#!/usr/bin/env bash

# Claude Code status line: color-coded context usage with ASCII progress bar

input=$(cat)

remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
cost_usd=$(printf '%s' "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
v = (d.get('cost') or {}).get('total_cost_usd')
print('\$%.4f' % v if v is not None else '')
" 2>/dev/null)

# Git info derived from cwd
git_info=""
if [ -n "$cwd" ]; then
  git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  if [ -n "$git_branch" ] && [ -n "$git_repo" ]; then
    git_info="${git_repo}:${git_branch}"
  fi
fi

# ANSI color codes
RESET="\033[0m"
DIM="\033[2m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BRIGHT_RED="\033[1;31m"
CYAN="\033[36m"
MAGENTA="\033[35m"

if [ -z "$remaining" ]; then
  out=""
  if [ -n "$git_info" ]; then
    out="${CYAN}${git_info}${RESET}  "
  fi
  out="${out}${DIM}${model}${RESET}"
  if [ -n "$cost_usd" ]; then
    out="${out}  ${MAGENTA}${cost_usd}${RESET}"
  fi
  printf "%b" "$out"
  exit 0
fi

# Determine color based on usage thresholds
used_int=$(printf "%.0f" "$used")
if [ "$used_int" -ge 90 ]; then
  COLOR="$BRIGHT_RED"
  FILL="━"
elif [ "$used_int" -ge 75 ]; then
  COLOR="$RED"
  FILL="━"
elif [ "$used_int" -ge 50 ]; then
  COLOR="$YELLOW"
  FILL="━"
else
  COLOR="$GREEN"
  FILL="━"
fi

# Build progress bar (15 chars wide)
bar_width=20
filled=$(( used_int * bar_width / 100 ))
empty=$(( bar_width - filled ))

bar=""
for i in $(seq 1 $filled); do bar="${bar}${FILL}"; done
for i in $(seq 1 $empty); do bar="${bar}─"; done

remaining_int=$(printf "%.0f" "$remaining")

# Assemble output
out=""
if [ -n "$git_info" ]; then
  out="${CYAN}${git_info}${RESET}  "
fi
out="${out}${COLOR}${bar}${RESET} ${COLOR}${remaining_int}% left${RESET}"
out="${out}  ${DIM}${model}${RESET}"
if [ -n "$cost_usd" ]; then
  out="${out}  ${MAGENTA}${cost_usd}${RESET}"
fi

printf "%b" "$out"
