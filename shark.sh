#!/usr/bin/env sh
# 🦈 shark.sh — Ralph-style loop enforcer for the Shark Pattern
# Each iteration = one bounded Claude turn. Never blocks >30s per loop.
# Usage: ./shark.sh "your task description"
#   or:  ./shark.sh  (reads task from SHARK_TASK.md if exists)

PROMPT_FILE="$(dirname "$0")/SHARK_PROMPT.md"
SKILL_FILE="$(dirname "$0")/SKILL.md"
STATE_FILE="$(dirname "$0")/shark-exec/state/pending.json"
MAX_LOOPS=${SHARK_MAX_LOOPS:-50}
LOOP_TIMEOUT=${SHARK_LOOP_TIMEOUT:-25}  # seconds per turn (under 30s hard limit)

if [ -n "$1" ]; then
  TASK="$*"
elif [ -f "SHARK_TASK.md" ]; then
  TASK=$(cat SHARK_TASK.md)
else
  echo "Usage: ./shark.sh 'task description'"
  echo "  or create SHARK_TASK.md with your task"
  exit 1
fi

# Build the prompt: skill context + task + state awareness
build_prompt() {
  cat "$SKILL_FILE"
  echo ""
  echo "---"
  echo "## Current Task"
  echo "$TASK"
  echo ""
  echo "## Loop State"
  echo "Loop: $CURRENT_LOOP / $MAX_LOOPS"
  if [ -f "$STATE_FILE" ]; then
    echo "Pending background jobs:"
    cat "$STATE_FILE"
  fi
  echo ""
  echo "## Instructions"
  echo "Follow the Shark Pattern from SKILL.md above."
  echo "Each turn MUST complete in under ${LOOP_TIMEOUT}s."
  echo "If your task requires slow operations (>5s), use shark-exec pattern."
  echo "Write TASK_COMPLETE to a file named .shark-done when finished."
  echo "Write progress to SHARK_LOG.md after each loop."
}

CURRENT_LOOP=0
rm -f .shark-done

echo "🦈 Shark loop starting — task: $TASK"
echo "   Max loops: $MAX_LOOPS | Timeout per turn: ${LOOP_TIMEOUT}s"
echo ""

while [ $CURRENT_LOOP -lt $MAX_LOOPS ]; do
  CURRENT_LOOP=$((CURRENT_LOOP + 1))
  echo "🦈 Loop $CURRENT_LOOP/$MAX_LOOPS..."

  # Run claude with hard timeout — THIS is the 30s enforcement
  build_prompt | timeout ${LOOP_TIMEOUT}s claude --print --permission-mode bypassPermissions
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 124 ]; then
    echo "⏱ Turn $CURRENT_LOOP timed out at ${LOOP_TIMEOUT}s — looping back"
  fi

  # Check if task is done
  if [ -f ".shark-done" ]; then
    echo ""
    echo "✅ Task complete after $CURRENT_LOOP loops"
    cat .shark-done
    exit 0
  fi
done

echo "⚠️ Max loops ($MAX_LOOPS) reached without completion"
exit 1
