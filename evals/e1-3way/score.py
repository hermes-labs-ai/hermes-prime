#!/usr/bin/env python3
"""Score raw-data.jsonl with rule-based regex matchers per question, emit RESULTS.md."""
import json
import re
import math
from pathlib import Path
from collections import defaultdict

HERE = Path(__file__).parent
RAW = HERE / "raw-data.jsonl"
SCORED = HERE / "scored-data.jsonl"
RESULTS = HERE / "RESULTS.md"

# Scoring rules per question. 1 = correct, 0 = miss/wrong.
def score_q1(r):
    # Tool name for external reality check on drifting session = hermes-ground
    return 1 if re.search(r"hermes[-_ ]?ground\b", r, re.I) else 0

def score_q2(r):
    # Rule about coining names: no noun-phrase label until file at a path exists
    rl = r.lower()
    has_no = any(p in rl for p in ["no noun", "do not", "don't", "not until", "before", "until", "must not", "shouldn't"])
    has_file_or_impl = any(p in rl for p in ["file", "path", "implement", "exist", "concrete"])
    has_name_concept = any(p in rl for p in ["name", "label", "noun", "coin", "naming"])
    return 1 if (has_no and has_file_or_impl and has_name_concept) else 0

def score_q3(r):
    # Indirect: should NOT commit name now, defer until file exists
    rl = r.lower()
    says_later = any(p in rl for p in ["later", "wait", "defer", "after", "once", "not yet", "hold off", "shouldn't commit", "don't commit", "should not commit", "not now", "no, "])
    says_now = any(p in rl for p in ["commit it now", "commit the name now", "name it now", "yes, commit"])
    has_file_reasoning = any(p in rl for p in ["file", "path", "implement", "exist", "concrete", "built", "code"])
    if says_now and not says_later:
        return 0
    return 1 if (says_later and has_file_reasoning) else 0

def score_q4(r):
    # Calibrate analysis before ship — synthetic ground truth
    rl = r.lower()
    has_calibrate = any(p in rl for p in ["calibrat", "synthetic", "ground[- ]?truth", "known expected", "sanity check", "validate"])
    has_check_rubric = any(p in rl for p in ["rubric", "blind", "review", "verify"])
    return 1 if (has_calibrate or has_check_rubric) else 0

def score_q5(r):
    # Indirect/blind: rubric (blinded) and/or calibration
    rl = r.lower()
    has_rubric = any(p in rl for p in ["rubric", "hermes-rubric", "blind"])
    has_calibrate = any(p in rl for p in ["calibrat", "synthetic", "ground-truth", "ground truth"])
    has_ground = "hermes-ground" in rl or "grounding" in rl
    return 1 if (has_rubric or has_calibrate or has_ground) else 0

SCORERS = {"Q1": score_q1, "Q2": score_q2, "Q3": score_q3, "Q4": score_q4, "Q5": score_q5}
DIRECT = {"Q1", "Q2", "Q4"}
INDIRECT = {"Q3", "Q5"}

def wilson_ci(k, n, z=1.96):
    if n == 0:
        return (0.0, 0.0)
    p = k / n
    denom = 1 + z*z/n
    center = (p + z*z/(2*n)) / denom
    half = (z * math.sqrt(p*(1-p)/n + z*z/(4*n*n))) / denom
    return (max(0.0, center-half), min(1.0, center+half))

def main():
    rows = []
    with open(RAW) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            qid = d["question_id"]
            d["score"] = SCORERS[qid](d.get("response", ""))
            rows.append(d)

    with open(SCORED, "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")

    # aggregates
    by_arm = defaultdict(list)
    by_arm_q = defaultdict(list)
    by_arm_kind = defaultdict(list)
    for r in rows:
        by_arm[r["arm"]].append(r["score"])
        by_arm_q[(r["arm"], r["question_id"])].append(r["score"])
        kind = "direct" if r["question_id"] in DIRECT else "indirect"
        by_arm_kind[(r["arm"], kind)].append(r["score"])

    arms = ["control", "v01", "v02"]
    qs = ["Q1","Q2","Q3","Q4","Q5"]

    lines = ["# E1 3-way Results: control vs v0.1-pointers vs v0.2-inline\n"]
    lines.append(f"Total rows scored: {len(rows)}\n")
    lines.append("## Per-arm aggregate recall\n")
    lines.append("| arm | n | correct | rate | 95% CI |")
    lines.append("|---|---|---|---|---|")
    arm_rate = {}
    for a in arms:
        scores = by_arm[a]
        n = len(scores); k = sum(scores)
        rate = k/n if n else 0
        lo, hi = wilson_ci(k, n)
        arm_rate[a] = rate
        lines.append(f"| {a} | {n} | {k} | {rate:.3f} | [{lo:.3f}, {hi:.3f}] |")

    lines.append("\n## Per-question per-arm recall (n_correct / n_total)\n")
    lines.append("| question | kind | control | v0.1 | v0.2 |")
    lines.append("|---|---|---|---|---|")
    for q in qs:
        kind = "direct" if q in DIRECT else "INDIRECT"
        cells = []
        for a in arms:
            s = by_arm_q[(a, q)]
            cells.append(f"{sum(s)}/{len(s)} ({(sum(s)/len(s) if s else 0):.2f})")
        lines.append(f"| {q} | {kind} | {cells[0]} | {cells[1]} | {cells[2]} |")

    lines.append("\n## Direct vs indirect breakdown\n")
    lines.append("| arm | direct rate | indirect rate |")
    lines.append("|---|---|---|")
    direct_rate = {}; indirect_rate = {}
    for a in arms:
        d = by_arm_kind[(a, "direct")]
        i = by_arm_kind[(a, "indirect")]
        dr = sum(d)/len(d) if d else 0
        ir = sum(i)/len(i) if i else 0
        direct_rate[a] = dr; indirect_rate[a] = ir
        lines.append(f"| {a} | {dr:.3f} ({sum(d)}/{len(d)}) | {ir:.3f} ({sum(i)}/{len(i)}) |")

    # Verdict
    delta_v2_v1 = arm_rate["v02"] - arm_rate["v01"]
    over_control_v1 = arm_rate["v01"] - arm_rate["control"]
    over_control_v2 = arm_rate["v02"] - arm_rate["control"]

    lines.append("\n## Provisional verdict\n")
    lines.append(f"- v0.2 - v0.1 delta: **{delta_v2_v1:+.3f}**")
    lines.append(f"- v0.1 - control delta: **{over_control_v1:+.3f}**")
    lines.append(f"- v0.2 - control delta: **{over_control_v2:+.3f}**\n")

    if over_control_v1 <= 0.05 and over_control_v2 <= 0.05:
        verdict = "BOTH-FAIL"
        rationale = "Neither v0.1 nor v0.2 beats control by >5pt — mechanism may be wrong."
    elif delta_v2_v1 >= 0.10:
        verdict = "SUPPORTED"
        rationale = "v0.2 inline ≥ v0.1 + 10pt → keep inline content."
    elif delta_v2_v1 <= -0.10:
        verdict = "WORSE"
        rationale = "v0.2 inline ≤ v0.1 - 10pt → REVERT inline approach."
    else:
        verdict = "EQUIVALENT"
        rationale = "v0.2 within ±10pt of v0.1 → keep v0.1 mechanism, change framing only."

    lines.append(f"**VERDICT: {verdict}** — {rationale}")

    RESULTS.write_text("\n".join(lines) + "\n")
    print(f"Scored {len(rows)} rows. Verdict: {verdict}")
    print(f"control={arm_rate['control']:.3f} v01={arm_rate['v01']:.3f} v02={arm_rate['v02']:.3f}")
    print(f"DIRECT control={direct_rate['control']:.2f} v01={direct_rate['v01']:.2f} v02={direct_rate['v02']:.2f}")
    print(f"INDIRECT control={indirect_rate['control']:.2f} v01={indirect_rate['v01']:.2f} v02={indirect_rate['v02']:.2f}")

if __name__ == "__main__":
    main()
