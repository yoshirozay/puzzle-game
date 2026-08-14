#!/usr/bin/env bash
# grok-delegate.sh — delegate a scoped coding task to Grok 4.5 in an isolated
# git worktree, then verify with the full adversarial suite. Prints a compact
# summary (the only thing the reviewing agent needs to read); full logs stay
# on disk for drill-down.
#
# Usage:
#   grok-delegate.sh run <name> <spec-file>   # delegate + full-suite verify
#   grok-delegate.sh clean <name>             # remove worktree + branch + logs
#
# The prompt sent to Grok = tools/grok-delegate-preamble.txt + <spec-file>.
# Spec files stay short: what to build, acceptance criteria, pointer docs.
set -euo pipefail

GROK_BIN="${GROK_BIN:-grok}"
GROK_MODEL="grok-4.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
PREAMBLE="$SCRIPT_DIR/grok-delegate-preamble.txt"

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 1; }

[ $# -ge 2 ] || usage
CMD="$1"; NAME="$2"
WT="$(dirname "$ROOT")/tiki-lounge-grok-$NAME"
LOGS="$WT-logs"
BRANCH="grok/$NAME"

case "$CMD" in
run)
    [ $# -eq 3 ] || usage
    SPEC="$3"
    [ -f "$SPEC" ] || { echo "spec file not found: $SPEC"; exit 1; }
    [ ! -e "$WT" ] || { echo "worktree exists: $WT — run 'grok-delegate.sh clean $NAME' first"; exit 1; }

    mkdir -p "$LOGS"
    git -C "$ROOT" worktree add "$WT" -b "$BRANCH" HEAD >"$LOGS/setup.log" 2>&1
    (cd "$WT/TikiGames" && xcodegen generate) >>"$LOGS/setup.log" 2>&1

    cat "$PREAMBLE" "$SPEC" > "$LOGS/prompt.txt"

    set +e
    "$GROK_BIN" --cwd "$WT" -m "$GROK_MODEL" \
        --prompt-file "$LOGS/prompt.txt" \
        --always-approve --output-format json \
        >"$LOGS/grok.json" 2>"$LOGS/grok.stderr"
    GROK_EXIT=$?

    (cd "$WT/TikiGames" && xcodebuild test \
        -project TikiGames.xcodeproj -scheme TikiGames \
        -destination "platform=iOS Simulator,name=TikiGames Sim" \
        CODE_SIGNING_ALLOWED=NO) >"$LOGS/suite.log" 2>&1
    SUITE_EXIT=$?
    set -e

    echo "=== GROK DELEGATE: $NAME ==="
    echo "grok: exit=$GROK_EXIT model=$GROK_MODEL $(jq -r '"stop=\(.stopReason) turns=\(.num_turns) cost_usd=\(.total_cost_usd)"' "$LOGS/grok.json" 2>/dev/null || echo '(no json envelope)')"
    echo "--- diff stat ---"
    git -C "$WT" diff --stat | tail -8
    echo "--- untracked files ---"
    git -C "$WT" status --short | grep '^??' || echo "(none)"
    echo "--- full suite (exit=$SUITE_EXIT) ---"
    grep -E "Test run with|TEST (SUCCEEDED|FAILED)" "$LOGS/suite.log" | tail -4
    if [ "$SUITE_EXIT" -ne 0 ]; then
        echo "--- failures ---"
        grep -E "✘|recorded an issue|failed \(" "$LOGS/suite.log" | head -20
    fi
    echo "--- paths ---"
    echo "worktree: $WT"
    echo "logs:     $LOGS   (grok report: jq -r .text $LOGS/grok.json)"
    if [ "$GROK_EXIT" -eq 0 ] && [ "$SUITE_EXIT" -eq 0 ]; then
        echo "VERDICT: PASS"
    else
        echo "VERDICT: FAIL"
        exit 1
    fi
    ;;
clean)
    git -C "$ROOT" worktree remove --force "$WT" 2>/dev/null || true
    git -C "$ROOT" branch -D "$BRANCH" 2>/dev/null || true
    git -C "$ROOT" worktree prune
    rm -rf "$LOGS"
    echo "cleaned: $WT (+branch $BRANCH, logs)"
    ;;
*)
    usage
    ;;
esac
