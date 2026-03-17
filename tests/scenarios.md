# 🦈 Shark Pattern — Scenario Tests

These are **behavioural spec tests**. Each scenario describes a task an agent would receive,
the expected behaviour when following the Shark Pattern, and what would be wrong.

Used by the `scenario-check.sh` linter to verify SKILL.md covers each case.

---

## Scenario 1: Simple parallel research

**Input:** "Find the latest ChatterPC version, check if pve3 is up, and search for any new GitHub issues — then summarise"

**Expected behaviour:**
- ✅ Identifies 3 independent slow tasks
- ✅ Spawns 3 remoras in parallel (not sequentially)
- ✅ Main agent doesn't wait — reasons about what to expect
- ✅ Progress bar shown after first remora completes
- ✅ Pilot fish spawned when first remora returns early
- ✅ Final synthesis after all 3 complete

**Wrong behaviour:**
- ❌ Runs tasks one at a time
- ❌ Waits for each tool before spawning the next
- ❌ Spawns all then immediately yields and does nothing

**SKILL.md must cover:** Decision tree (>10s → spawn), parallel spawn, progress bar, pilot fish trigger

---

## Scenario 2: Fast task — do NOT spawn

**Input:** "What's the current version in package.json?"

**Expected behaviour:**
- ✅ Reads file inline (< 2s)
- ✅ No remoras spawned
- ✅ Answers directly

**Wrong behaviour:**
- ❌ Spawns a remora to read a local file
- ❌ Adds overhead for a trivial operation

**SKILL.md must cover:** Decision tree (< 10s → inline), fast tools list

---

## Scenario 3: Remora timeout

**Input:** "Run the full E2E test suite and report results"

**Expected behaviour:**
- ✅ Spawns remora with `runTimeoutSeconds: 300` (or appropriate budget)
- ✅ If remora times out, marks `⏱` in progress bar
- ✅ Uses partial result — reports what passed before timeout
- ✅ Does NOT re-spawn the same task
- ✅ Notes timeout in final summary: "E2E timed out — partial: 12/19 passed"

**Wrong behaviour:**
- ❌ Crashes or halts when remora times out
- ❌ Discards partial result
- ❌ Retries indefinitely

**SKILL.md must cover:** Error handling (timeout), `⏱` symbol, partial result handling

---

## Scenario 4: Nested remora attempt

**Input:** Agent is already running as a remora and encounters a slow tool

**Expected behaviour:**
- ✅ Executes slow tool inline (no nested spawning)
- ✅ Returns result to parent shark

**Wrong behaviour:**
- ❌ Spawns a remora from within a remora

**SKILL.md must cover:** No nested remoras rule

---

## Scenario 5: >50% remoras fail

**Input:** 4 remoras spawned, 3 crash immediately (network down)

**Expected behaviour:**
- ✅ Continues with 1 successful result
- ✅ Reports: "⚠️ degraded mode — 3/4 remoras failed"
- ✅ Falls back to sequential for any remaining critical work
- ✅ Does NOT spawn another full fleet

**Wrong behaviour:**
- ❌ Halts entirely
- ❌ Silently omits failure count
- ❌ Retries all 3 failed remoras

**SKILL.md must cover:** Degraded mode (>50% fail), error handling table

---

## Scenario 6: Pilot fish killed mid-analysis

**Input:** Pilot fish is pre-analysing remora A's result when remoras B and C both finish simultaneously

**Expected behaviour:**
- ✅ Pilot fish is killed (its timeout fires or parent kills it)
- ✅ Whatever partial output pilot fish produced is incorporated
- ✅ Synthesis proceeds with A + B + C + pilot fish partial draft

**Wrong behaviour:**
- ❌ Waits for pilot fish to finish before synthesising
- ❌ Discards pilot fish output entirely
- ❌ Spawns a new pilot fish after B and C arrive

**SKILL.md must cover:** Pilot fish rules (killed mid-run is expected, partial is useful)

---

## Scenario 7: Progress bar update

**Input:** 3 remoras running, first completes at 9s, second at 22s, third at 31s (timeout)

**Expected progress bar sequence:**

After 9s (remora A done):
```
🦈 3 remoras · 1 pilot fish

◉ [A] task A    ████████████ ✅ 9s
⊙ [B] task B    ███░░░░░░░░░ ~13s left
⊙ [C] task C    ███░░░░░░░░░ ~22s left
◈ [P] Pilot     ░░░░░░░░░░░░ starting

↳ continuing...
```

After 22s (remora B done, pilot fish killed):
```
◉ [A] task A    ████████████ ✅ 9s
◉ [B] task B    ████████████ ✅ 22s
⊙ [C] task C    ████████░░░░ ~9s left
◈ [P] Pilot     ████████████ ✅ killed (partial used)
```

After 31s (remora C timeout):
```
◉ [A] task A    ████████████ ✅ 9s
◉ [B] task B    ████████████ ✅ 22s
◉ [C] task C    ████████████ ⏱ 30s [timeout]

🦈 All fins in — synthesising 3 results (1 timeout)
```

**SKILL.md must cover:** Progress bar symbols, fill formula, update-on-event rule

---

## Scenario 8: Infinite run / no timeout set

**Input:** Agent spawns a remora with no `runTimeoutSeconds` to run a long-running build

**Expected behaviour:**
- ✅ Remora is spawned with an explicit `runTimeoutSeconds` budget
- ✅ Main agent notes the expected completion time
- ✅ If remora runs past budget, it is killed and marked ⏱

**Wrong behaviour:**
- ❌ Spawns remora with no timeout
- ❌ Waits indefinitely for remora to return
- ❌ Blocks main loop until remora finishes

**SKILL.md must cover:** Mandatory timeout on every remora spawn, timeout budget selection

---

## Scenario 9: Deadlock — remora waiting on main agent

**Input:** Main agent spawns remora A; remora A sends a message back asking the main agent for input before it can proceed

**Expected behaviour:**
- ✅ Main agent detects the remora is stalled (no result after expected time)
- ✅ Kills the stalled remora
- ✅ Falls back to inline execution for that task
- ✅ Notes the deadlock in the summary

**Wrong behaviour:**
- ❌ Main agent waits for remora to complete (which never happens)
- ❌ Both agents are blocked — true deadlock
- ❌ No timeout kills the stalled remora

**SKILL.md must cover:** Deadlock prevention, remora autonomy requirement (remoras must not require input from parent), stall detection

---

## Scenario 10: Skill violation — agent waits >30s in a single turn

**Input:** Agent fetches a URL, waits for it (35s), then processes the result in the same turn

**Expected behaviour:**
- ✅ Agent recognises the fetch will take >10s
- ✅ Spawns remora before the fetch
- ✅ Main turn completes in <30s
- ✅ Remora returns with the fetch result

**Wrong behaviour:**
- ❌ Agent fetches inline and waits >30s
- ❌ User receives no response for 35+ seconds
- ❌ Single turn blocks the entire conversation

**SKILL.md must cover:** 30s hard limit per turn, >10s threshold triggers remora spawn

---

## Scenario 11: Bad response — synthesis missing failed remoras

**Input:** 3 remoras run; 1 fails with an error. Agent synthesises results and mentions only the 2 successful ones.

**Expected behaviour:**
- ✅ Failed remora is noted in the progress bar with ❌
- ✅ Final synthesis explicitly mentions the failure: "Note: task X failed — [error]"
- ✅ User knows which part of the answer is incomplete

**Wrong behaviour:**
- ❌ Silently omits the failed remora
- ❌ Synthesis reads as if all 3 completed
- ❌ User has no idea part of the answer is missing

**SKILL.md must cover:** Failed remora reporting, synthesis completeness, ❌ symbol in progress bar

---

## Scenario 12: shark-exec — background exec happy path

**Input:** Agent needs to run `gh run watch 12345` (expected ~45s)

**Expected behaviour:**
- ✅ Reads shark-exec/SKILL.md before running
- ✅ Sends immediate ack: "⏳ CI: run #12345 — watching in background (max 120s)..."
- ✅ Calls exec with background: true, yieldMs: 500
- ✅ Writes job to shark-exec/state/pending.json with real Date.now() timestamp
- ✅ Creates cron job (everyMs: 15000), writes cronJobId back to pending.json
- ✅ Main turn completes in <30s
- ✅ Cron delivers result to user when done

**Wrong behaviour:**
- ❌ Runs exec inline without background:true
- ❌ Uses hardcoded startedAt timestamp
- ❌ Forgets to write cronJobId back to state
- ❌ Creates multiple cron jobs for multiple parallel commands

**SKILL.md must cover:** shark-exec protocol, state file format, cronJobId write-back

---

## Scenario 13: shark-exec — process exits before first poll

**Input:** Agent runs a command that finishes in 5s (faster than the 15s cron interval)

**Expected behaviour:**
- ✅ Exec result arrives as a system event in the main session
- ✅ Agent reads the system event output and delivers it directly to user
- ✅ Removes the job from pending.json
- ✅ Removes the cron job (nothing to poll)

**Wrong behaviour:**
- ❌ Cron fires, gets "session not found", sends confusing error to user
- ❌ Agent ignores the system event and waits for cron
- ❌ Leaves orphaned cron job running after job completes

**SKILL.md must cover:** Fast-exit handling, system event delivery path

---

## Running These Tests

These scenarios are checked structurally by `lint.sh`.
For full behavioural testing, use the scenario prompts manually with your agent of choice
and verify it follows the expected behaviour above.
