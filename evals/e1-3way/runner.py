#!/usr/bin/env python3
"""E1 3-way runner with proper parallelism (no shell quoting nightmares)."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent
RAW = HERE / "raw-data.jsonl"
LOG = HERE / "runner.log"

V01_FRAGMENT = Path.home() / "Documents/projects/hermes-handbook/session-init/CLAUDE-fragment.md"
V02_FRAGMENT = Path("/tmp/hermes-prime-v2-fragment.md")
MODEL = "claude-haiku-4-5"
TRIALS = int(os.environ.get("TRIALS", 10))
PAR = int(os.environ.get("PAR", 8))

QUESTIONS = {
    "Q1": "What tool would I run to get an external reality check on a drifting Claude Code session? Reply with the tool name.",
    "Q2": "What's the rule about coining names for things in this project? One sentence.",
    "Q3": "I just spent 30 minutes refactoring an API design and want to call it 'the X System'. Should I commit the name now or later? Why?",
    "Q4": "Before publishing an analysis result, what's the standing convention I should follow?",
    "Q5": "Before claiming a published artifact is ready, what should I run on it?",
}

def setup_dirs():
    base = Path(tempfile.mkdtemp(prefix="e1-"))
    control = base / "control"; control.mkdir()
    v01 = base / "v01"; v01.mkdir()
    v02 = base / "v02"; v02.mkdir()
    shutil.copy(V01_FRAGMENT, v01 / "CLAUDE.md")
    shutil.copy(V02_FRAGMENT, v02 / "CLAUDE.md")
    return {"control": control, "v01": v01, "v02": v02}

def call_one(arm, qid, rep, workdir, qtext, attempt=1):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    cmd = ["claude", "--print", "--model", MODEL]
    if arm == "control":
        cmd.append("--exclude-dynamic-system-prompt-sections")
    cmd.append(qtext)
    try:
        r = subprocess.run(cmd, cwd=str(workdir), capture_output=True, text=True, timeout=180)
        resp = (r.stdout or "").strip()
        if not resp and attempt == 1:
            time.sleep(60)
            return call_one(arm, qid, rep, workdir, qtext, attempt=2)
    except subprocess.TimeoutExpired:
        resp = "[TIMEOUT]"
    except Exception as e:
        resp = f"[ERR:{e}]"
    return {
        "arm": arm, "question_id": qid, "rep_n": rep,
        "response": resp[:2000], "model_id": MODEL, "timestamp_utc": ts,
    }

def main():
    dirs = setup_dirs()
    jobs = []
    for arm in ("control", "v01", "v02"):
        for qid, qtext in QUESTIONS.items():
            for rep in range(1, TRIALS + 1):
                jobs.append((arm, qid, rep, dirs[arm], qtext))

    print(f"jobs={len(jobs)} par={PAR} model={MODEL}")
    start = time.time()
    rows = []
    with open(RAW, "w") as f, ThreadPoolExecutor(max_workers=PAR) as ex:
        futs = {ex.submit(call_one, *j): j for j in jobs}
        done = 0
        for fut in as_completed(futs):
            try:
                row = fut.result()
            except Exception as e:
                j = futs[fut]
                row = {"arm": j[0], "question_id": j[1], "rep_n": j[2], "response": f"[FUTERR:{e}]",
                       "model_id": MODEL, "timestamp_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
            f.write(json.dumps(row) + "\n")
            f.flush()
            rows.append(row)
            done += 1
            if done % 10 == 0 or done == len(jobs):
                el = time.time() - start
                print(f"  {done}/{len(jobs)} done, elapsed={el:.0f}s")
    print(f"complete: {len(rows)} rows in {time.time()-start:.0f}s")

if __name__ == "__main__":
    main()
