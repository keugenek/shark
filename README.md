# 🦈 The Shark Pattern

> *A shark that stops swimming dies. An agent that waits for tools wastes compute.*

## What Is This?

The **Shark Pattern** is a non-blocking execution model for AI coding agents.

**The rule:** Every LLM turn completes in under 30 seconds. Slow operations get spawned as sub-agents. The main agent never waits.

**The Pilot Fish sub-pattern:** When a sub-shark finishes early and others are still running, spawn a time-bounded pilot fish to pre-analyse partial results — killed when the last primary completes.

---

## Install

### OpenClaw (Claude / Sonnet / Opus)

**Option A — ClawHub (recommended):**
```bash
npx clawhub@latest install shark
```

**Option B — directly from this repo:**
```bash
# Copy SKILL.md into your OpenClaw workspace
curl -o ~/clawd/skills/shark/SKILL.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
```
Or clone:
```bash
git clone https://github.com/keugenek/shark-pattern ~/clawd/skills/shark
```
OpenClaw auto-discovers skills in `~/clawd/skills/` — no config needed.

---

### Claude Code (Anthropic CLI)

Add to your `CLAUDE.md` or `AGENTS.md` in the project root:
```bash
curl -o SHARK.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
```
Then reference it in your `CLAUDE.md`:
```markdown
## Agent Skills
- See SHARK.md for the Shark Pattern — use it for any multi-step task with slow tools.
```
Or paste the contents of `SKILL.md` directly into your `CLAUDE.md`.

---

### Codex (OpenAI)

Add to your `AGENTS.md` in the project root:
```bash
curl -o SHARK.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
```
Reference in `AGENTS.md`:
```markdown
## Execution Model
Follow the Shark Pattern defined in SHARK.md.
Never block on slow tools — spawn sub-agents, keep the main agent moving.
```

---

### Gemini CLI

Add to your `GEMINI.md` or system prompt file:
```bash
curl -o SHARK.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
```
Pass it as context:
```bash
gemini --system-prompt SHARK.md -p "your task here"
```
Or prepend to your prompt:
```bash
cat SHARK.md your-task.md | gemini -p -
```

---

### Cursor / Windsurf / Aider / any agent with a rules file

```bash
curl -o .cursor/rules/shark.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
# or for Aider:
curl -o .aider.shark.md \
  https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md
```
Add to your rules/conventions file:
```markdown
Follow the Shark Pattern (shark.md) for all multi-step tasks.
```

---

### One-liner for any project

Drop `SHARK.md` into any repo root — works as context for any agent:
```bash
curl -sO https://raw.githubusercontent.com/keugenek/shark-pattern/main/SKILL.md \
  && mv SKILL.md SHARK.md \
  && echo "SHARK.md" >> .gitignore
```

---

## Usage

Once installed, tell your agent:
- `"Use shark mode"`
- `"Non-blocking — spawn where needed"`
- `"Keep swimming"`
- `"Never wait for tools"`

### Progress output (chat-friendly)

```
🦈 3 sub-sharks · 1 pilot fish

⊙ [A] E2E tests         ████████████ ✅ 39s
⊙ [B] GitHub PRs        ████████████ ✅ 33s
○ [C] Infra ping        ████████████ ✅  9s
◈ [P] Pilot fish        ██████░░░░░░ ~14s left

↳ synthesising…
```

---

## The Patterns

### 🦈 Shark — non-blocking execution
```
think → spawn(slow tool A) → think
      → spawn(slow tool B) → think
      → receive A → incorporate → swim on
      → receive B → synthesise → done
```

### 🐟 Pilot Fish — time-bounded pre-analysis
```
sub-shark A ──► done (early)
sub-shark B ───────────────────────► done
              ↓
              spawn pilot-fish(A's result, timeout=est_remaining)
              pilot-fish: pre-validate, draft structure, flag gaps...
              ↓ (killed when B done)
              synthesise A + B + pilot-fish draft
```

---

## Comparison

| | Sequential | Ralph Loop | 🦈 Shark |
|--|--|--|--|
| Execution | Blocking | Iterative, blocking | Parallel, non-blocking |
| Tool wait | Always blocks | Always blocks | Never blocks |
| Idle analysis | None | None | Pilot fish |
| Speed | Linear | Linear | Bounded by slowest parallel task |

---

## Timing Budget

| Operation | Action |
|-----------|--------|
| File read < 2s | Inline |
| Web search 5-30s | Spawn sub-shark |
| SSH command 10-120s | Spawn sub-shark |
| Build/test 30-300s | Spawn sub-shark |
| Coding agent 60-600s | Spawn sub-shark |
| Pre-analysis (pilot fish) | Spawn with `runTimeoutSeconds` |

---

## Related

- [Ralph Loop](https://ghuntley.com/ralph/) — the sequential iteration pattern this builds on
- [OpenClaw](https://openclaw.ai) — agent framework
- [ClawHub](https://clawhub.com/skill/shark) — skill registry

## Author

[Evgeny Knyazev](https://github.com/keugenek)

## License

MIT
