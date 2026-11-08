#!/bin/sh
# codex-review.sh — the ONLY sanctioned way to launch a Codex board review.
# Exists because raw `codex exec` in background shells accumulated four
# distinct silent-hang modes (stdin pipe, startup stall, wrong-id polling,
# prompt-echo false verdicts) costing hours of watching nothing happen.
#
# Guarantees:
#   - stdin closed (kills the "Reading additional input from stdin..." hang)
#   - LIVENESS: if output hasn't grown past the banner in BOOT_SECS -> kill, exit 65
#   - HARD CAP: TIMEOUT_SECS wall clock -> kill, exit 66
#   - exit 0 only when a non-empty review landed in OUT_FILE
#
# Usage: codex-review.sh <prompt-file> <out-file> [timeout-secs=480] [effort]
#   effort (optional): low|medium|high|xhigh -> passed via -c model_reasoning_effort
#   (use medium for mechanical-diff sanity passes; halves latency)
#
# Caller contract (the never-block rule, now mechanical): treat ANY nonzero
# exit as "no Codex this round" — retry AT MOST once, then proceed with the
# Claude reviewers' verdicts and reconcile Codex post-merge if it ever lands.
set -u
PROMPT_FILE=${1:?prompt file}; OUT_FILE=${2:?out file}
TIMEOUT_SECS=${3:-480}; EFFORT=${4:-}
BOOT_SECS=45

EFFORT_ARGS=""
[ -n "$EFFORT" ] && EFFORT_ARGS="-c model_reasoning_effort=$EFFORT"

codex exec $EFFORT_ARGS "$(cat "$PROMPT_FILE")" < /dev/null > "$OUT_FILE" 2>&1 &
PID=$!

# Wall-clock deadlines, not an iteration counter: a counter stops advancing if this
# shell is suspended or a sleep overruns, and a 900s cap once ran ~75 min.
start=$(date +%s); booted=0
while kill -0 "$PID" 2>/dev/null; do
    sleep 5; elapsed=$(( $(date +%s) - start ))
    if [ "$booted" -eq 0 ] && [ "$elapsed" -ge "$BOOT_SECS" ]; then
        booted=1
        # Booted = more than the ~12-line banner in the log
        if [ "$(wc -l < "$OUT_FILE")" -lt 13 ]; then
            kill "$PID" 2>/dev/null
            echo "codex-review: NOT BOOTED after ${BOOT_SECS}s — killed (exit 65). Do not wait; retry once or proceed without Codex." >> "$OUT_FILE"
            exit 65
        fi
    fi
    if [ "$elapsed" -ge "$TIMEOUT_SECS" ]; then
        kill "$PID" 2>/dev/null
        echo "codex-review: TIMEOUT after ${TIMEOUT_SECS}s — killed (exit 66). Partial output above; proceed without Codex." >> "$OUT_FILE"
        exit 66
    fi
done
wait "$PID"; RC=$?
[ "$RC" -ne 0 ] && { echo "codex-review: codex exited $RC" >> "$OUT_FILE"; exit "$RC"; }
# Success requires actual review content, not just a banner
[ "$(wc -c < "$OUT_FILE")" -lt 800 ] && { echo "codex-review: output suspiciously small — treating as failure (exit 67)" >> "$OUT_FILE"; exit 67; }
exit 0
