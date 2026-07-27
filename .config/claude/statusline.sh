#!/usr/bin/env bash
# Claude Code custom statusline.
# Reads JSON from stdin. Prints one line with ANSI colors.

set -euo pipefail

INPUT=$(cat)

# ---- palette ----
RED=$'\033[38;5;196m'
GREEN=$'\033[38;5;42m'
YEL=$'\033[38;5;220m'
CYAN=$'\033[38;5;51m'
BLU=$'\033[38;5;39m'
R=$'\033[0m'

# ---- extract fields ----
CWD=$(printf '%s' "$INPUT" | jq -r '.workspace.current_dir // .cwd // "."')
COST=$(printf '%s' "$INPUT" | jq -r '.cost.total_cost_usd // 0')
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')

# ---- git branch ----
BRANCH=""
BR_COLOR="$GREEN"
if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
  [[ -z "$BRANCH" ]] && BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null || echo "?")
  case "$BRANCH" in
    master|main) BR_COLOR="$RED" ;;
    *)           BR_COLOR="$GREEN" ;;
  esac
fi

# ---- cumulative session tokens (deduplicated transcript messages) ----
TOTAL_TOK=0
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
  TOTAL_TOK=$(jq -Rn '
    [ inputs | fromjson? | select(.message.usage?) ]
    | unique_by(.message.id // .requestId // .uuid)
    | map(.message.usage
        | (.input_tokens // 0)
        + (.output_tokens // 0)
        + (.cache_read_input_tokens // 0)
        + (.cache_creation_input_tokens // 0))
    | add // 0
  ' "$TRANSCRIPT" 2>/dev/null || printf '0')
fi

fmt_num() {
  local n=$1
  if   (( n >= 1000000 )); then awk -v n="$n" 'BEGIN{printf "%.1fM", n/1000000}'
  elif (( n >= 1000 ));    then awk -v n="$n" 'BEGIN{printf "%.1fk", n/1000}'
  else printf '%d' "$n"
  fi
}

# ---- weather Hanoi (cached, refreshed in background) ----
WCACHE="/tmp/claude_weather_hanoi.txt"
WMAX=1800   # 30 min
now=$(date +%s)
mtime=0
[[ -f "$WCACHE" ]] && mtime=$(stat -c %Y "$WCACHE" 2>/dev/null || echo 0)
age=$(( now - mtime ))
if (( age > WMAX )); then
  ( curl -fsSL --max-time 4 'https://wttr.in/Hanoi?format=%t+%c+%h' \
      -o "$WCACHE.tmp" 2>/dev/null && mv "$WCACHE.tmp" "$WCACHE" ) &
fi
WEATHER="—"
[[ -s "$WCACHE" ]] && WEATHER=$(tr -d '\n' < "$WCACHE")

# ---- disk (free/total, %used) ----
read -r DISK DISK_PCT < <(
  df -hP / 2>/dev/null | awk 'NR==2 {pct=$5; gsub("%","",pct); print $4 "/" $2, pct}'
)
DISK=${DISK:---}; DISK_PCT=${DISK_PCT:-0}
DISK_COLOR="$GREEN"
if   (( DISK_PCT >= 90 )); then DISK_COLOR="$RED"
elif (( DISK_PCT >= 75 )); then DISK_COLOR="$YEL"
fi

# ---- ram (free/total in GiB, %used) — parsed from /proc/meminfo (kB) ----
read -r RAM RAM_PCT < <(
  awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { avail = $2 }
    END {
      if (total > 0) {
        used_pct = int(((total-avail)*100)/total)
        printf "%.1fG/%.1fG %d\n", avail/1048576, total/1048576, used_pct
      }
    }
  ' /proc/meminfo
)
RAM=${RAM:---}; RAM_PCT=${RAM_PCT:-0}
RAM_COLOR="$GREEN"
if   (( RAM_PCT >= 90 )); then RAM_COLOR="$RED"
elif (( RAM_PCT >= 75 )); then RAM_COLOR="$YEL"
fi

# ---- cpu (instant sample from /proc/stat, %) ----
read -r c1 u1 n1 s1 i1 io1 h1 sq1 < <(awk '/^cpu / {print $1, $2, $3, $4, $5, $6, $7, $8}' /proc/stat)
sleep 0.15
read -r c2 u2 n2 s2 i2 io2 h2 sq2 < <(awk '/^cpu / {print $1, $2, $3, $4, $5, $6, $7, $8}' /proc/stat)
CPU_PCT=$(awk -v a1="$u1" -v b1="$n1" -v c1="$s1" -v d1="$i1" -v e1="$io1" -v f1="$h1" -v g1="$sq1" \
              -v a2="$u2" -v b2="$n2" -v c2="$s2" -v d2="$i2" -v e2="$io2" -v f2="$h2" -v g2="$sq2" '
  BEGIN {
    idle1 = d1 + e1; idle2 = d2 + e2
    tot1  = a1+b1+c1+d1+e1+f1+g1; tot2 = a2+b2+c2+d2+e2+f2+g2
    dt = tot2 - tot1; di = idle2 - idle1
    if (dt <= 0) { print 0; exit }
    p = int(((dt - di) * 100) / dt)
    if (p < 0) p = 0; if (p > 100) p = 100
    print p
  }')
CPU_COLOR="$GREEN"
if   (( CPU_PCT >= 90 )); then CPU_COLOR="$RED"
elif (( CPU_PCT >= 75 )); then CPU_COLOR="$YEL"
fi

# ---- render ----
DIR_SHORT=$(printf '%s' "$CWD" | sed "s|^$HOME|~|")

printf '%b%s%b  ' "$BLU" "$DIR_SHORT" "$R"
[[ -n "$BRANCH" ]] && printf '%b %s%b  ' "$BR_COLOR" "$BRANCH" "$R"
printf '%b%s tok%b  ' "$YEL" "$(fmt_num "$TOTAL_TOK")" "$R"
printf '%b$%.4f%b  ' "$GREEN" "$COST" "$R"
printf '%bHanoi %s%b  ' "$CYAN" "$WEATHER" "$R"
printf '%bcpu %d%%%b  ' "$CPU_COLOR" "$CPU_PCT" "$R"
printf '%bram %s%b  '   "$RAM_COLOR" "$RAM"  "$R"
printf '%bdisk %s%b'    "$DISK_COLOR" "$DISK" "$R"
