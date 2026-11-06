#!/usr/bin/env bash
# Claude Code Statusline (Blazing Fast, Stylish & Feature-Rich)
# No emojis. Clean, minimal design using ANSI colors and subtle separators.

# ============================================================
# データパースの高速化: 単一の jq 呼び出しで全データを抽出
# ============================================================
# stdinは一度しか読めないため変数に保持し、RunCat Neo用の書き出し処理にも使い回す
payload=$(cat)

# RunCat Neo Custom Metrics 用のJSONを非同期で書き出す（失敗してもステータスライン表示には影響させない）
echo "$payload" | python3 "$HOME/claude/runcat-statusline.py" >"$HOME/claude/runcat-statusline.log" 2>&1 &

eval $(echo "$payload" | jq -r '
  @sh "current_dir=\(.workspace.current_dir // "")",
  @sh "model_name=\(.model.display_name // "")",
  @sh "model_id=\(.model.id // "")",
  @sh "repo_host=\(.workspace.repo.host // "")",
  @sh "repo_owner=\(.workspace.repo.owner // "")",
  @sh "repo_name=\(.workspace.repo.name // "")",
  @sh "git_worktree=\(.workspace.git_worktree // "")",
  @sh "total_input_tokens=\(.context_window.total_input_tokens // 0)",
  @sh "total_output_tokens=\(.context_window.total_output_tokens // 0)",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "input_tok_current=\(.context_window.current_usage.input_tokens // 0)",
  @sh "cache_write=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "used_pct=\(.context_window.used_percentage // "")",
  @sh "remaining_pct=\(.context_window.remaining_percentage // "")",
  @sh "five_hour=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "five_hour_resets_at=\(.rate_limits.five_hour.resets_at // "")",
  @sh "seven_day=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "seven_day_resets_at=\(.rate_limits.seven_day.resets_at // "")",
  @sh "total_cost=\(.cost.total_cost_usd // "")",
  @sh "lines_added=\(.cost.total_lines_added // "")",
  @sh "lines_removed=\(.cost.total_lines_removed // "")"
')

dir_name=$(basename "$current_dir" 2>/dev/null)

# --- カラー定義 (ANSI) ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
BRIGHT_CYAN='\033[96m'
GREEN='\033[32m'
BRIGHT_GREEN='\033[92m'
YELLOW='\033[33m'
BRIGHT_YELLOW='\033[93m'
RED='\033[31m'
BRIGHT_RED='\033[91m'
BLUE='\033[34m'
BRIGHT_BLUE='\033[94m'
MAGENTA='\033[35m'
BRIGHT_MAGENTA='\033[95m'
WHITE='\033[37m'
BRIGHT_WHITE='\033[97m'

SEP="$(printf '%b' "$DIM")|$(printf '%b' "$RESET")"
DOT="$(printf '%b' "$DIM")·$(printf '%b' "$RESET")"

# --- 5. プロジェクト言語自動検知 (バージョン取得は遅いため省略) ---
env_info=""
if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  if [ -f "$current_dir/package.json" ]; then
    env_info="$(printf '%b' "${YELLOW}")node$(printf '%b' "$RESET")"
  elif [ -f "$current_dir/pyproject.toml" ] || [ -f "$current_dir/requirements.txt" ] || [ -f "$current_dir/Pipfile" ]; then
    env_info="$(printf '%b' "${BLUE}")python$(printf '%b' "$RESET")"
  elif [ -f "$current_dir/go.mod" ]; then
    env_info="$(printf '%b' "${CYAN}")go$(printf '%b' "$RESET")"
  elif [ -f "$current_dir/Cargo.toml" ]; then
    env_info="$(printf '%b' "${RED}")rust$(printf '%b' "$RESET")"
  fi
fi

# --- 3. MCPサーバー/プラグインの接続数 ---
mcp_count=0
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  mcp_count=$(jq '{a: ((.enabledPlugins // {}) | length), b: ((.mcpServers // {}) | length)} | .a + .b' "$settings_file" 2>/dev/null)
  [ -z "$mcp_count" ] || [ "$mcp_count" = "null" ] && mcp_count=0
fi

# --- 6. 今日のメッセージ数 ---
today_msgs=0
stats_file="$HOME/.claude/stats-cache.json"
if [ -f "$stats_file" ]; then
  today_date=$(date "+%Y-%m-%d")
  msgs=$(jq -r --arg d "$today_date" '.dailyActivity[] | select(.date == $d) | .messageCount' "$stats_file" 2>/dev/null | head -n1)
  [ -n "$msgs" ] && [ "$msgs" != "null" ] && today_msgs=$msgs
fi

# --- Git ---
git_branch=""
if [ -n "$git_worktree" ]; then
  git_branch="$git_worktree"
elif [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  git_branch=$(git -C "$current_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

git_dirty_count=0
if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
  git_dirty_count=$(git -C "$current_dir" --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi

# --- 1. キャッシュヒット率 ---
cache_rate=0
if [ -n "$input_tok_current" ] && [ "$input_tok_current" -gt 0 ] 2>/dev/null; then
  cache_rate=$(echo "scale=1; $cache_read * 100 / $input_tok_current" | bc 2>/dev/null)
fi

# --- 2. 残りトークン数 ---
remaining_tokens=""
if [ -n "$used_pct" ] && [ "$used_pct" != "0" ] && [ "$used_pct" != "null" ]; then
  tot=$(( total_input_tokens + total_output_tokens ))
  if [ "$tot" -gt 0 ]; then
    max_tok=$(echo "scale=0; $tot * 100 / $used_pct" | bc 2>/dev/null)
    rem_tok=$(echo "scale=0; $max_tok * $remaining_pct / 100" | bc 2>/dev/null)
    rem_tok=$(echo "$rem_tok" | cut -d'.' -f1)
    if [ -n "$rem_tok" ] && [ "$rem_tok" -gt 0 ] 2>/dev/null; then
      if [ "$rem_tok" -gt 1000000 ]; then
        remaining_tokens="$(echo "scale=1; $rem_tok / 1000000" | bc 2>/dev/null)M"
      elif [ "$rem_tok" -gt 1000 ]; then
        remaining_tokens="$(echo "scale=1; $rem_tok / 1000" | bc 2>/dev/null)K"
      else
        remaining_tokens="$rem_tok"
      fi
    fi
  fi
fi

# --- コスト ---
if [ -z "$total_cost" ] || [ "$total_cost" = "null" ]; then
  if echo "$model_id" | grep -q "opus"; then
    price_in=3.00; price_out=15.00; price_cw=3.75; price_cr=0.30
  elif echo "$model_id" | grep -q "sonnet"; then
    price_in=3.00; price_out=15.00; price_cw=3.75; price_cr=0.30
  else
    price_in=0.25; price_out=1.25; price_cw=0.30; price_cr=0.03
  fi

  total_cost=$(echo "scale=4; ($input_tok_current * $price_in + $total_output_tokens * $price_out + $cache_write * $price_cw + $cache_read * $price_cr) / 1000000" | bc 2>/dev/null)
fi

# --- 時間・システムリソース (軽量版) ---
current_time=$(date "+%H:%M")
# topは重いためpsとvm_statに代替
cpu_usage=$(ps -A -o %cpu 2>/dev/null | awk '{s+=$1} END {printf "%.1f", s}' 2>/dev/null)
mem_used=$(vm_stat 2>/dev/null | awk '/Pages active/ {a=$3} /Pages wired down/ {w=$3} END {printf "%.1fG", (a+w)*4096/1024/1024/1024}' 2>/dev/null)
battery_pct=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1)

# ============================================================
# ユーティリティ関数
# ============================================================

color_for_used_pct() {
  local pct="$1"
  if [ -z "$pct" ] || [ "$pct" = "null" ]; then
    printf '%b' "$DIM"
  elif [ "$(echo "$pct < 50" | bc 2>/dev/null)" = "1" ]; then
    printf '%b' "$BRIGHT_GREEN"
  elif [ "$(echo "$pct < 80" | bc 2>/dev/null)" = "1" ]; then
    printf '%b' "$BRIGHT_YELLOW"
  else
    printf '%b' "$BRIGHT_RED"
  fi
}

make_progress_bar() {
  local pct="$1"
  local bar_len="${2:-10}"
  local filled=0
  local empty=0

  if [ -n "$pct" ] && [ "$pct" != "null" ]; then
    filled=$(echo "scale=0; $pct * $bar_len / 100" | bc 2>/dev/null)
    filled=${filled:-0}
    filled=$(echo "$filled" | cut -d'.' -f1)
    [ "$filled" -gt "$bar_len" ] && filled=$bar_len
    empty=$(( bar_len - filled ))
  else
    empty=$bar_len
  fi

  local bar=""
  local i=0
  while [ $i -lt $filled ]; do
    bar="${bar}■"
    i=$(( i + 1 ))
  done
  i=0
  while [ $i -lt $empty ]; do
    bar="${bar}□"
    i=$(( i + 1 ))
  done
  echo "$bar"
}

format_tokens() {
  local tok="$1"
  if [ -z "$tok" ] || [ "$tok" = "0" ] || [ "$tok" = "null" ]; then
    echo "0"
  elif [ "$(echo "$tok >= 1000000" | bc 2>/dev/null)" = "1" ]; then
    printf "%.1fM" "$(echo "scale=1; $tok / 1000000" | bc 2>/dev/null)"
  elif [ "$(echo "$tok >= 1000" | bc 2>/dev/null)" = "1" ]; then
    printf "%.1fK" "$(echo "scale=1; $tok / 1000" | bc 2>/dev/null)"
  else
    echo "$tok"
  fi
}

calc_remaining_time() {
  local resets_at="$1"
  if [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
    # ISO8601 (ミリ秒やタイムゾーン付き) や Epoch を正確かつ高速にパースするため Node を利用
    local reset_sec=""
    if [[ "$resets_at" =~ ^[0-9]+$ ]]; then
      if [ "${#resets_at}" -gt 10 ]; then
        reset_sec=$(( resets_at / 1000 ))
      else
        reset_sec=$resets_at
      fi
    else
      reset_sec=$(node -e "const d=Date.parse(process.argv[1]); if(!isNaN(d)) console.log(Math.floor(d/1000))" "$resets_at" 2>/dev/null)
    fi

    local now_sec=$(date +%s)
    if [ -n "$reset_sec" ] && [ "$reset_sec" -gt "$now_sec" ]; then
      local diff=$(( reset_sec - now_sec ))
      local days=$(( diff / 86400 ))
      local hours=$(( (diff % 86400) / 3600 ))
      local mins=$(( (diff % 3600) / 60 ))
      
      if [ "$days" -gt 0 ]; then
        echo "${days}d${hours}h"
      else
        echo "${hours}h${mins}m"
      fi
    fi
  fi
}

# ============================================================
# 1行目: Workspace・Env・Git・Model・Cache・MCP
# ============================================================
line1=""

# Workspace
if [ -n "$dir_name" ]; then
  line1="${line1}$(printf '%b' "$DIM")[$(printf '%b' "$RESET")$(printf '%b' "${BRIGHT_CYAN}${BOLD}") ${dir_name} $(printf '%b' "$RESET")$(printf '%b' "$DIM")]$(printf '%b' "$RESET") "
fi

# Env
if [ -n "$env_info" ]; then
  line1="${line1} ${env_info} $DOT "
fi

# Repo
if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  repo_str="${repo_owner}/${repo_name}"
  line1="${line1}$(printf '%b' "$DIM")${repo_str}$(printf '%b' "$RESET") "
fi

# Branch
if [ -n "$git_branch" ] && [ "$git_branch" != "HEAD" ]; then
  line1="${line1}${DOT} $(printf '%b' "${BRIGHT_BLUE}")${git_branch}$(printf '%b' "$RESET") "
fi

# Diffs
if [ -n "$lines_added" ] && [ "$lines_added" != "null" ] || [ -n "$lines_removed" ] && [ "$lines_removed" != "null" ]; then
  line1="${line1}${DOT} $(printf '%b' "${GREEN}")+${lines_added:-0}$(printf '%b' "$RESET") $(printf '%b' "${RED}")-${lines_removed:-0}$(printf '%b' "$RESET") "
fi

# Dirty
if [ -n "$git_dirty_count" ] && [ "$git_dirty_count" -gt 0 ] 2>/dev/null; then
  line1="${line1}${DOT} $(printf '%b' "${YELLOW}")dirty:${git_dirty_count}$(printf '%b' "$RESET") "
fi

line1="${line1} $SEP "

# Model
if [ -n "$model_name" ]; then
  line1="${line1} $(printf '%b' "${BRIGHT_MAGENTA}${BOLD}")${model_name}$(printf '%b' "$RESET") "
fi

# Tokens
in_fmt=$(format_tokens "$total_input_tokens")
out_fmt=$(format_tokens "$total_output_tokens")
if [ "$in_fmt" != "0" ] || [ "$out_fmt" != "0" ]; then
  line1="${line1}${DOT} $(printf '%b' "${DIM}")in:$(printf '%b' "$RESET")${in_fmt} $(printf '%b' "${DIM}")out:$(printf '%b' "$RESET")${out_fmt} "
fi

# Cache Rate
if [ -n "$cache_rate" ] && [ "$(echo "$cache_rate > 0" | bc 2>/dev/null)" = "1" ]; then
  line1="${line1}${DOT} $(printf '%b' "${DIM}")cache:$(printf '%b' "$RESET")$(printf '%b' "${BRIGHT_GREEN}")${cache_rate}%$(printf '%b' "$RESET") "
fi

# MCP / Plugins
line1="${line1}${DOT} $(printf '%b' "${DIM}")tools:$(printf '%b' "$RESET")${mcp_count} "

# ============================================================
# 2行目: Time・Sys・Cost・Limits・Ctx
# ============================================================
line2=""

# Time
line2="${line2}$(printf '%b' "${BRIGHT_WHITE}")${current_time}$(printf '%b' "$RESET") "

# Sys
sys_str=""
[ -n "$cpu_usage" ] && sys_str="${sys_str}cpu:${cpu_usage}% "
[ -n "$mem_used" ] && sys_str="${sys_str}ram:${mem_used} "
[ -n "$battery_pct" ] && sys_str="${sys_str}batt:${battery_pct}"
if [ -n "$sys_str" ]; then
  sys_str_trimmed="${sys_str%% }"
  line2="${line2}${DOT} $(printf '%b' "${DIM}")${sys_str_trimmed}$(printf '%b' "$RESET") "
fi

# Cost
if [ -n "$total_cost" ] && [ "$total_cost" != "0" ] && [ "$total_cost" != "0.0000" ] && [ "$total_cost" != "null" ]; then
  cost_fmt=$(printf "\$%.4f" "$total_cost")
  line2="${line2} $SEP $(printf '%b' "${BRIGHT_MAGENTA}")${cost_fmt}$(printf '%b' "$RESET") "
fi

# Today's msgs
if [ "$today_msgs" -gt 0 ]; then
  line2="${line2} $SEP $(printf '%b' "${DIM}")msgs:$(printf '%b' "$RESET")${today_msgs} "
fi

line2="${line2} $SEP "

# 5H
if [ -n "$five_hour" ] && [ "$five_hour" != "null" ]; then
  col=$(color_for_used_pct "$five_hour")
  pct_fmt=$(printf "%.0f" "$five_hour")
  
  rem=$(calc_remaining_time "$five_hour_resets_at")
  rem_str=""
  [ -n "$rem" ] && rem_str="$(printf '%b' "${DIM}")(rem:${rem})$(printf '%b' "$RESET")"
  
  line2="${line2}$(printf '%b' "${DIM}")5h:$(printf '%b' "$RESET")${col}${pct_fmt}%$(printf '%b' "$RESET")${rem_str} "
fi

# 7D
if [ -n "$seven_day" ] && [ "$seven_day" != "null" ]; then
  col=$(color_for_used_pct "$seven_day")
  pct_fmt=$(printf "%.0f" "$seven_day")
  
  rem=$(calc_remaining_time "$seven_day_resets_at")
  rem_str=""
  [ -n "$rem" ] && rem_str="$(printf '%b' "${DIM}")(rem:${rem})$(printf '%b' "$RESET")"
  
  line2="${line2}${DOT} $(printf '%b' "${DIM}")7d:$(printf '%b' "$RESET")${col}${pct_fmt}%$(printf '%b' "$RESET")${rem_str} "
fi

# Ctx
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  bar=$(make_progress_bar "$used_int" 10)
  col=$(color_for_used_pct "$used_int")

  rem_tok_str=""
  [ -n "$remaining_tokens" ] && rem_tok_str=" $(printf '%b' "${DIM}")(rem:${remaining_tokens})$(printf '%b' "$RESET")"
  
  line2="${line2} $SEP $(printf '%b' "${DIM}")ctx:$(printf '%b' "$RESET") ${col}${bar}$(printf '%b' "$RESET") ${col}${used_int}%$(printf '%b' "$RESET")${rem_tok_str}"
fi

# ============================================================
# 最終出力
# ============================================================

if [ -z "$line1" ]; then line1="$(printf '%b' "${DIM}")Claude Code$(printf '%b' "$RESET")"; fi
if [ -z "$line2" ]; then line2="$(printf '%b' "${DIM}")--$(printf '%b' "$RESET")"; fi

printf '%b\n%b' "$line1" "$line2"
