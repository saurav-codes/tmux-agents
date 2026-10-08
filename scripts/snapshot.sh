#!/usr/bin/env bash
# Print every agent pane (panes with the @agent option) and its last N lines.
set -euo pipefail

lines="${1:-30}"
if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
  echo "usage: snapshot.sh [lines]" >&2
  exit 1
fi

panes="$(tmux list-panes -a -F '#{pane_id}	#{@agent}	#{pane_current_command}	#{pane_dead}	#{pane_dead_status}' | awk -F '\t' '$2 != ""')"
if [[ -z "$panes" ]]; then
  echo "no agent panes"
  exit 0
fi

while IFS=$'\t' read -r id slug cmd dead status; do
  state="alive"
  [[ "$dead" == "1" ]] && state="DEAD exit=$status"
  printf '===== %s %s [%s] %s\n' "$id" "$slug" "$cmd" "$state"
  tmux capture-pane -p -J -t "$id" -S "-$lines" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
done <<< "$panes"
