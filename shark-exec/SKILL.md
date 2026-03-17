---
name: shark-exec
version: 0.1.0
summary: "Background shell execution with guaranteed <30s reply. Wraps slow commands in exec+cron so the main agent never blocks."
tags: [async, shell, background, shark, non-blocking]
---

# shark-exec

**Never block the main turn.** This skill wraps any slow shell command in a background `exec` + cron poller, so the agent always replies to the user within 30 seconds — even if the command takes 10 minutes.

---

## When to Use

Use this skill whenever you're about to call `exec` and the command is expected to take **more than ~5 seconds**. Examples:

- `gh run watch <run-id>` — waiting for CI
- `npm run build` / `pytest` / `cargo build`
- `docker build`, `docker pull`
- Long-running SSH remote commands
- Any `exec` with `yieldMs > 10000`
- Any command that polls, watches, or tails output

**Do NOT use for:**
- Quick reads (`cat`, `ls`, `git status`) — inline is fine
- Commands you're confident finish in <5s

---

## Protocol (Step by Step)

### Step 1 — Send Immediate Acknowledgment

Before spawning the background job, send the user a reply:

```
⏳ [label] running in background (max Xs)...
```

Example: `⏳ CI: run #12345 — watching in background (max 120s)...`

This must be the **first thing you do** — before exec, before writing state. Silence = failure.

### Step 2 — Launch Background Exec

Call `exec` with:
- `background: true`
- `yieldMs: 500` (returns sessionId almost immediately)

```json
{
  "command": "gh run watch 12345",
  "background": true,
  "yieldMs": 500
}
```

You'll get back a `sessionId` (e.g. `"sess-abc-123"`).

### Step 3 — Write State

Read `C:\Users\Admin\clawd\skills\shark-exec\state\pending.json`. If it doesn't exist, start with `{"jobs": []}`.

Append your new job:

```json
{
  "jobs": [
    {
      "sessionId": "sess-abc-123",
      "label": "CI: run #12345",
      "command": "gh run watch 12345",
      "startedAt": "<use Date.now() in ms — e.g. from session_status or JS: new Date().getTime()>",
      "maxSeconds": 120,
      "cronJobId": null
    }
  ]
}
```

**Critical:** `startedAt` must be the actual current timestamp in milliseconds (`Date.now()`), not a hardcoded placeholder. Get it from `session_status` or use the current time.

Set `cronJobId: null` for now — you'll fill it in step 4.

### Step 4 — Create Cron Job

Create a cron job via the OpenClaw cron API. The cron message instructs an isolated agent to poll pending jobs and deliver results.

**Cron payload:**

```json
{
  "schedule": {"kind": "every", "everyMs": 15000},
  "payload": {
    "kind": "agentTurn",
    "message": "Check C:\\Users\\Admin\\clawd\\skills\\shark-exec\\state\\pending.json for pending background jobs. For each entry: call process(action=poll, sessionId=X, timeout=3000). If completed, send the result to telegram:210770893 and remove the entry from pending.json. If still running and startedAt + maxSeconds*1000 < Date.now(), kill it with process(action=kill, sessionId=X) and send partial output with '⏱ killed after Xs'. After processing all entries, if pending.json jobs array is empty, delete this cron job (cronJobId is stored in the state file under cronJobId field)."
  },
  "sessionTarget": "isolated",
  "delivery": {"mode": "none"}
}
```

Once you have the `cronJobId`, **immediately update the state file** to store it:

```json
{ "sessionId": "sess-abc-123", ..., "cronJobId": "the-cron-id-returned" }
```

This is required so the cron agent can self-delete when done.

> **Important:** Only create ONE cron job per session, even if there are multiple concurrent background jobs. The single cron will poll all entries in pending.json.

### Step 5 — Cron Fires (Every 15s)

The cron agent will:

1. Read `pending.json`
2. For each job, call `process(action=poll, sessionId=X, timeout=3000)`
3. If **completed**: send result to user, remove from jobs array, save pending.json
4. If **still running** and **past maxSeconds**: kill the process, send partial output + timeout message
5. If **still running** and within maxSeconds: leave in place, cron will retry in 15s
6. If jobs array is empty after processing: delete the cron job

### Step 6 — Result Delivery Format

**Success:**
```
✅ CI: run #12345 completed (47s)

<output truncated to last 50 lines if long>
```

**Timeout/Kill:**
```
⏱ CI: run #12345 killed after 120s

Last output:
<last 20 lines of output>
```

**Process already exited before first poll** (common when the command finishes in <15s):
```
✅ CI: run #12345 — completed before first poll
Output: <last output from exec result in the system event>
```
In this case, the exec result arrives as a system event in the main session. Read it from there and deliver it directly — no need for cron at all.

**Error (process not found / session lost):**
```
❌ CI: run #12345 — session not found (process may have exited before poll; check last system event for output)
```

---

## State File Format

**Path:** `C:\Users\Admin\clawd\skills\shark-exec\state\pending.json`

```json
{
  "jobs": [
    {
      "sessionId": "sess-abc-123",
      "label": "CI: run #12345",
      "command": "gh run watch 12345",
      "startedAt": 1710000000000,
      "maxSeconds": 120,
      "cronJobId": "cron-xyz-456"
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `sessionId` | string | From exec response |
| `label` | string | Human-readable name shown in ack/result |
| `command` | string | The shell command that was run |
| `startedAt` | number | `Date.now()` at launch time (ms) |
| `maxSeconds` | number | Kill threshold (default: 120) |
| `cronJobId` | string\|null | Cron job ID for cleanup; null until created |

---

## maxSeconds Defaults

| Command type | Suggested maxSeconds |
|---|---|
| `gh run watch` | 300 (CI can be slow) |
| `npm run build` | 180 |
| `docker build` | 600 |
| `pytest` / `cargo test` | 300 |
| Generic unknown | 120 |
| User-specified | Honor their request |

If the user says "wait up to 10 minutes", use `maxSeconds: 600`.

---

## Multiple Concurrent Jobs

If there's already a cron job running (check `cronJobId` in any existing job in pending.json), **do not create a new cron job**. Just add your new job to the array. The existing cron will pick it up on its next tick.

Algorithm:
1. Read pending.json
2. If `jobs.length > 0` and any job has a non-null `cronJobId` → reuse that cronJobId, just append new job
3. If `jobs.length === 0` or all `cronJobId` are null → create a new cron job, then update state

---

## Error Handling

### `process(action=poll)` throws "session not found"
→ Remove the job from pending.json, send:
`❌ [label] — session lost (process may have crashed or the exec session expired)`

### Output is very long
→ Truncate to last 50 lines. Always append truncation notice:
`[output truncated — showing last 50 lines of N total]`

### pending.json is corrupted/invalid JSON
→ Reset to `{"jobs": []}`, send:
`⚠️ shark-exec: pending.json was corrupted and has been reset. Background jobs may have been lost.`

### exec returns no sessionId
→ Fall back to inline exec. Do not use shark-exec for that command.

---

## Full Example: Replacing `gh run watch`

### ❌ Old (blocking) way:
```
exec("gh run watch 12345")
// Agent blocks for 3 minutes, user gets no reply
```

### ✅ New (shark-exec) way:

**Turn 1 (main agent):**
1. Send: `⏳ CI: run #12345 — watching in background (max 300s)...`
2. `exec("gh run watch 12345", background=true, yieldMs=500)` → `sessionId: "sess-9f3a"`
3. Write to pending.json:
   ```json
   {
     "jobs": [{
       "sessionId": "sess-9f3a",
       "label": "CI: run #12345",
       "command": "gh run watch 12345",
       "startedAt": 1710005200000,
       "maxSeconds": 300,
       "cronJobId": null
     }]
   }
   ```
4. Create cron (everyMs: 15000, agentTurn message as above) → `cronJobId: "cron-8b2c"`
5. Update pending.json with `cronJobId: "cron-8b2c"`
6. **Main turn ends. User got their reply in <5s.**

**~47 seconds later (cron fires 3 times, 3rd time it's done):**
1. Cron agent reads pending.json → finds `sess-9f3a`
2. `process(poll, sess-9f3a, timeout=3000)` → status: completed, output: "Run #12345 completed: success"
3. Sends to telegram:210770893:
   ```
   ✅ CI: run #12345 completed (47s)

   Run #12345 (main / push) · Completed successfully
   Jobs: build ✓, test ✓, deploy ✓
   ```
4. Removes job from pending.json → jobs array empty
5. Deletes cron job `cron-8b2c`

---

## Quick Reference Checklist

Before every `exec` call:
- [ ] Will this take >5s? → Use shark-exec
- [ ] Send ack message **first**
- [ ] `exec(background=true, yieldMs=500)`
- [ ] Write to pending.json
- [ ] Create or reuse cron job
- [ ] Update cronJobId in state

---

## Helper Script

`scripts/poll-and-deliver.js` — run to inspect current pending jobs:

```bash
node C:\Users\Admin\clawd\skills\shark-exec\scripts\poll-and-deliver.js
```

Prints a human-readable summary of all pending jobs, their ages, and whether they're past maxSeconds. Useful for debugging stuck jobs.
