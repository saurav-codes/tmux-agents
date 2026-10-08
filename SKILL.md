---
name: tmux-agents
description: "Coordinate parallel coding agents as panes in the user's own tmux server (separate `agents` session, one tiled `work` window): spawn per-task agent panes, read what every agent is doing, send them prompts, wait for their output, log and debug them, and clean up. Use when the user wants work delegated to tmux agent panes, asks what other agent panes are doing, or runs a large multi-agent debugging session."
---

# tmux agents

Agents are panes in the `agents` session on the user's default tmux server, tiled in one `work` window so the user watches them live. Scripts live in `scripts/` next to this file. Examples use `$SKILL` for this skill's directory.

## Ownership, the hard rule

The user runs their own panes in this session too. Typing into one destroys live work, and it has happened.

- An agent pane is one spawned with the recipe below, so it carries the `@agent` pane option. A pane without it is the user's.
- Never `send-keys`, `kill-pane`, `respawn-pane`, `resize-pane`, `swap-pane` or retitle a pane that isn't yours, no matter how idle it looks.
- Unsure about a target: spawn a fresh pane. Never reuse a pane you merely found.
- Target panes by id (`%24`) only. Session or window targets like `-t agents` resolve to the active pane, which is usually the user's.

## Spawn

```bash
tmux has-session -t agents 2>/dev/null || tmux new-session -d -s agents -n work
tmux list-windows -t agents -F '#{window_name}' | grep -qx work || tmux new-window -d -t agents -n work
PANE=$(tmux split-window -d -t agents:work -c "<task-cwd>" -P -F '#{pane_id}')
[ -n "$PANE" ] || { echo 'spawn failed, no pane id' >&2; exit 1; }
tmux set -p -t "$PANE" @agent "<slug>"           # durable identity, survives respawn
tmux set -p -t "$PANE" remain-on-exit on          # keep output if the agent crashes
tmux select-pane -t "$PANE" -T "<slug>"
tmux select-layout -t agents:work tiled
mkdir -p /tmp/agents && tmux pipe-pane -o -t "$PANE" "cat >> /tmp/agents/<slug>.log"
```

- Slug: kebab-case from the task (`auth-refactor`, then `auth-refactor-2`). Keep the pane id you got back.
- Titles are for humans only. The program inside overwrites them, so find agents by `@agent` or pane id.
- Repo tasks get their own worktree so agents never share a checkout: `git -C <repo> worktree add -b <slug> <repo>/../.wt/<slug>`, then spawn with that path as `-c`.

Wait for the shell prompt, then start the agent:

```bash
$SKILL/scripts/wait-for-text.sh -t "$PANE" -p '❯' -T 10
tmux send-keys -t "$PANE" -l -- 'grok "<task prompt>"'
tmux send-keys -t "$PANE" Enter
```

## Awareness

```bash
$SKILL/scripts/snapshot.sh 30          # every agent pane: id, slug, command, dead/alive, last 30 lines
tmux list-panes -a -F '#{session_name}:#{window_name} #{pane_id} @agent=#{@agent} [#{pane_current_command}] dead=#{pane_dead}' | grep '^agents:'
```

Run one before spawning and whenever the user asks what agents are doing. Report findings, not just "checked".

## Talk, interrupt, wait

```bash
tmux send-keys -t <pane-id> -l -- "prompt text"; tmux send-keys -t <pane-id> Enter   # always -l
tmux send-keys -t <pane-id> Escape          # stop the agent's current turn (C-c to kill a shell command)
$SKILL/scripts/wait-for-text.sh -t <pane-id> -p 'pattern' [-F] [-T 60]           # 0 on match, 1 on timeout
```

`tmux wait-for` does not watch output. It is a signal channel: tell an agent to finish with `tmux wait-for -S <slug>-done`, and the lead blocks on `tmux wait-for <slug>-done`. Run that in the background or behind a timeout, since it never returns if the agent forgets to signal.

## Debugging sessions

For many agents or long runs, keep evidence outside the scrollback:

| Need | Command |
|---|---|
| Full history of one pane | `tmux capture-pane -p -J -t <id> -S - > /tmp/agents/<slug>.txt` |
| Live log (started at spawn) | `tail -f /tmp/agents/<slug>.log`, raw with colors; use `capture-pane` for clean text |
| Grep every agent at once | `$SKILL/scripts/snapshot.sh 2000 \| grep -n -E 'error\|panic\|FAIL'` |
| Did it crash, and how | `tmux display -p -t <id> 'dead=#{pane_dead} status=#{pane_dead_status}'` |
| Restart a crashed agent in place | `tmux respawn-pane -k -t <id> -c <cwd>`; `@agent` and logging survive |
| Focus one pane | `tmux resize-pane -Z -t <id>` (toggle zoom), or `break-pane -d -s <id>` to give it a window |
| Its process tree | `pgrep -lP $(tmux display -p -t <id> '#{pane_pid}')` |
| Fresh scrollback before a rerun | `tmux clear-history -t <id>` |

Never use `synchronize-panes`: one keystroke would land in every pane, including the user's.

## Cleanup

- Kill a pane only after its agent has finished and you have its result. Never kill a pane that lacks `@agent`.
- `tmux kill-pane -t <id>`, then `git -C <repo> worktree remove <repo>/../.wt/<slug>` if one was made.
- Keep `/tmp/agents/<slug>.log` until the user has what they need.
