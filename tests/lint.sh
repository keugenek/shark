#!/usr/bin/env bash
# 🦈 Shark Skill — Structural Lint Tests
# Fast, no LLM needed. Runs in CI on every push.
set -uo pipefail

SKILL="SKILL.md"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "  ✅ $desc"
    PASS=$((PASS+1))
  else
    echo "  ❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "🦈 Shark Skill — Lint Tests"
echo "================================"

# --- SKILL.md exists and has frontmatter ---
echo ""
echo "📄 File structure"
check "SKILL.md exists" $([ -f "$SKILL" ] && echo 0 || echo 1)
check "README.md exists" $([ -f "README.md" ] && echo 0 || echo 1)
check "SKILL.md has YAML frontmatter" $(head -1 "$SKILL" | grep -q "^---$" && echo 0 || echo 1)
check "SKILL.md has name field" $(grep -q "^name:" "$SKILL" && echo 0 || echo 1)
check "SKILL.md has version field" $(grep -q "^version:" "$SKILL" && echo 0 || echo 1)
check "SKILL.md has summary field" $(grep -q "^summary:" "$SKILL" && echo 0 || echo 1)
check "SKILL.md has tags field" $(grep -q "^tags:" "$SKILL" && echo 0 || echo 1)

# --- Required sections ---
echo ""
echo "📋 Required sections"
check "Has ## Lifecycle section" $(grep -q "^## Lifecycle" "$SKILL" && echo 0 || echo 1)
check "Has ## Decision Tree section" $(grep -q "^## Decision Tree" "$SKILL" && echo 0 || echo 1)
check "Has ## Error Handling section" $(grep -q "^## Error Handling" "$SKILL" && echo 0 || echo 1)
check "Has ## Hard Limits section" $(grep -q "^## Hard Limits" "$SKILL" && echo 0 || echo 1)
check "Has ## Output Format section" $(grep -q "^## Output Format" "$SKILL" && echo 0 || echo 1)
check "Has Pilot Fish section" $(grep -q "Pilot Fish" "$SKILL" && echo 0 || echo 1)
check "Has Remora terminology" $(grep -q "remora" "$SKILL" && echo 0 || echo 1)

# --- Key rules present ---
echo ""
echo "📏 Key rules"
check "30s rule mentioned" $(grep -q "30" "$SKILL" && echo 0 || echo 1)
check "runTimeoutSeconds mentioned" $(grep -q "runTimeoutSeconds" "$SKILL" && echo 0 || echo 1)
check "Max 8 remoras rule" $(grep -q "[Mm]ax 8" "$SKILL" && echo 0 || echo 1)
check "No nested remoras rule" $(grep -qi "nested" "$SKILL" && echo 0 || echo 1)
check "Pilot fish formula present" $(grep -q "estimatedRemaining" "$SKILL" && echo 0 || echo 1)
check "Progress bar symbols defined" $(grep -q "████" "$SKILL" && echo 0 || echo 1)

# --- Multi-agent support ---
echo ""
echo "🤖 Agent compatibility"
check "Claude Code mentioned" $(grep -qi "claude" "$SKILL" && echo 0 || echo 1)
check "Codex mentioned" $(grep -qi "codex" "$SKILL" && echo 0 || echo 1)
check "Gemini mentioned" $(grep -qi "gemini" "$SKILL" && echo 0 || echo 1)
check "exec timeout mentioned" $(grep -q "background: true" "$SKILL" && echo 0 || echo 1)
check "Codex cleanup mentions close_agent" $(grep -q "close_agent" "$SKILL" && echo 0 || echo 1)

# --- shark-exec checks ---
echo ""
echo "🦈 shark-exec checks"
check "shark-exec/SKILL.md exists" $([ -f "shark-exec/SKILL.md" ] && echo 0 || echo 1)
check "shark-exec has state directory" $([ -f "shark-exec/state/.gitkeep" ] && echo 0 || echo 1)
check "shark-exec has scripts directory" $([ -f "shark-exec/scripts/poll-and-deliver.js" ] && echo 0 || echo 1)
check "shark-exec covers cronJobId write-back" $(grep -q "cronJobId" shark-exec/SKILL.md && echo 0 || echo 1)
check "shark-exec covers fast-exit handling" $(grep -qi "system event\|already completed\|fast-exit\|exits before" shark-exec/SKILL.md && echo 0 || echo 1)
check "shark-exec covers maxSeconds" $(grep -q "maxSeconds" shark-exec/SKILL.md && echo 0 || echo 1)
check "shark-exec covers cleanup of completed agents" $(grep -q "close_agent" shark-exec/SKILL.md && echo 0 || echo 1)

# --- Anti-patterns NOT present ---
echo ""
echo "🚫 Anti-pattern checks"
check "No 'sub-shark' (renamed to remora)" $(grep -qv "sub-shark" "$SKILL" && echo 0 || echo 1)

# --- README quality ---
echo ""
echo "📖 README quality"
check "README has install section" $(grep -q "## Install" README.md && echo 0 || echo 1)
check "README has one-liner install" $(grep -q "curl" README.md && echo 0 || echo 1)
check "README mentions all agents" $(grep -qi "codex" README.md && echo 0 || echo 1)
check "README has comparison table" $(grep -q "Ralph Loop" README.md && echo 0 || echo 1)

# --- Summary ---
echo ""
echo "================================"
echo "🦈 Results: $PASS passed, $FAIL failed"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "❌ Lint failed"
  exit 1
else
  echo "✅ All checks passed"
  exit 0
fi
