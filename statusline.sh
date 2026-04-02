#!/bin/bash

# Gentleman theme colors (ANSI 256)
PRIMARY='\033[38;5;110m'      # #7FB4CA azul claro
ACCENT='\033[38;5;179m'       # #E0C15A dorado
SECONDARY='\033[38;5;146m'    # #A3B5D6 azul gris
MUTED='\033[38;5;242m'        # #5C6170 gris
SUCCESS='\033[38;5;150m'      # #B7CC85 verde
ERROR='\033[38;5;174m'        # #CB7C94 rosa/rojo
PURPLE='\033[38;5;183m'       # #C99AD6 púrpura
CYAN='\033[38;5;116m'         # cyan suave
ORANGE='\033[38;5;215m'       # naranja para output style
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Read JSON from stdin
input=$(cat)

# Parse basic fields
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Output style
OUTPUT_STYLE=$(echo "$input" | jq -r '.output_style.name // empty')

# Vim mode
VIM_MODE=$(echo "$input" | jq -r '.vim.mode // empty')

# Session name
SESSION_NAME=$(echo "$input" | jq -r '.session_name // empty')

# Worktree
WORKTREE_NAME=$(echo "$input" | jq -r '.worktree.name // empty')
WORKTREE_BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')

# Cost tracking
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf '%.2f' "$COST")

# Duration
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
DURATION_SEC=$((DURATION_MS / 1000))
MINS=$((DURATION_SEC / 60))
SECS=$((DURATION_SEC % 60))

# Token counts (cumulative session)
TOTAL_IN=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# Token speed (tokens/s based on API duration)
API_DURATION_MS=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
if [ "$API_DURATION_MS" -gt 0 ] 2>/dev/null; then
  TOTAL_TOKENS=$((TOTAL_IN + TOTAL_OUT))
  TOK_PER_SEC=$((TOTAL_TOKENS * 1000 / API_DURATION_MS))
else
  TOK_PER_SEC=0
fi

# Format token counts (k/M)
format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf '%.1fM' "$(echo "scale=1; $n / 1000000" | bc)"
  elif [ "$n" -ge 1000 ]; then
    printf '%.1fk' "$(echo "scale=1; $n / 1000" | bc)"
  else
    echo "$n"
  fi
}

IN_FMT=$(format_tokens "$TOTAL_IN")
OUT_FMT=$(format_tokens "$TOTAL_OUT")

# Context window
CTX_PERCENT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
[ -z "$CTX_PERCENT" ] && CTX_PERCENT=0
[ "$CTX_PERCENT" -gt 100 ] 2>/dev/null && CTX_PERCENT=100
[ "$CTX_PERCENT" -lt 0 ] 2>/dev/null && CTX_PERCENT=0

# Rate limits
RATE_5H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RATE_5H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RATE_7D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Directory name
DIR_NAME=$(basename "$DIR")

# Git info (cached)
GIT_CACHE="/tmp/claude_statusline_git"
GIT_CACHE_TTL=5
REMOTE_CACHE="/tmp/claude_statusline_remote"
REMOTE_CACHE_TTL=60

git_cache_stale() {
  [ ! -f "$GIT_CACHE" ] || \
  [ $(($(date +%s) - $(stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0))) -gt $GIT_CACHE_TTL ]
}

remote_cache_stale() {
  [ ! -f "$REMOTE_CACHE" ] || \
  [ $(($(date +%s) - $(stat -f %m "$REMOTE_CACHE" 2>/dev/null || echo 0))) -gt $REMOTE_CACHE_TTL ]
}

if git_cache_stale; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    DIRTY=""
    [[ -n $(git status --porcelain 2>/dev/null) ]] && DIRTY="*"
    echo "${BRANCH}|${DIRTY}" > "$GIT_CACHE"
  else
    echo "|" > "$GIT_CACHE"
  fi
fi

IFS='|' read -r BRANCH GIT_DIRTY < "$GIT_CACHE"

# Git remote URL (cached longer — doesn't change often)
GIT_REMOTE_URL=""
if [ -n "$BRANCH" ]; then
  if remote_cache_stale; then
    REMOTE_RAW=$(git remote get-url origin 2>/dev/null | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
    echo "$REMOTE_RAW" > "$REMOTE_CACHE"
  fi
  GIT_REMOTE_URL=$(cat "$REMOTE_CACHE" 2>/dev/null)
fi

# Model icon
MODEL_ICON="🤖"
case "$MODEL" in
  *Opus*) MODEL_ICON="🎭" ;;
  *Sonnet*) MODEL_ICON="📝" ;;
  *Haiku*) MODEL_ICON="🍃" ;;
esac

# Context progress bar
BAR_WIDTH=8
FILLED=$((CTX_PERCENT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

if [ "$CTX_PERCENT" -ge 80 ]; then
  BAR_COLOR="$ERROR"
elif [ "$CTX_PERCENT" -ge 50 ]; then
  BAR_COLOR="$ACCENT"
else
  BAR_COLOR="$SUCCESS"
fi

BAR="${BAR_COLOR}"
for ((i=0; i<FILLED; i++)); do BAR+="█"; done
BAR+="${MUTED}"
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
BAR+="${NC}"

# Rate limit color
rate_color() {
  local pct=$(printf '%.0f' "$1")
  if [ "$pct" -ge 80 ]; then echo "$ERROR"
  elif [ "$pct" -ge 50 ]; then echo "$ACCENT"
  else echo "$SUCCESS"
  fi
}

# Format rate limit reset time
format_reset() {
  local reset_at=$1
  local now=$(date +%s)
  local diff=$((reset_at - now))
  if [ "$diff" -le 0 ]; then
    echo "now"
  elif [ "$diff" -lt 3600 ]; then
    echo "$((diff / 60))m"
  else
    echo "$((diff / 3600))h$((diff % 3600 / 60))m"
  fi
}

# === LINE 1: Model, dir, git (clickable), worktree, lines changed ===
SEP="${MUTED}  ${NC}"

LINE1="${BOLD}${PURPLE}${MODEL_ICON} ${MODEL}${NC}"

# Output style (if set and not "default")
if [ -n "$OUTPUT_STYLE" ] && [ "$OUTPUT_STYLE" != "default" ]; then
  LINE1+=" ${ORANGE}${OUTPUT_STYLE}${NC}"
fi

# Vim mode
if [ -n "$VIM_MODE" ]; then
  if [ "$VIM_MODE" = "NORMAL" ]; then
    LINE1+=" ${SUCCESS}N${NC}"
  else
    LINE1+=" ${CYAN}I${NC}"
  fi
fi

LINE1+="${SEP}"

# Session name or directory
if [ -n "$SESSION_NAME" ]; then
  LINE1+="${PRIMARY}⚡${SESSION_NAME}${NC}${SEP}"
fi

LINE1+="${ACCENT}󰉋 ${DIR_NAME}${NC}"

# Git branch — clickable if remote URL available
if [ -n "$BRANCH" ]; then
  LINE1+="${SEP}"
  if [ -n "$GIT_REMOTE_URL" ]; then
    BRANCH_URL="${GIT_REMOTE_URL}/tree/${BRANCH}"
    LINE1+="\033]8;;${BRANCH_URL}\a${SECONDARY} ${BRANCH}${GIT_DIRTY}\033]8;;\a${NC}"
  else
    LINE1+="${SECONDARY} ${BRANCH}${GIT_DIRTY}${NC}"
  fi
fi

# Worktree indicator
if [ -n "$WORKTREE_NAME" ]; then
  LINE1+="${SEP}"
  LINE1+="${CYAN}🌲${WORKTREE_NAME}${NC}"
fi

LINE1+="${SEP}"
LINE1+="${SUCCESS}+${ADDED}${NC} ${ERROR}-${REMOVED}${NC}"

# === LINE 2: Context bar, cost, tokens, speed, duration, rate limits ===
LINE2="${MUTED}ctx${NC} ${BAR} ${MUTED}${CTX_PERCENT}%${NC}"
LINE2+="${SEP}"
LINE2+="${ACCENT}\$${COST_FMT}${NC}"
LINE2+="${SEP}"
LINE2+="${CYAN}↓${IN_FMT}${NC} ${PURPLE}↑${OUT_FMT}${NC}"

# Token speed
if [ "$TOK_PER_SEC" -gt 0 ]; then
  LINE2+=" ${DIM}${MUTED}${TOK_PER_SEC}t/s${NC}"
fi

LINE2+="${SEP}"
LINE2+="${MUTED}${MINS}m${SECS}s${NC}"

# Rate limits (only if available)
if [ -n "$RATE_5H" ]; then
  RATE_5H_INT=$(printf '%.0f' "$RATE_5H")
  RATE_5H_COLOR=$(rate_color "$RATE_5H")
  LINE2+="${SEP}"
  LINE2+="${MUTED}5h${NC} ${RATE_5H_COLOR}${RATE_5H_INT}%${NC}"
  if [ -n "$RATE_5H_RESET" ]; then
    RESET_FMT=$(format_reset "$RATE_5H_RESET")
    LINE2+="${DIM}${MUTED}→${RESET_FMT}${NC}"
  fi
fi

if [ -n "$RATE_7D" ]; then
  RATE_7D_INT=$(printf '%.0f' "$RATE_7D")
  RATE_7D_COLOR=$(rate_color "$RATE_7D")
  LINE2+=" ${MUTED}7d${NC} ${RATE_7D_COLOR}${RATE_7D_INT}%${NC}"
fi

printf '%b\n' "$LINE1"
printf '%b\n' "$LINE2"
