#!/bin/bash
# preliminary-bootstrap-eval.sh — three preliminary evals for hermes-prime.
#
# E1 — convention-recall test (with vs without bootstrap, fresh claude-cli)
# E2 — idempotency stress (5 rapid re-injections)
# E3 — uninject roundtrip integrity
#
# Calibration step runs first: dry-tests the E1 scoring function with synthetic
# responses that should score Y/N/partial. If calibration fails, E1 is aborted.
#
# Usage:
#   bash evals/preliminary-bootstrap-eval.sh             # run all three
#   bash evals/preliminary-bootstrap-eval.sh --skip-e1   # skip E1 (no claude-cli)
#
# Honest reporting: results written unredacted to evals/runs/<date>/.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$REPO_ROOT/bin/hermes-session-init"
RUN_DATE=$(date +%Y-%m-%d)
RUN_DIR="$REPO_ROOT/evals/runs/$RUN_DATE"
mkdir -p "$RUN_DIR"

SKIP_E1=0
for arg in "$@"; do
    [[ "$arg" == "--skip-e1" ]] && SKIP_E1=1
done

PASS=0; FAIL=0
LOG="$RUN_DIR/eval-log.txt"
: > "$LOG"

log() { echo "$@" | tee -a "$LOG"; }
log "hermes-prime preliminary eval — $RUN_DATE"
log "repo: $REPO_ROOT"
log "bin:  $BIN"
log "==="

# ---------------------------------------------------------------
# E1 scoring function (defined before calibration so calibration tests it).
# ---------------------------------------------------------------
# score_response <question_id> <response_text> -> echoes "Y" or "N", returns 0
score_response() {
    local qid="$1"; local resp="$2"
    local lower; lower=$(printf '%s' "$resp" | tr '[:upper:]' '[:lower:]')
    case "$qid" in
        Q-ground)
            case "$lower" in *hermes-ground*) echo Y; return 0 ;; esac
            echo N
            ;;
        Q-noun-phrase)
            case "$lower" in
                *"no noun-phrase"*|*"file exists at a path"*|*"until a file"*) echo Y; return 0 ;;
            esac
            echo N
            ;;
        Q-rubric)
            case "$lower" in
                *hermes-rubric*|*"blinded rubric"*|*"rubric pass-through"*|*"blind rubric"*) echo Y; return 0 ;;
            esac
            case "$lower" in
                *blind*rubric*|*rubric*blind*) echo Y; return 0 ;;
            esac
            echo N
            ;;
        *)
            echo N
            ;;
    esac
}

# ---------------------------------------------------------------
# Calibration: dry-test scoring function on synthetic responses.
# ---------------------------------------------------------------
calibrate() {
    log ""
    log "[CALIBRATION] dry-testing score_response on 9 synthetic cases"
    local cal_pass=0 cal_fail=0
    # Format: qid|expected|response
    local cases=(
        "Q-ground|Y|You would run hermes-ground to externally check the session."
        "Q-ground|N|You would write a careful summary and ask the user to verify it."
        "Q-ground|Y|hermes-ground is the tool."
        "Q-noun-phrase|Y|No noun-phrase label until a file exists at a path."
        "Q-noun-phrase|N|Pick a memorable name and iterate from there."
        "Q-noun-phrase|Y|Wait until a file is at the path before you name it."
        "Q-rubric|Y|Pass it through hermes-rubric (BLINDed) before ship."
        "Q-rubric|N|Have a friend skim it and ship if they nod."
        "Q-rubric|Y|Use a blinded rubric pass-through to score before shipping."
    )
    for c in "${cases[@]}"; do
        local qid="${c%%|*}"; local rest="${c#*|}"
        local expected="${rest%%|*}"; local resp="${rest#*|}"
        local got; got=$(score_response "$qid" "$resp")
        if [[ "$got" == "$expected" ]]; then
            cal_pass=$((cal_pass+1))
        else
            cal_fail=$((cal_fail+1))
            log "  CAL-FAIL: qid=$qid expected=$expected got=$got resp=\"$resp\""
        fi
    done
    log "[CALIBRATION] pass=$cal_pass fail=$cal_fail (target: 9/0)"
    if [[ $cal_fail -ne 0 ]]; then
        log "[CALIBRATION] FAILED — aborting E1. (E2/E3 still run.)"
        return 1
    fi
    log "[CALIBRATION] OK — scoring function categorizes correctly."
    return 0
}

# ---------------------------------------------------------------
# E1 — convention recall test.
# ---------------------------------------------------------------
run_e1() {
    log ""
    log "=== E1 — convention-recall test (with vs without bootstrap) ==="
    if ! command -v claude >/dev/null 2>&1; then
        log "E1: SKIP — claude-cli not available."
        return 2
    fi

    local control_dir treatment_dir
    control_dir=$(mktemp -d -t hp-e1-ctrl-XXXX)
    treatment_dir=$(mktemp -d -t hp-e1-trt-XXXX)
    # Treatment: inject the fragment.
    "$BIN" --inject "$treatment_dir" >/dev/null 2>&1 || {
        log "E1: SKIP — --inject failed."
        rm -rf "$control_dir" "$treatment_dir"
        return 2
    }
    log "E1 control_dir   = $control_dir (no CLAUDE.md)"
    log "E1 treatment_dir = $treatment_dir (CLAUDE.md present, marker injected)"

    # Question set
    local -a qids=(Q-ground Q-noun-phrase Q-rubric)
    local -a qtxt=(
        "What tool would I run to externally ground a drifting session? Reply in one sentence."
        "What is the rule about coining names for new concepts mid-session? Reply in one sentence."
        "How should every shippable artifact be reviewed before ship? Reply in one sentence."
    )

    local -a results_ctrl=() results_trt=()
    local i=0
    for qid in "${qids[@]}"; do
        local q="${qtxt[$i]}"
        log ""
        log "  --- $qid ---"
        log "  Q: $q"

        # Control
        local ctrl_resp ctrl_score
        ctrl_resp=$(cd "$control_dir" && claude --print \
                    --exclude-dynamic-system-prompt-sections \
                    "$q" 2>/dev/null || echo "[claude-cli error or timeout]")
        ctrl_score=$(score_response "$qid" "$ctrl_resp")
        results_ctrl+=("$ctrl_score")
        printf '%s\n' "$ctrl_resp" > "$RUN_DIR/E1_${qid}_control.txt"
        log "  CONTROL  ($ctrl_score): $(printf '%.180s' "$ctrl_resp")"

        # Treatment
        local trt_resp trt_score
        trt_resp=$(cd "$treatment_dir" && claude --print \
                   --exclude-dynamic-system-prompt-sections \
                   "$q" 2>/dev/null || echo "[claude-cli error or timeout]")
        trt_score=$(score_response "$qid" "$trt_resp")
        results_trt+=("$trt_score")
        printf '%s\n' "$trt_resp" > "$RUN_DIR/E1_${qid}_treatment.txt"
        log "  TREATMENT ($trt_score): $(printf '%.180s' "$trt_resp")"
        i=$((i+1))
    done

    # Tally
    local ctrl_y=0 trt_y=0
    for s in "${results_ctrl[@]}"; do [[ "$s" == "Y" ]] && ctrl_y=$((ctrl_y+1)); done
    for s in "${results_trt[@]}"; do [[ "$s" == "Y" ]] && trt_y=$((trt_y+1)); done
    local n=${#qids[@]}
    local ctrl_rate=$(awk -v y="$ctrl_y" -v n="$n" 'BEGIN{printf "%.2f", y/n}')
    local trt_rate=$(awk -v y="$trt_y" -v n="$n" 'BEGIN{printf "%.2f", y/n}')
    local lift=$(awk -v t="$trt_rate" -v c="$ctrl_rate" 'BEGIN{printf "%+.2f", t-c}')

    log ""
    log "  E1 SUMMARY:"
    log "    control  recall: $ctrl_y/$n = $ctrl_rate"
    log "    treatment recall: $trt_y/$n = $trt_rate"
    log "    lift           : $lift"

    # Persist a summary JSON-ish file
    cat > "$RUN_DIR/E1_summary.txt" <<EOF
E1 convention-recall summary — $RUN_DATE
n_questions = $n
control_passes = $ctrl_y
treatment_passes = $trt_y
control_rate = $ctrl_rate
treatment_rate = $trt_rate
lift = $lift
per_question_control = ${results_ctrl[*]}
per_question_treatment = ${results_trt[*]}
EOF

    rm -rf "$control_dir" "$treatment_dir"

    # E1 doesn't fail the script even if lift is ≤ 0 — null result is the deliverable.
    log "  E1: data captured. Honest reporting: lift=$lift (positive, zero, or negative all reported)."
    return 0
}

# ---------------------------------------------------------------
# E2 — idempotency stress.
# ---------------------------------------------------------------
run_e2() {
    log ""
    log "=== E2 — idempotency stress (5 rapid re-injections) ==="
    local d; d=$(mktemp -d -t hp-e2-XXXX)
    "$BIN" --inject "$d" >/dev/null 2>&1
    local s1; s1=$(wc -c < "$d/CLAUDE.md")
    "$BIN" --inject "$d" >/dev/null 2>&1
    "$BIN" --inject "$d" >/dev/null 2>&1
    "$BIN" --inject "$d" >/dev/null 2>&1
    "$BIN" --inject "$d" >/dev/null 2>&1
    local s5; s5=$(wc -c < "$d/CLAUDE.md")
    local delta=$((s5 - s1)); delta=${delta#-}
    rm -rf "$d"
    log "  size after 1 inject: $s1 bytes"
    log "  size after 5 injects: $s5 bytes"
    log "  |delta|: $delta (target: ≤ 2)"
    if [[ $delta -le 2 ]]; then
        log "  E2: PASS"
        PASS=$((PASS+1))
        return 0
    else
        log "  E2: FAIL"
        FAIL=$((FAIL+1))
        return 1
    fi
}

# ---------------------------------------------------------------
# E3 — uninject roundtrip integrity.
# ---------------------------------------------------------------
run_e3() {
    log ""
    log "=== E3 — uninject roundtrip integrity ==="
    local d; d=$(mktemp -d -t hp-e3-XXXX)
    cat > "$d/CLAUDE.md" <<'EOF'
# pre-existing project conventions

This project predates hermes-prime.
- rule one
- rule two

EOF
    local pre_hash; pre_hash=$(shasum -a 256 "$d/CLAUDE.md" | awk '{print $1}')
    "$BIN" --inject "$d" >/dev/null 2>&1
    "$BIN" --uninject "$d" >/dev/null 2>&1
    local post_hash; post_hash=$(shasum -a 256 "$d/CLAUDE.md" | awk '{print $1}')

    # Whitespace-tolerant comparison: also check after stripping trailing whitespace.
    local pre_trim post_trim
    pre_trim=$(awk 'BEGIN{RS=""}{print}' "$d/CLAUDE.md.bak."* 2>/dev/null | head -c 100000 | shasum -a 256 | awk '{print $1}')
    # Compute post_trim from the current CLAUDE.md (whitespace-collapsed).
    post_trim=$(awk 'BEGIN{RS=""}{print}' "$d/CLAUDE.md" | shasum -a 256 | awk '{print $1}')

    log "  pre-inject  sha256 (raw):  $pre_hash"
    log "  post-uninject sha256 (raw): $post_hash"
    log "  whitespace-tolerant pre:   $pre_trim"
    log "  whitespace-tolerant post:  $post_trim"

    rm -rf "$d"
    if [[ "$pre_hash" == "$post_hash" ]] || [[ "$pre_trim" == "$post_trim" ]]; then
        log "  E3: PASS (roundtrip integrity preserved)"
        PASS=$((PASS+1))
        return 0
    else
        log "  E3: FAIL (content drifted across inject+uninject roundtrip)"
        FAIL=$((FAIL+1))
        return 1
    fi
}

# ---------------------------------------------------------------
# Run order: calibration → E1 (if not skipped) → E2 → E3.
# ---------------------------------------------------------------
if [[ $SKIP_E1 -eq 0 ]]; then
    if calibrate; then
        run_e1 || true
    else
        log "E1 skipped due to calibration failure."
    fi
else
    log "E1 skipped (--skip-e1)."
fi

run_e2
run_e3

log ""
log "==="
log "MECHANISM EVALS (E2, E3): pass=$PASS fail=$FAIL"
log "E1 (empirical): see $RUN_DIR/E1_summary.txt for actual recall numbers."
log "Run log: $LOG"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
