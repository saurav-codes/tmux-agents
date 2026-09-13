---
name: tmux-agents
description: "Coordinate parallel coding agents as panes in the user's own tmux server (separate `agents` session, one tiled split view): spawn per-task agent panes, read what every agent is doing, send them prompts, wait for their output, and clean up. Use when the user wants work delegated to tmux agent panes, asks what other agent panes are doing, or wants the AI-company flow without extra tools."
---

# tmux agents

Parallel agents are tmux panes in a dedicated `agents` session on the user's default tmux server, all in one tiled window so the user can watch every agent in real time. No private sockets, no `-f /dev/null`, no extra tools.

## Naming, every task

- Task slug: kebab-case, derived from the task ("auth refactor" = `auth-refactor`).
- Pane title = task slug: `auth-refactor`. Second agent on the same task: `auth-refactor-2`.
- Record each agent's pane id (printed at spawn, like `%24`) in the handoff; target panes by pane id, never by index.
- Status file: `~/Developer/AI-Company/inbox/<slug>.md`, existing STATUS/DONE protocol.

Pane titles are the source of truth for who is busy. Set them right at spawn, never rename mid-task.

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

Always `-l` (literal), never let the shell mangle the text.

## Wait for output

```bash
~/.grok/skills/tmux-agents/scripts/wait-for-text.sh -t <pane-id> -p 'pattern' [-F] [-T 20] [-i 0.5] [-l 2000]
```

Exits 0 on first match, 1 on timeout. Use before sending follow-up input. The user's shell prompt ends with `❯` (starship), wait for that to know a pane is idle. `tmux wait-for` does NOT watch pane output, never use it for that.

## Cleanup

- A task is done when its inbox file has a DONE line (with review evidence).
- Then: `tmux kill-pane -t <pane-id>`.
- Never kill a pane whose inbox has no DONE line. Never kill the user's own panes.
