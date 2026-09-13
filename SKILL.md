---
name: tmux-agents
description: "Coordinate parallel coding agents as windows in the user's own tmux server (separate `agents` session): spawn per-task agent windows, read what every agent is doing, send them prompts, wait for their output, and clean up. Use when the user wants work delegated to tmux agent windows, asks what other agent windows are doing, or wants the AI-company flow without Herdr."
---

# tmux agents

Parallel agents are tmux windows in a dedicated `agents` session on the user's default tmux server. No private sockets, no `-f /dev/null`, no extra tools. The user watches everything through their window overview (prefix `w`), which lists the `agents` session alongside their own.

## Naming, every task

- Task slug: kebab-case, derived from the task ("auth refactor" = `auth-refactor`).
- Window name = task slug: `auth-refactor`. Second agent on the same task: `auth-refactor-2`.
- Status file: `~/Developer/AI-Company/inbox/<slug>.md`, existing STATUS/DONE protocol.

Windows are the source of truth for who is busy. Name them right at spawn, never rename mid-task.

## Spawn

```bash
tmux has-session -t agents || tmux new-session -d -s agents
tmux new-window -t agents -n <slug> -c <task-cwd>
tmux send-keys -t agents:<slug> -l -- 'grok "Execute handoff: ~/Developer/AI-Company/handoffs/<slug>.md"'
tmux send-keys -t agents:<slug> Enter
```

## Awareness: what is everyone doing?

```bash
tmux list-panes -a -F '#{session_name}:#{window_index} #{window_name} [#{pane_current_command}]'
tmux capture-pane -p -J -t agents:<slug> -S -80 | tail -40
```

Run the first line before every handoff and whenever the user asks what other agents are doing. Run the second to read one agent's latest output. Report findings, do not just say "checked".

## Talk to an agent

```bash
tmux send-keys -t agents:<slug> -l -- "text of the prompt"
tmux send-keys -t agents:<slug> Enter
```

Always `-l` (literal), never let the shell mangle the text.

## Wait for output

```bash
~/.grok/skills/tmux-agents/scripts/wait-for-text.sh -t agents:<slug> -p 'pattern' [-F] [-T 20] [-i 0.5] [-l 2000]
```

Exits 0 on first match, 1 on timeout. Use before sending follow-up input. The user's shell prompt ends with `❯` (starship), wait for that to know a pane is idle. `tmux wait-for` does NOT watch pane output, never use it for that.

## Cleanup

- A task is done when its inbox file has a DONE line (with review evidence).
- Then: `tmux kill-window -t agents:<slug>`.
- Never kill a window whose inbox has no DONE line.
