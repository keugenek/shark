# 🦈 The Shark Pattern

> *A shark that stops swimming dies. An agent that waits for tools wastes compute.*

## What Is This?

The **Shark Pattern** is a non-blocking execution model for [OpenClaw](https://openclaw.ai) agents.

**The rule:** Every LLM turn completes in under 30 seconds. Slow operations get spawned as sub-agents. The main agent never waits.

## The Problem

Most agents work sequentially:
```
think → slow tool → WAIT 45s → think → slow tool → WAIT 30s → ...
```
90% of runtime is spent waiting for tools, not thinking.

## The Solution

```
think → spawn(web search)  ─────────────────────────────► result
      → spawn(SSH command) ──────────────────► result      
      → spawn(build/test)  ────────────────────────────────────► result
      → think while all of these run in parallel
      → incorporate results → swim on
```

## Comparison

| | Ralph Loop | Shark Pattern |
|--|--|--|
| Execution | Sequential, blocking | Parallel, non-blocking |
| Tool wait | Main agent waits | Spawns sub-shark, keeps moving |
| Speed | Linear | Bounded by slowest parallel task |
| Complexity | Simple | Slightly more orchestration |

## Install

```bash
npx clawhub@latest install shark
```

## Usage

Tell your OpenClaw agent:
- "Use shark mode"
- "Non-blocking — spawn where needed"  
- "Keep swimming"
- "Never wait for tools"

## Timing Budget

| Operation | Max inline | Action |
|-----------|-----------|--------|
| File read | < 2s | Inline |
| Web search | 5-30s | Spawn |
| SSH command | 10-120s | Spawn |
| Build/test run | 30-300s | Spawn |
| Coding agent | 60-600s | Spawn |

## Hard Limits

- ❌ Never `yieldMs > 30000`
- ❌ Never `sleep` in main thread  
- ❌ Never block on unknown-latency operations
- ✅ Max 8 concurrent sub-sharks
- ✅ Always reason while waiting

## Related

- [Ralph Loop](https://ghuntley.com/ralph/) — the sequential iteration pattern this builds on
- [OpenClaw](https://openclaw.ai) — the agent framework
- [ClawHub](https://clawhub.com) — skill registry

## Author

[Evgeny Knyazev](https://github.com/keugenek) — [keugenek](https://github.com/keugenek)

## License

MIT
