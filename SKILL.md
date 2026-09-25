---
name: tmux-agents
description: "Coordinate parallel coding agents as panes in the user's own tmux server (separate `agents` session, one tiled split view): spawn per-task agent panes, read what every agent is doing, send them prompts, wait for their output, and clean up. Use when the user wants work delegated to tmux agent panes, asks what other agent panes are doing, or wants the AI-company flow without extra tools."
---

# tmux agents

Parallel agents are tmux panes in a dedicated `agents` session on the user's default tmux server, all in one tiled window so the user can watch every agent in real time. No private sockets, no `-f /dev/null`, no extra tools.

## Ownership, the hard rule

The user runs their own panes and windows in this session too: brainstorming, research, their orchestrator sessions. An agent typing into one destroys live work, and it has happened.

- Touch only panes that are agent-created: the pane your own `split-window` printed this session, or a pane id recorded in a handoff/inbox file.
- A pane or window created by the human is off-limits: never `send-keys`, `kill-pane`, `swap-pane`, `resize-pane`, or retitle it, no matter how idle it looks.
- Unknown or ambiguous target: spawn a fresh pane. Never guess, never reuse a pane you merely found.
- `agents:work` belongs to this workflow, the spawn recipe below creates it. Other windows in the session are the user's, leave them alone.

## Naming, every task

- Task slug: kebab-case, derived from the task ("auth refactor" = `auth-refactor`).
- Pane title = task slug: `auth-refactor`. Second agent on the same task: `auth-refactor-2`.
- Record each agent's pane id in the handoff as a `pane: %24` line. The pane id is the only durable identity of a pane; target panes by that id only, never by index, title, session, or window.
- Status file: `~/Developer/AI-Company/inbox/<slug>.md`, existing STATUS/DONE protocol.

Titles are labels for humans, not identity. The program running in a pane overwrites the title with its own while it runs (grok sets a spinner and task name, zsh sets the hostname), so never find or target a pane by title.

## Spawn

```bash
tmux has-session -t agents || tmux new-session -d -s agents -n work
PANE=$(tmux split-window -t agents:work -c <task-cwd> -P -F '#{pane_id}')
tmux select-pane -t "$PANE" -T <slug>
tmux select-layout -t agents:work tiled
tmux send-keys -t "$PANE" -l -- 'grok "Execute handoff: ~/Developer/AI-Company/handoffs/<slug>.md"'
tmux send-keys -t "$PANE" Enter
```

Always panes, never windows: the user watches agents working live in the split view.

For repo tasks, isolate with a git worktree so parallel agents never collide in one checkout:

```bash
git -C <repo> worktree add -b <slug> <repo>/../.wt/<slug>   # then use that path as the -c value
```

Worktrees live in `<repo>/../.wt/`, one hidden sister dir holding all of them.

## Awareness: what is everyone doing?

```bash
tmux list-panes -t agents:work -F '#{pane_id} #{pane_title} [#{pane_current_command}]'
tmux capture-pane -p -J -t <pane-id> -S -80 | tail -40
```

Run the first line before every handoff and whenever the user asks what other agents are doing. Run the second to read one agent's latest output. Report findings, do not just say "checked".

## Talk to an agent

```bash
tmux send-keys -t <pane-id> -l -- "text of the prompt"
tmux send-keys -t <pane-id> Enter
```

Always `-l` (literal), never let the shell mangle the text. The pane id must be your own spawn's or the one recorded in that task's handoff file; a wrong target is someone's live session.

## Wait for output

```bash
~/.grok/skills/tmux-agents/scripts/wait-for-text.sh -t <pane-id> -p 'pattern' [-F] [-T 20] [-i 0.5] [-l 2000]
```

Exits 0 on first match, 1 on timeout. Use before sending follow-up input. The user's shell prompt ends with `❯` (starship), wait for that to know a pane is idle. `tmux wait-for` does NOT watch pane output, never use it for that.

## Cleanup

- A task is done when its inbox file has a DONE line (with review evidence).
- Then: `tmux kill-pane -t <pane-id>` (the id recorded in the handoff, nothing else).
- If spawned with a worktree, remove it: `git -C <repo> worktree remove <repo>/../.wt/<slug>`.
- Never kill a pane whose inbox has no DONE line. Never kill the user's own panes.
