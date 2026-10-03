---
name: codex-collaboration
description: Use when Claude should collaborate directly with local Codex on this machine, choose between Codex MCP, `codex exec`, or file-based handoff, prepare a crisp HAVEN handoff, or ask Codex to install, sync, package, or verify Claude skills for Claude Code or Claude Desktop.
when_to_use: Trigger when the user wants Claude to work with Codex, delegate bounded coding work to Codex, inspect how Codex is configured locally, or leave a durable handoff between Claude and Codex in the HAVEN repos.
argument-hint: "[task, repo path, or handoff goal]"
---

# Codex Collaboration

Use this skill when Claude should work with Codex rather than only reasoning locally.

## First read

Read:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/Claude_Skills_and_Codex_Collaboration.md`

## The one-minute rule

**The `codex-local` MCP tool call times out after 60 seconds.** This is a hard
ceiling on the *call*, not on Codex. Codex keeps working on the Mac after the
timeout — it will edit files, run builds, and finish the job — but the caller
gets an error instead of a result. That means:

- **No report.** Whatever Codex concluded is lost unless it wrote it to a file.
- **No thread id.** `codex-reply` needs one, so the session cannot be steered,
  corrected, or asked a follow-up question. It is fire-and-forget.

So the decision is not "MCP if available" but "how long will this take?"

- **Under a minute** — a lookup, a single small edit, a question about local
  configuration: use the MCP call and read the result.
- **Anything else** — a build, a test run, more than a couple of file edits, or
  any task whose length is unknown: treat MCP as fire-and-forget. Write a
  file-based handoff first, point the MCP call at it, and require Codex to write
  its report to a named file.

**Never re-fire the call after a timeout.** A retry does not resume anything —
it starts a *new* headless Codex session. Two or three of them then race on the
same files, and there is no console to see any of them. If a call times out,
assume the work started and go watch the filesystem.

## Watching a fire-and-forget session

Since there is no console, progress is only visible on disk:

- `git status` / `git diff` in the target repo — what has actually changed
- mtimes on the files Codex was asked to touch
- the report file you named in the handoff — its appearance is the finish line
- any build or test logs the repo's own scripts write

Read this evidence carefully before drawing conclusions. A long build looks a lot
like a hung process, and a harness script that rewrites its own status file looks
a lot like a restart loop. Do not tell the user to kill processes on the strength
of an inference — say what you observe, say what you cannot see, and let them
look. Being wrong here costs them a 30-minute build.

## Preferred order

1. **File-based handoff plus an MCP call that points at it** — the default for
   any real work, because it survives the 60-second timeout.
2. **A bare MCP call** — only for work that will plainly finish inside a minute.
3. **`codex exec`** — when `codex` is on PATH and the user is at a terminal where
   they can watch it.

## Codex collaboration options

### 1. MCP server

If a Codex MCP server such as `codex-local` is configured:

- inspect the available Codex tools first instead of guessing names
- keep asks narrow and explicit
- for anything non-trivial, tell Codex up front that the caller may time out, so
  it should finish the work on disk and not wait for further input
- always name the file it must write its report to

### 2. Codex CLI

If `codex` is available on PATH, use it for bounded work such as:

- repository review
- targeted implementation
- test execution
- commit drafting

Prefer prompts that specify:

- repo path
- exact goal
- files or areas to inspect
- constraints
- required verification

Example pattern:

```bash
codex exec -C /Users/kjetil/Build/Digipomps/HAVEN/CellScaffold "Review the login skill wiring, update only the relevant files, run focused verification, and summarize risks."
```

### 3. File-based handoff

When direct integration is unavailable or too heavyweight, leave a concise handoff in one of these places:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/Operations/assistant_handoff.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/memory/context-ledger.md`
- a new dated note under `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/`

Before writing, read the existing file so you append or update without clobbering useful context.

## Handoff shape

A good Codex handoff should include:

- objective
- current state
- relevant files and docs
- constraints and non-goals
- verification expected — the exact commands, not "run the tests"
- the path Codex must write its report to
- open questions

Name the verification commands explicitly. Left to its own devices Codex may
reach for an old harness script it finds in the repo — one that builds and takes
screenshots but runs no tests at all.

## HAVEN-specific references

If the task is in CellScaffold or nearby HAVEN repos, look up the local guides referenced in:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/Claude_Skills_and_Codex_Collaboration.md`

## Special case: Claude skill installation and packaging

When the user wants Codex to help Claude use a skill, or wants a skill packaged for sharing:

1. tell Codex exactly which skill to create or update
2. ask Codex to sync the repo-local skill into:
   - `.claude/skills/`
   - `~/.claude/skills/`
3. ask Codex to rebuild the Desktop upload ZIP under:
   - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/ClaudeSkills/desktop-zips/`
4. on this machine, if Claude Desktop local agent mode must see the change immediately, ask Codex to also sync:
   - `/Users/kjetil/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/`
   by using:
   - `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Scripts/sync_claude_desktop_skills.py`
5. ask Codex to report the exact ZIP path so it can be shared with another person

Prompt shape to give Codex:

```text
Update the Claude skill `<skill-name>` based on this prompt and document any durable workflow changes. Sync it into project and user Claude skills, rebuild the Desktop ZIP, sync Claude Desktop local agent mode if needed, verify Claude can see it, and tell me the exact ZIP path so I can send it onward.
```

## Guardrails

- Do not assume Codex should edit broadly; keep scope explicit.
- Do not ask Codex to overwrite unrelated dirty worktree changes.
- Prefer the smallest verifiable task slice.
- Never re-fire a timed-out MCP call. One timeout means one running session; a
  second call means two sessions on the same files.
- When legal/regulatory or claim-safety questions are involved, combine this skill with the relevant HAVEN skill rather than replacing it.
