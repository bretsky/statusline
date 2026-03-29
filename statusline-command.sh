#!/usr/bin/env bash

# Claude Code status line: color-coded context usage with ASCII progress bar

input=$(cat)

eval "$(echo "$input" | python -c "
import sys, json
try:
    d = json.load(sys.stdin)
    cw = d.get('context_window', {}) or {}
    rem = cw.get('remaining_percentage', '')
    used = cw.get('used_percentage', '')
    model = (d.get('model') or {}).get('display_name', '')
    cwd = d.get('cwd', '')
    def q(v): return str(v).replace(\"'\", \"'\\\\''\")
    print(\"remaining='\" + q(rem) + \"'\")
    print(\"used='\" + q(used) + \"'\")
    print(\"model='\" + q(model) + \"'\")
    print(\"cwd='\" + q(cwd) + \"'\")
except Exception:
    print(\"remaining=''\")
    print(\"used=''\")
    print(\"model=''\")
    print(\"cwd=''\")
")"

# Git info derived from cwd
git_info=""
if [ -n "$cwd" ]; then
  git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_repo=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
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

if [ -z "$remaining" ]; then
  if [ -n "$git_info" ]; then
    printf "${CYAN}${git_info}${RESET}  ${DIM}${model}${RESET}"
  else
    printf "${DIM}${model}${RESET}"
  fi
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

# Build progress bar (20 chars wide)
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

printf "%b" "$out"
