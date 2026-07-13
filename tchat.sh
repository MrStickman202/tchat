#!/data/data/com.termux/files/usr/bin/bash

# ─────────────────────────────────────────
#  tchat v3.0 — Multi-provider agentic chat
#  Providers: OpenRouter, Gemini, Anthropic, OpenAI
#  deps: curl, jq  (pkg install curl jq)
#  install: type /install inside the app
# ─────────────────────────────────────────

TCHAT_VERSION="3.0"
PROVIDER="${TCHAT_PROVIDER:-}"
API_KEY=""
MODEL=""
SAVE_DIR="${HOME}/tchat-files"
CONFIG_DIR="${HOME}/.config/tchat"
CONFIG_FILE="${CONFIG_DIR}/config.json"
MEMORY_FILE="${CONFIG_DIR}/memory.json"
MODELS_CACHE=""

mkdir -p "$SAVE_DIR" "$CONFIG_DIR"

# ── ANSI HELPERS ─────────────────────────
R="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
tc()    { printf "\033[38;2;%d;%d;%dm" "$1" "$2" "$3"; }  # fg truecolor
tcbg()  { printf "\033[48;2;%d;%d;%dm" "$1" "$2" "$3"; }  # bg truecolor

hex2rgb() {
  local hex="${1#\#}"
  if [[ ! "$hex" =~ ^[0-9a-fA-F]{6}$ ]]; then
    printf "224 224 224"
    return
  fi
  printf "%d %d %d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# ── SETTINGS DEFAULTS ────────────────────
CFG_TEXT_COLOR="#E0E0E0"
CFG_USER_COLOR="#CC88FF"
CFG_ASSISTANT_COLOR="#44FF88"
CFG_TOOL_COLOR="#44AAFF"
CFG_DIM_COLOR="#666666"
CFG_ERROR_COLOR="#FF4444"
CFG_BG_COLOR=""             # empty = terminal default
CFG_BOLD_USER="true"
CFG_FILE_ROOT="sdcard"      # sdcard | termux
CFG_CUSTOM_PROMPT=""        # appended to system prompt
CFG_FONT_STYLE="normal"     # normal | bold | dim
CFG_COMMAND_PREVIEW="true"  # ghost command completion in the input line
CFG_MEMORY_ENABLED="false"  # persistent compact user memory
CFG_MAX_OUTPUT_TOKENS="2048"
CFG_DEFAULT_MODEL_OPENROUTER=""
CFG_DEFAULT_MODEL_GEMINI=""
CFG_DEFAULT_MODEL_ANTHROPIC=""
CFG_DEFAULT_MODEL_OPENAI=""

# ── CONFIG PERSISTENCE ───────────────────
save_config() {
  local tmp="${CONFIG_FILE}.tmp"
  jq -n \
    --arg text_color "$CFG_TEXT_COLOR" \
    --arg user_color "$CFG_USER_COLOR" \
    --arg assistant_color "$CFG_ASSISTANT_COLOR" \
    --arg tool_color "$CFG_TOOL_COLOR" \
    --arg dim_color "$CFG_DIM_COLOR" \
    --arg error_color "$CFG_ERROR_COLOR" \
    --arg bg_color "$CFG_BG_COLOR" \
    --arg bold_user "$CFG_BOLD_USER" \
    --arg file_root "$CFG_FILE_ROOT" \
    --arg custom_prompt "$CFG_CUSTOM_PROMPT" \
    --arg font_style "$CFG_FONT_STYLE" \
    --arg command_preview "$CFG_COMMAND_PREVIEW" \
    --arg memory_enabled "$CFG_MEMORY_ENABLED" \
    --arg max_output_tokens "$CFG_MAX_OUTPUT_TOKENS" \
    --arg default_openrouter "$CFG_DEFAULT_MODEL_OPENROUTER" \
    --arg default_gemini "$CFG_DEFAULT_MODEL_GEMINI" \
    --arg default_anthropic "$CFG_DEFAULT_MODEL_ANTHROPIC" \
    --arg default_openai "$CFG_DEFAULT_MODEL_OPENAI" \
    '{text_color:$text_color,user_color:$user_color,assistant_color:$assistant_color,
      tool_color:$tool_color,dim_color:$dim_color,error_color:$error_color,
      bg_color:$bg_color,bold_user:$bold_user,file_root:$file_root,
      custom_prompt:$custom_prompt,font_style:$font_style,
      command_preview:$command_preview,memory_enabled:$memory_enabled,
      max_output_tokens:$max_output_tokens,
      default_models:{openrouter:$default_openrouter,gemini:$default_gemini,
        anthropic:$default_anthropic,openai:$default_openai}}' > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

load_config() {
  if [ ! -f "$CONFIG_FILE" ] || ! jq -e . "$CONFIG_FILE" >/dev/null 2>&1; then
    [ -f "$CONFIG_FILE" ] && mv "$CONFIG_FILE" "${CONFIG_FILE}.broken.$(date +%s)" 2>/dev/null
    save_config
    return
  fi
  CFG_TEXT_COLOR=$(jq -r '.text_color // "#E0E0E0"' "$CONFIG_FILE")
  CFG_USER_COLOR=$(jq -r '.user_color // "#CC88FF"' "$CONFIG_FILE")
  CFG_ASSISTANT_COLOR=$(jq -r '.assistant_color // "#44FF88"' "$CONFIG_FILE")
  CFG_TOOL_COLOR=$(jq -r '.tool_color // "#44AAFF"' "$CONFIG_FILE")
  CFG_DIM_COLOR=$(jq -r '.dim_color // "#666666"' "$CONFIG_FILE")
  CFG_ERROR_COLOR=$(jq -r '.error_color // "#FF4444"' "$CONFIG_FILE")
  CFG_BG_COLOR=$(jq -r '.bg_color // ""' "$CONFIG_FILE")
  CFG_BOLD_USER=$(jq -r '.bold_user // "true"' "$CONFIG_FILE")
  CFG_FILE_ROOT=$(jq -r '.file_root // "sdcard"' "$CONFIG_FILE")
  CFG_CUSTOM_PROMPT=$(jq -r '.custom_prompt // ""' "$CONFIG_FILE")
  CFG_FONT_STYLE=$(jq -r '.font_style // "normal"' "$CONFIG_FILE")
  CFG_COMMAND_PREVIEW=$(jq -r '.command_preview // "true"' "$CONFIG_FILE")
  CFG_MEMORY_ENABLED=$(jq -r '.memory_enabled // "false"' "$CONFIG_FILE")
  CFG_MAX_OUTPUT_TOKENS=$(jq -r '.max_output_tokens // "2048"' "$CONFIG_FILE")
  CFG_DEFAULT_MODEL_OPENROUTER=$(jq -r '.default_models.openrouter // ""' "$CONFIG_FILE")
  CFG_DEFAULT_MODEL_GEMINI=$(jq -r '.default_models.gemini // ""' "$CONFIG_FILE")
  CFG_DEFAULT_MODEL_ANTHROPIC=$(jq -r '.default_models.anthropic // ""' "$CONFIG_FILE")
  CFG_DEFAULT_MODEL_OPENAI=$(jq -r '.default_models.openai // ""' "$CONFIG_FILE")

  [[ "$CFG_FILE_ROOT" =~ ^(sdcard|termux)$ ]] || CFG_FILE_ROOT="sdcard"
  [[ "$CFG_FONT_STYLE" =~ ^(normal|bold|dim)$ ]] || CFG_FONT_STYLE="normal"
  [[ "$CFG_COMMAND_PREVIEW" =~ ^(true|false)$ ]] || CFG_COMMAND_PREVIEW="true"
  [[ "$CFG_MEMORY_ENABLED" =~ ^(true|false)$ ]] || CFG_MEMORY_ENABLED="false"
  [[ "$CFG_MAX_OUTPUT_TOKENS" =~ ^[0-9]+$ ]] || CFG_MAX_OUTPUT_TOKENS="2048"
  [ "$CFG_MAX_OUTPUT_TOKENS" -lt 128 ] && CFG_MAX_OUTPUT_TOKENS="128"
  [ "$CFG_MAX_OUTPUT_TOKENS" -gt 32768 ] && CFG_MAX_OUTPUT_TOKENS="32768"
}

KEYS_FILE="${CONFIG_DIR}/keys.json"
save_key() {
  if [ ! -f "$KEYS_FILE" ] || ! jq -e . "$KEYS_FILE" >/dev/null 2>&1; then
    printf '{}\n' > "$KEYS_FILE"
  fi
  local tmp="${KEYS_FILE}.tmp"
  if jq --arg p "$1" --arg k "$2" '.[$p]=$k' "$KEYS_FILE" > "$tmp"; then
    mv "$tmp" "$KEYS_FILE"
    chmod 600 "$KEYS_FILE" 2>/dev/null || true
  else
    rm -f "$tmp"
    return 1
  fi
}
get_key() {
  [ -f "$KEYS_FILE" ] && jq -r --arg p "$1" '.[$p]//empty' "$KEYS_FILE" 2>/dev/null
}

get_saved_default_model() {
  case "$PROVIDER" in
    openrouter) printf '%s' "$CFG_DEFAULT_MODEL_OPENROUTER" ;;
    gemini)     printf '%s' "$CFG_DEFAULT_MODEL_GEMINI" ;;
    anthropic)  printf '%s' "$CFG_DEFAULT_MODEL_ANTHROPIC" ;;
    openai)     printf '%s' "$CFG_DEFAULT_MODEL_OPENAI" ;;
  esac
}

save_current_model_as_default() {
  [ -z "$MODEL" ] && return 1
  case "$PROVIDER" in
    openrouter) CFG_DEFAULT_MODEL_OPENROUTER="$MODEL" ;;
    gemini)     CFG_DEFAULT_MODEL_GEMINI="$MODEL" ;;
    anthropic)  CFG_DEFAULT_MODEL_ANTHROPIC="$MODEL" ;;
    openai)     CFG_DEFAULT_MODEL_OPENAI="$MODEL" ;;
  esac
  save_config
}

clear_provider_default_model() {
  case "$PROVIDER" in
    openrouter) CFG_DEFAULT_MODEL_OPENROUTER="" ;;
    gemini)     CFG_DEFAULT_MODEL_GEMINI="" ;;
    anthropic)  CFG_DEFAULT_MODEL_ANTHROPIC="" ;;
    openai)     CFG_DEFAULT_MODEL_OPENAI="" ;;
  esac
  save_config
}

# ── COMPACT USER MEMORY ──────────────────
ensure_memory_file() {
  if [ ! -f "$MEMORY_FILE" ] || ! jq -e 'type=="array"' "$MEMORY_FILE" >/dev/null 2>&1; then
    printf '[]\n' > "$MEMORY_FILE"
  fi
  chmod 600 "$MEMORY_FILE" 2>/dev/null || true
}

memory_context() {
  ensure_memory_file
  jq -r '.[:20][] | "- " + .' "$MEMORY_FILE" 2>/dev/null | head -c 1800
}

memory_add_fact() {
  ensure_memory_file
  local fact="$1" tmp="${MEMORY_FILE}.tmp"
  fact=$(printf '%s' "$fact" | tr '\n\r\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | cut -c1-180)
  [ -z "$fact" ] && return 1
  if jq --arg f "$fact" 'map(select((ascii_downcase) != ($f|ascii_downcase))) + [$f] | if length>20 then .[-20:] else . end' "$MEMORY_FILE" > "$tmp"; then
    mv "$tmp" "$MEMORY_FILE"; chmod 600 "$MEMORY_FILE" 2>/dev/null || true
  else
    rm -f "$tmp"; return 1
  fi
}

memory_forget_matching() {
  ensure_memory_file
  local query="$1" tmp="${MEMORY_FILE}.tmp"
  [ -z "$query" ] && return 1
  if jq --arg q "$query" 'map(select(((ascii_downcase)|contains($q|ascii_downcase))|not))' "$MEMORY_FILE" > "$tmp"; then
    mv "$tmp" "$MEMORY_FILE"; chmod 600 "$MEMORY_FILE" 2>/dev/null || true
  else
    rm -f "$tmp"; return 1
  fi
}

memory_clear() {
  printf '[]\n' > "$MEMORY_FILE"
  chmod 600 "$MEMORY_FILE" 2>/dev/null || true
}

show_memory() {
  ensure_memory_file
  printf "\n  ${BOLD}${C_TOOL}AI memory${R}  ${C_DIM}(%s)${R}\n" "$CFG_MEMORY_ENABLED"
  local count; count=$(jq 'length' "$MEMORY_FILE" 2>/dev/null)
  if [ "${count:-0}" -eq 0 ]; then
    printf "  ${C_DIM}No saved facts.${R}\n\n"
  else
    jq -r 'to_entries[] | "  \(.key+1)) \(.value)"' "$MEMORY_FILE"
    printf "\n"
  fi
}

memory_menu() {
  while true; do
    show_memory
    printf "  ${C_USER}1)${R} Toggle memory\n"
    printf "  ${C_USER}2)${R} Add a fact manually\n"
    printf "  ${C_USER}3)${R} Forget matching facts\n"
    printf "  ${C_USER}4)${R} Clear all memory\n"
    printf "  ${C_USER}0)${R} Back\n\n"
    printf "  ${C_DIM}Pick: ${R}"; read -r mp
    case "$mp" in
      1)
        if [ "$CFG_MEMORY_ENABLED" = "true" ]; then CFG_MEMORY_ENABLED="false"; else CFG_MEMORY_ENABLED="true"; fi
        save_config ;;
      2)
        printf "  ${C_DIM}Fact (keep it short): ${R}"; read -r fact
        memory_add_fact "$fact" && printf "  ${C_ASST}✓ Remembered.${R}\n" || printf "  ${C_ERR}✗ Nothing saved.${R}\n" ;;
      3)
        printf "  ${C_DIM}Forget facts containing: ${R}"; read -r query
        memory_forget_matching "$query" && printf "  ${C_ASST}✓ Updated memory.${R}\n" || printf "  ${C_ERR}✗ Nothing changed.${R}\n" ;;
      4)
        printf "  ${C_DIM}Clear all saved memory? [y/N]: ${R}"; read -r confirm
        [[ "$confirm" =~ ^[Yy] ]] && memory_clear ;;
      0) break ;;
    esac
  done
}

# ── DYNAMIC COLOR VARS ───────────────────
apply_colors() {
  read -r tr tg tb <<< "$(hex2rgb "$CFG_TEXT_COLOR")"
  read -r ur ug ub <<< "$(hex2rgb "$CFG_USER_COLOR")"
  read -r ar ag ab <<< "$(hex2rgb "$CFG_ASSISTANT_COLOR")"
  read -r tlr tlg tlb <<< "$(hex2rgb "$CFG_TOOL_COLOR")"
  read -r dr dg db <<< "$(hex2rgb "$CFG_DIM_COLOR")"
  read -r er eg eb <<< "$(hex2rgb "$CFG_ERROR_COLOR")"

  C_TEXT=$(tc $tr $tg $tb)
  C_USER=$(tc $ur $ug $ub)
  C_ASST=$(tc $ar $ag $ab)
  C_TOOL=$(tc $tlr $tlg $tlb)
  C_DIM=$(tc $dr $dg $db)
  C_ERR=$(tc $er $eg $eb)

  if [ -n "$CFG_BG_COLOR" ]; then
    read -r br bg bb <<< "$(hex2rgb "$CFG_BG_COLOR")"
    C_BG=$(tcbg $br $bg $bb)
  else
    C_BG=""
  fi

  case "$CFG_FONT_STYLE" in
    bold) C_FONT="\033[1m" ;;
    dim)  C_FONT="\033[2m" ;;
    *)    C_FONT="" ;;
  esac
}

# ── DEPS ─────────────────────────────────
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    printf "\033[31m✗ Missing: $cmd — run: pkg install $cmd\033[0m\n"; exit 1
  fi
done

load_config
apply_colors

# ── FILE ROOT ────────────────────────────
get_docs_path() {
  case "$CFG_FILE_ROOT" in
    sdcard)  echo "/sdcard" ;;
    termux)  echo "$HOME" ;;
  esac
}

# ── PROVIDER DEFAULTS ────────────────────
set_provider_defaults() {
  case "$PROVIDER" in
    openrouter)
      API_URL="https://openrouter.ai/api/v1/chat/completions"
      MODELS_URL="https://openrouter.ai/api/v1/models"
      MODEL="$(get_saved_default_model)"
      MODEL="${MODEL:-google/gemini-2.5-pro}" ;;
    gemini)
      API_URL="https://generativelanguage.googleapis.com/v1beta/models"
      MODELS_URL="https://generativelanguage.googleapis.com/v1beta/models"
      MODEL="$(get_saved_default_model)"
      MODEL="${MODEL:-gemini-flash-latest}" ;;
    anthropic)
      API_URL="https://api.anthropic.com/v1/messages"
      MODELS_URL="https://api.anthropic.com/v1/models"
      MODEL="$(get_saved_default_model)"
      MODEL="${MODEL:-claude-3-5-sonnet-latest}" ;;
    openai)
      API_URL="https://api.openai.com/v1/chat/completions"
      MODELS_URL="https://api.openai.com/v1/models"
      MODEL="$(get_saved_default_model)"
      MODEL="${MODEL:-gpt-5-mini}" ;;
  esac
}

select_automatic_model() {
  local saved candidate
  saved=$(get_saved_default_model)
  if [ -n "$saved" ]; then
    MODEL="$saved"
    return
  fi

  case "$PROVIDER" in
    gemini)
      # Prefer the highest stable numbered Flash model (for example gemini-3.5-flash).
      candidate=$(printf '%s\n' "$MODELS_CACHE" \
        | grep -E '^gemini-[0-9]+([.][0-9]+)*-flash$' \
        | sort -V | tail -1)
      [ -z "$candidate" ] && candidate=$(printf '%s\n' "$MODELS_CACHE" | grep -Fx 'gemini-flash-latest' | head -1)
      [ -z "$candidate" ] && candidate=$(printf '%s\n' "$MODELS_CACHE" \
        | grep -Ei '^gemini-.*flash' \
        | grep -Eiv '(lite|image|live|tts|preview)' \
        | sort -V | tail -1)
      [ -n "$candidate" ] && MODEL="$candidate" ;;
    openai)
      for candidate in gpt-5-mini gpt-4.1-mini gpt-4o-mini; do
        if printf '%s\n' "$MODELS_CACHE" | grep -Fxq "$candidate"; then MODEL="$candidate"; return; fi
      done
      candidate=$(printf '%s\n' "$MODELS_CACHE" | grep -E '^gpt-.*mini' | sort -V | tail -1)
      [ -z "$candidate" ] && candidate=$(printf '%s\n' "$MODELS_CACHE" | grep -E '^gpt-' | sort -V | tail -1)
      [ -n "$candidate" ] && MODEL="$candidate" ;;
  esac
}

# ── BRANDED BOX ──────────────────────────
print_box() {
  local len=31
  case "$PROVIDER" in
    anthropic)
      local lc; lc=$(tc 215 119 87)
      printf "  ${lc}▐▛███▜▌${R}\n"
      printf "  ${lc}▜█████▛▘${R}\n"
      printf "  ${lc} ▘▘ ▝▝${R}\n"
      printf "\n"
      printf "  $(tc 215 119 87)╔═══════════════════════════════╗${R}\n"
      printf "  $(tc 215 119 87)║      tchat  •  Claude         ║${R}\n"
      printf "  $(tc 215 119 87)╚═══════════════════════════════╝${R}\n" ;;
    gemini)
      local cr=(66 234 251 52) cg=(133 67 188 168) cb=(244 53 4 83)
      printf "  ╔"
      for (( i=0; i<len; i++ )); do
        local seg=$(( i*4/len )) nxt=$(( (i*4/len+1)%4 )) t=$(( (i*4%len)*256/len ))
        local r=$(( (cr[seg]*(256-t)+cr[nxt]*t)/256 ))
        local g=$(( (cg[seg]*(256-t)+cg[nxt]*t)/256 ))
        local b=$(( (cb[seg]*(256-t)+cb[nxt]*t)/256 ))
        printf "$(tc $r $g $b)═${R}"
      done
      printf "╗\n"
      printf "  ║  $(tc 66 133 244)G$(tc 234 67 53)o$(tc 251 188 4)o$(tc 52 168 83)g$(tc 234 67 53)l$(tc 66 133 244)e${R}  tchat  •  Gemini     ║\n"
      printf "  ╚"
      for (( i=0; i<len; i++ )); do
        local seg=$(( i*4/len )) nxt=$(( (i*4/len+1)%4 )) t=$(( (i*4%len)*256/len ))
        local r=$(( (cr[seg]*(256-t)+cr[nxt]*t)/256 ))
        local g=$(( (cg[seg]*(256-t)+cg[nxt]*t)/256 ))
        local b=$(( (cb[seg]*(256-t)+cb[nxt]*t)/256 ))
        printf "$(tc $r $g $b)═${R}"
      done
      printf "╝\n" ;;
    openrouter)
      local gray; gray=$(tc 220 220 220)
      printf "  ${gray}╔═══════════════════════════════╗${R}\n"
      printf "  ${gray}║     tchat  •  OpenRouter      ║${R}\n"
      printf "  ${gray}╚═══════════════════════════════╝${R}\n" ;;
    openai)
      local green; green=$(tc 116 170 156)
      printf "  ${green}╔═══════════════════════════════╗${R}\n"
      printf "  ${green}║       tchat  •  OpenAI        ║${R}\n"
      printf "  ${green}╚═══════════════════════════════╝${R}\n" ;;
  esac
}

# ── PROVIDER PICKER ──────────────────────
choose_provider() {
  MODELS_CACHE=""
  while true; do
    clear
    local picker_title="tchat v${TCHAT_VERSION}" picker_left picker_right
    picker_left=$(( (31 - ${#picker_title}) / 2 ))
    picker_right=$(( 31 - ${#picker_title} - picker_left ))
    printf "\n  ╔$(tc 180 180 180)═══════════════════════════════${R}╗\n"
    printf "  ║$(tc 180 180 180)%*s%s%*s${R}║\n" "$picker_left" "" "$picker_title" "$picker_right" ""
    printf "  ╚$(tc 180 180 180)═══════════════════════════════${R}╝\n\n"
    printf "  ${BOLD}Choose provider:${R}\n\n"
    printf "  ${C_USER}1)${R} OpenRouter  ${C_DIM}(many providers)${R}\n"
    printf "  ${C_USER}2)${R} Gemini      ${C_DIM}(Google AI Studio)${R}\n"
    printf "  ${C_USER}3)${R} Anthropic   ${C_DIM}(Claude API)${R}\n"
    printf "  ${C_USER}4)${R} OpenAI      ${C_DIM}(OpenAI Platform API)${R}\n\n"
    printf "  ${C_DIM}Pick [1-4]: ${R}"
    read -r pick
    pick=$(echo "$pick" | tr -d '[:space:]')
    case "$pick" in
      1) PROVIDER="openrouter"; break ;;
      2) PROVIDER="gemini"; break ;;
      3) PROVIDER="anthropic"; break ;;
      4) PROVIDER="openai"; break ;;
      *) printf "\n  ${C_ERR}✗ Invalid choice. Pick 1, 2, 3, or 4.${R}\n"; sleep 1 ;;
    esac
  done

  set_provider_defaults
  local saved; saved=$(get_key "$PROVIDER")
  if [ -n "$saved" ]; then
    printf "\n  ${C_DIM}Found saved key for %s. Use it? [Y/n]: ${R}" "$PROVIDER"; read -r use
    use=$(echo "$use" | tr -d '[:space:]')
    if [[ ! "$use" =~ ^[Nn] ]]; then
      API_KEY="$saved"; printf "  ${C_DIM}✓ Key loaded.${R}\n\n"; return
    fi
  fi
  printf "\n  ${C_USER}API key for %s: ${R}" "$PROVIDER"
  read -r -s API_KEY; echo ""
  [ -z "$API_KEY" ] && printf "${C_ERR}✗ No key.${R}\n" && exit 1
  save_key "$PROVIDER" "$API_KEY"
  printf "  ${C_DIM}✓ Key saved.${R}\n\n"
}

# ── HEADER ───────────────────────────────
print_header() {
  clear
  [ -n "$C_BG" ] && printf "${C_BG}"; tput ed 2>/dev/null; printf "${R}"
  printf "\n"
  print_box
  case "$PROVIDER" in
    anthropic)  printf "  $(tc 232 184 154)Model: %s${R}\n" "$MODEL" ;;
    gemini)     printf "  $(tc 66 133 244)Model: %s${R}\n" "$MODEL" ;;
    openrouter) printf "  $(tc 200 200 200)Model: %s${R}\n" "$MODEL" ;;
    openai)     printf "  $(tc 116 170 156)Model: %s${R}\n" "$MODEL" ;;
  esac
  printf "  ${C_DIM}/q quit  /s search  /settings  /switch  /help${R}\n"
  [ "$CFG_COMMAND_PREVIEW" = "true" ] && printf "  ${C_DIM}Type / for commands; Tab or → accepts the preview${R}\n"
  printf "  ${C_DIM}────────────────────────────────────${R}\n\n"
}

# ── PROVIDER CREDIT BALANCE ──────────────
check_balance() {
  printf "\n  ${BOLD}${C_TOOL}Checking API Balance...${R}\n"
  case "$PROVIDER" in
    openrouter)
      local res total used remaining err
      res=$(curl -sS --connect-timeout 15 --max-time 60 \
        "https://openrouter.ai/api/v1/credits" \
        -H "Authorization: Bearer $API_KEY" 2>&1)
      if jq -e . >/dev/null 2>&1 <<< "$res"; then
        total=$(jq -r '.data.total_credits//empty' <<< "$res")
        used=$(jq -r '.data.total_usage//empty' <<< "$res")
        if [ -n "$total" ] && [ -n "$used" ]; then
          remaining=$(jq -nr --argjson total "$total" --argjson used "$used" '$total-$used')
          printf "  ${C_ASST}Remaining:${R} $%.4f USD\n" "$remaining"
          printf "  ${C_DIM}Purchased: $%.4f  Used: $%.4f${R}\n\n" "$total" "$used"
        else
          local key_res key_remaining key_usage
          err=$(jq -r '.error.message//.message//empty' <<< "$res")
          key_res=$(curl -sS --connect-timeout 15 --max-time 60 \
            "https://openrouter.ai/api/v1/key" \
            -H "Authorization: Bearer $API_KEY" 2>&1)
          key_remaining=$(jq -r '.data.limit_remaining//empty' <<< "$key_res" 2>/dev/null)
          key_usage=$(jq -r '.data.usage//empty' <<< "$key_res" 2>/dev/null)
          if [ -n "$key_remaining" ]; then
            printf "  ${C_ASST}API-key limit remaining:${R} $%.4f USD\n" "$key_remaining"
            [ -n "$key_usage" ] && printf "  ${C_DIM}Key usage: $%.4f${R}\n" "$key_usage"
            printf "  ${C_DIM}Account-wide balance needs an OpenRouter management key.${R}\n\n"
          else
            printf "  ${C_ERR}✗ %s${R}\n\n" "${err:-Could not fetch credit information.}"
          fi
        fi
      else
        printf "  ${C_ERR}✗ Network/API error: %s${R}\n\n" "$res"
      fi ;;
    gemini)
      printf "  ${C_USER}Gemini (Google AI Studio)${R} uses project quotas rather than a conversational credit balance.\n"
      printf "  ${C_DIM}Check usage and quotas in Google AI Studio / Google Cloud.${R}\n\n" ;;
    anthropic)
      printf "  ${C_USER}Anthropic (Claude API)${R} billing balance is managed in the web console.\n"
      printf "  ${C_DIM}Check Billing in the Anthropic Console.${R}\n\n" ;;
    openai)
      printf "  ${C_USER}OpenAI API${R} usage and billing are managed in the OpenAI Platform dashboard.\n"
      printf "  ${C_DIM}A normal API key does not expose an account balance endpoint here.${R}\n\n" ;;
  esac
}

# ── MODEL FETCH ──────────────────────────
fetch_models() {
  printf "  ${C_DIM}Fetching models...${R}\n"
  local response err
  MODELS_CACHE=""
  case "$PROVIDER" in
    openrouter)
      response=$(curl -sS --connect-timeout 15 --max-time 90 "$MODELS_URL" \
        -H "Authorization: Bearer $API_KEY" 2>&1)
      MODELS_CACHE=$(jq -r '[.data[]?|.id]|sort|.[]' <<< "$response" 2>/dev/null) ;;
    gemini)
      local token="" page models=""
      while true; do
        if [ -n "$token" ]; then
          page=$(curl -sS --connect-timeout 15 --max-time 90 --get "$MODELS_URL" \
            -H "x-goog-api-key: $API_KEY" \
            --data-urlencode "pageSize=100" --data-urlencode "pageToken=$token" 2>&1)
        else
          page=$(curl -sS --connect-timeout 15 --max-time 90 --get "$MODELS_URL" \
            -H "x-goog-api-key: $API_KEY" --data-urlencode "pageSize=100" 2>&1)
        fi
        response="$page"
        if ! jq -e . >/dev/null 2>&1 <<< "$page"; then
          break
        fi
        if jq -e '.error?' >/dev/null 2>&1 <<< "$page"; then
          break
        fi
        models+=$(jq -r '.models[]?|select(any(.supportedGenerationMethods[]?; .=="generateContent"))|.name|ltrimstr("models/")' <<< "$page")$'\n'
        token=$(jq -r '.nextPageToken//empty' <<< "$page")
        [ -z "$token" ] && break
      done
      MODELS_CACHE=$(printf '%s' "$models" | sed '/^$/d' | sort -u) ;;
    anthropic)
      response=$(curl -sS --connect-timeout 15 --max-time 90 "$MODELS_URL" \
        -H "x-api-key: $API_KEY" -H "anthropic-version: 2023-06-01" 2>&1)
      MODELS_CACHE=$(jq -r '[.data[]?|.id]|sort|.[]' <<< "$response" 2>/dev/null) ;;
    openai)
      response=$(curl -sS --connect-timeout 15 --max-time 90 "$MODELS_URL" \
        -H "Authorization: Bearer $API_KEY" 2>&1)
      MODELS_CACHE=$(jq -r '[.data[]?.id
        | select(test("^(gpt-|o[0-9]|codex)"))
        | select((test("realtime|audio|transcribe|tts|image|embedding|moderation|search|computer-use";"i"))|not)]
        | sort | .[]' <<< "$response" 2>/dev/null) ;;
  esac
  if [ -z "$MODELS_CACHE" ]; then
    err=$(jq -r '.error.message//.error//.message//empty' <<< "${response:-}" 2>/dev/null)
    printf "  ${C_ERR}✗ Could not fetch models%s${R}\n\n" "${err:+: $err}"
  else
    local count; count=$(printf '%s\n' "$MODELS_CACHE" | sed '/^$/d' | wc -l | tr -d ' ')
    select_automatic_model
    printf "  ${C_DIM}Loaded ${C_USER}%s${R}${C_DIM} models. Using ${C_USER}%s${R}${C_DIM}.${R}\n\n" "$count" "$MODEL"
  fi
}

search_models() {
  local query="$1"
  [ -z "$MODELS_CACHE" ] && fetch_models
  local results; results=$(printf '%s\n' "$MODELS_CACHE" | grep -iF -- "$query" | head -20)
  if [ -z "$results" ]; then
    printf "  ${C_ERR}No models matching \"%s\"${R}\n\n" "$query"; return
  fi
  printf "\n  ${BOLD}${C_TOOL}Results for \"%s\":${R}\n" "$query"
  local i=1; local ids=()
  while IFS= read -r id; do
    ids+=("$id"); printf "  ${C_USER}%2d)${R} %s\n" "$i" "$id"; i=$(( i + 1 ))
  done <<< "$results"
  printf "\n  ${C_DIM}Pick number to switch, Enter to cancel: ${R}"
  read -r pick
  pick=$(echo "$pick" | tr -d '[:space:]')
  if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#ids[@]}" ]; then
    MODEL="${ids[$((pick-1))]}"; printf "  ${C_DIM}Switched to: ${C_USER}%s${R}\n\n" "$MODEL"
  else
    printf "  ${C_DIM}Cancelled.${R}\n\n"
  fi
}

# ── LIST ALL MODELS ─────────────────────
list_all_models() {
  [ -z "$MODELS_CACHE" ] && fetch_models
  if [ -z "$MODELS_CACHE" ]; then
    printf "  ${C_ERR}No models loaded.${R}\n\n"; return
  fi
  printf "\n  ${BOLD}${C_TOOL}Available models (%s):${R}\n" "$PROVIDER"
  local i=1
  local ids=()
  while IFS= read -r id; do
    ids+=("$id")
    printf "  ${C_USER}%3d)${R} %s\n" "$i" "$id"
    i=$(( i + 1 ))
  done <<< "$MODELS_CACHE"
  printf "\n  ${C_DIM}Pick number to switch, Enter to cancel: ${R}"
  read -r pick
  pick=$(echo "$pick" | tr -d '[:space:]')
  if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#ids[@]}" ]; then
    MODEL="${ids[$((pick-1))]}"
    printf "  ${C_DIM}Switched to: ${C_USER}%s${R}\n\n" "$MODEL"
  else
    printf "  ${C_DIM}Cancelled.${R}\n\n"
  fi
}

# ── SETTINGS MENU ────────────────────────
show_color_preview() {
  printf "\n  ${C_DIM}Preview:${R}\n"
  printf "  ${C_USER}You › ${R}${C_FONT}${C_TEXT}Hello there!${R}\n"
  printf "  ${BOLD}${C_ASST}◆ Assistant${R}\n"
  printf "  ${C_FONT}${C_TEXT}Hi! How can I help?${R}\n"
  printf "  ${BOLD}${C_TOOL}⚙ tool:${R} write_file\n"
  printf "  ${C_ERR}✗ Example error${R}\n\n"
}

print_settings_box() {
  # Exactly 31 visible characters inside each border; avoids wrapping on narrow phones.
  printf "\n  ╔═══════════════════════════════╗\n"
  printf "  ║        tchat settings         ║\n"
  printf "  ╚═══════════════════════════════╝\n\n"
}

pick_color() {
  local label="$1" current="$2" cpick hex
  {
    printf "\n  ${C_DIM}Current %s: ${C_USER}%s${R}\n" "$label" "$current"
    printf "  ${C_DIM}Presets:${R}\n"
    printf "  ${C_USER}1)${R} $(tc 224 108 117)Red       #E06C75${R}\n"
    printf "  ${C_USER}2)${R} $(tc 152 195 121)Green     #98C379${R}\n"
    printf "  ${C_USER}3)${R} $(tc 97 175 239)Blue      #61AFEF${R}\n"
    printf "  ${C_USER}4)${R} $(tc 229 192 123)Yellow    #E5C07B${R}\n"
    printf "  ${C_USER}5)${R} $(tc 198 120 221)Purple    #C678DD${R}\n"
    printf "  ${C_USER}6)${R} $(tc 86 182 194)Cyan      #56B6C2${R}\n"
    printf "  ${C_USER}7)${R} $(tc 224 224 224)White     #E0E0E0${R}\n"
    printf "  ${C_USER}8)${R} $(tc 230 162 118)Orange    #E6A276${R}\n"
    printf "  ${C_USER}9)${R} Custom hex (e.g. #FF8800)\n"
    printf "  ${C_USER}0)${R} Keep current\n\n"
    printf "  ${C_DIM}Pick: ${R}"
  } >&2
  read -r cpick
  cpick=$(printf '%s' "$cpick" | tr -d '[:space:]')
  case "$cpick" in
    1) printf '#E06C75' ;; 2) printf '#98C379' ;; 3) printf '#61AFEF' ;;
    4) printf '#E5C07B' ;; 5) printf '#C678DD' ;; 6) printf '#56B6C2' ;;
    7) printf '#E0E0E0' ;; 8) printf '#E6A276' ;;
    9)
      printf "  ${C_DIM}Enter hex color: ${R}" >&2
      read -r hex
      if [[ "$hex" =~ ^#[0-9a-fA-F]{6}$ ]]; then printf '%s' "$hex"; else printf '%s' "$current"; fi ;;
    *) printf '%s' "$current" ;;
  esac
}

manage_default_model() {
  local saved; saved=$(get_saved_default_model)
  printf "\n  ${C_DIM}Current model:${R} ${C_USER}%s${R}\n" "$MODEL"
  printf "  ${C_DIM}Saved default:${R} ${C_USER}%s${R}\n\n" "${saved:-automatic}"
  printf "  ${C_USER}1)${R} Save current model as default\n"
  printf "  ${C_USER}2)${R} Clear default and use automatic selection\n"
  printf "  ${C_USER}0)${R} Cancel\n\n"
  printf "  ${C_DIM}Pick: ${R}"; read -r dp
  case "$dp" in
    1) save_current_model_as_default && printf "  ${C_ASST}✓ Default saved.${R}\n" ;;
    2) clear_provider_default_model; select_automatic_model; printf "  ${C_ASST}✓ Default cleared. Using %s.${R}\n" "$MODEL" ;;
  esac
}

open_settings() {
  while true; do
    clear
    print_settings_box
    local default_label; default_label=$(get_saved_default_model)

    printf "  ${BOLD}Colors${R}\n"
    printf "  ${C_USER}1)${R} Text color        ${C_DIM}%s${R}\n" "$CFG_TEXT_COLOR"
    printf "  ${C_USER}2)${R} Your name color   ${C_DIM}%s${R}\n" "$CFG_USER_COLOR"
    printf "  ${C_USER}3)${R} Assistant color   ${C_DIM}%s${R}\n" "$CFG_ASSISTANT_COLOR"
    printf "  ${C_USER}4)${R} Tool color        ${C_DIM}%s${R}\n" "$CFG_TOOL_COLOR"
    printf "  ${C_USER}5)${R} Dim/hint color    ${C_DIM}%s${R}\n" "$CFG_DIM_COLOR"
    printf "  ${C_USER}6)${R} Error color       ${C_DIM}%s${R}\n" "$CFG_ERROR_COLOR"
    printf "  ${C_USER}7)${R} Background color  ${C_DIM}%s${R}\n" "${CFG_BG_COLOR:-terminal default}"

    printf "\n  ${BOLD}Style${R}\n"
    printf "  ${C_USER}8)${R} Font style        ${C_DIM}%s${R}\n" "$CFG_FONT_STYLE"

    printf "\n  ${BOLD}Behavior${R}\n"
    printf "  ${C_USER}9)${R} File location     ${C_DIM}%s${R}\n" "$CFG_FILE_ROOT"
    printf "  ${C_USER}10)${R} Command preview  ${C_DIM}%s${R}\n" "$CFG_COMMAND_PREVIEW"
    printf "  ${C_USER}11)${R} AI memory        ${C_DIM}%s${R}\n" "$CFG_MEMORY_ENABLED"
    printf "  ${C_USER}12)${R} Max output       ${C_DIM}%s tokens${R}\n" "$CFG_MAX_OUTPUT_TOKENS"
    printf "  ${C_USER}13)${R} Default model    ${C_DIM}%s${R}\n" "${default_label:-automatic}"
    printf "  ${C_USER}14)${R} Custom prompt    ${C_DIM}%s${R}\n" "${CFG_CUSTOM_PROMPT:-(none)}"

    printf "\n  ${BOLD}Misc${R}\n"
    printf "  ${C_USER}15)${R} Preview colors\n"
    printf "  ${C_USER}16)${R} Reset to defaults\n"
    printf "  ${C_USER}0)${R}  Back\n\n"

    printf "  ${C_DIM}Pick: ${R}"; read -r pick
    pick=$(echo "$pick" | tr -d '[:space:]')

    case "$pick" in
      1) CFG_TEXT_COLOR=$(pick_color "text color" "$CFG_TEXT_COLOR"); apply_colors; save_config ;;
      2) CFG_USER_COLOR=$(pick_color "your name color" "$CFG_USER_COLOR"); apply_colors; save_config ;;
      3) CFG_ASSISTANT_COLOR=$(pick_color "assistant color" "$CFG_ASSISTANT_COLOR"); apply_colors; save_config ;;
      4) CFG_TOOL_COLOR=$(pick_color "tool color" "$CFG_TOOL_COLOR"); apply_colors; save_config ;;
      5) CFG_DIM_COLOR=$(pick_color "dim/hint color" "$CFG_DIM_COLOR"); apply_colors; save_config ;;
      6) CFG_ERROR_COLOR=$(pick_color "error color" "$CFG_ERROR_COLOR"); apply_colors; save_config ;;
      7)
        printf "\n  ${C_DIM}Enter background hex, or leave empty for terminal default: ${R}"; read -r bghex
        if [ -z "$bghex" ] || [[ "$bghex" =~ ^#[0-9a-fA-F]{6}$ ]]; then
          CFG_BG_COLOR="$bghex"; apply_colors; save_config
        else printf "  ${C_ERR}✗ Invalid color. Use #RRGGBB.${R}\n"; fi ;;
      8)
        printf "\n  ${C_USER}1)${R} normal  ${C_USER}2)${R} bold  ${C_USER}3)${R} dim\n"
        printf "  ${C_DIM}Pick: ${R}"; read -r fp
        case "$fp" in 1) CFG_FONT_STYLE="normal" ;; 2) CFG_FONT_STYLE="bold" ;; 3) CFG_FONT_STYLE="dim" ;; esac
        apply_colors; save_config ;;
      9)
        printf "\n  ${C_USER}1)${R} /sdcard/  ${C_DIM}(Android-visible)${R}\n"
        printf "  ${C_USER}2)${R} ~/        ${C_DIM}(Termux-only)${R}\n"
        printf "  ${C_DIM}Pick: ${R}"; read -r fp
        case "$fp" in 1) CFG_FILE_ROOT="sdcard" ;; 2) CFG_FILE_ROOT="termux" ;; esac
        save_config ;;
      10)
        if [ "$CFG_COMMAND_PREVIEW" = "true" ]; then CFG_COMMAND_PREVIEW="false"; else CFG_COMMAND_PREVIEW="true"; fi
        save_config ;;
      11) memory_menu ;;
      12)
        printf "\n  ${C_DIM}Maximum output tokens (128-32768): ${R}"; read -r mt
        if [[ "$mt" =~ ^[0-9]+$ ]] && [ "$mt" -ge 128 ] && [ "$mt" -le 32768 ]; then
          CFG_MAX_OUTPUT_TOKENS="$mt"; save_config
        else printf "  ${C_ERR}✗ Enter a number from 128 to 32768.${R}\n"; fi ;;
      13) manage_default_model ;;
      14)
        printf "\n  ${C_DIM}Current custom prompt:${R}\n  %s\n\n" "${CFG_CUSTOM_PROMPT:-(none)}"
        printf "  ${C_DIM}Enter new prompt (empty clears it):${R}\n  > "; read -r CFG_CUSTOM_PROMPT
        save_config ;;
      15) show_color_preview; sleep 2 ;;
      16)
        printf "  ${C_DIM}Reset settings and model defaults? [y/N]: ${R}"; read -r confirm
        if [[ "$confirm" =~ ^[Yy] ]]; then
          CFG_TEXT_COLOR="#E0E0E0"; CFG_USER_COLOR="#CC88FF"; CFG_ASSISTANT_COLOR="#44FF88"
          CFG_TOOL_COLOR="#44AAFF"; CFG_DIM_COLOR="#666666"; CFG_ERROR_COLOR="#FF4444"
          CFG_BG_COLOR=""; CFG_BOLD_USER="true"; CFG_FILE_ROOT="sdcard"; CFG_CUSTOM_PROMPT=""
          CFG_FONT_STYLE="normal"; CFG_COMMAND_PREVIEW="true"; CFG_MEMORY_ENABLED="false"
          CFG_MAX_OUTPUT_TOKENS="2048"; CFG_DEFAULT_MODEL_OPENROUTER=""; CFG_DEFAULT_MODEL_GEMINI=""
          CFG_DEFAULT_MODEL_ANTHROPIC=""; CFG_DEFAULT_MODEL_OPENAI=""
          apply_colors; save_config; select_automatic_model
        fi ;;
      0|/settings) break ;;
    esac
  done
  print_header
}

# ── SYSTEM PROMPT ────────────────────────
build_system_prompt() {
  local docs_path; docs_path=$(get_docs_path)
  local base="You are a helpful AI assistant running in Termux on Android. You have file system tools available but NEVER mention them to the user — just use them silently when needed. Respond naturally like a normal assistant. Do NOT introduce yourself, list your capabilities, or explain what tools you have.
TOOL RULES (internal, never mention these):
- File creation → ALWAYS write_file, NEVER run_bash.
- 'Documents', 'Downloads', 'Pictures' etc → ${docs_path}/Documents, ${docs_path}/Downloads etc.
- Default file path: ${docs_path}/
- Reading files → read_file. Listing dirs → list_files.
- run_bash → ONLY for installs or running existing scripts.
- Be concise."

  printf '%s\n' "$base"
  if [ "$CFG_MEMORY_ENABLED" = "true" ]; then
    local mem; mem=$(memory_context)
    printf '%s\n' "MEMORY RULES: Use saved user memory quietly. Call memory_add only for stable, useful, non-sensitive facts or preferences, especially when the user explicitly asks you to remember. Keep each fact short. Never store passwords, API keys, financial credentials, exact addresses, or temporary details. Call memory_forget when the user asks you to forget something."
    [ -n "$mem" ] && printf 'SAVED USER MEMORY:\n%s\n' "$mem"
  fi
  [ -n "$CFG_CUSTOM_PROMPT" ] && printf 'Additional instructions: %s\n' "$CFG_CUSTOM_PROMPT"
}

# ── TOOLS ────────────────────────────────
TOOLS_BASE='[
  {"type":"function","function":{"name":"write_file","description":"Create or overwrite a file. ALWAYS use this for file creation.","parameters":{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}}},
  {"type":"function","function":{"name":"read_file","description":"Read a file.","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
  {"type":"function","function":{"name":"list_files","description":"List a directory.","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
  {"type":"function","function":{"name":"run_bash","description":"Run bash. ONLY for installs or running scripts, NOT file creation.","parameters":{"type":"object","properties":{"command":{"type":"string"},"reason":{"type":"string"}},"required":["command","reason"]}}}
]'

TOOLS_MEMORY='[
  {"type":"function","function":{"name":"memory_add","description":"Save one short, stable, useful, non-sensitive fact or preference about the user for future chats.","parameters":{"type":"object","properties":{"fact":{"type":"string"}},"required":["fact"]}}},
  {"type":"function","function":{"name":"memory_forget","description":"Forget saved user-memory facts containing the given text when the user asks.","parameters":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}}
]'

TOOLS_ANTHROPIC_BASE='[
  {"name":"write_file","description":"Create or overwrite a file. ALWAYS use for file creation.","input_schema":{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}},
  {"name":"read_file","description":"Read a file.","input_schema":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}},
  {"name":"list_files","description":"List a directory.","input_schema":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}},
  {"name":"run_bash","description":"Run bash. ONLY installs/scripts, NOT file creation.","input_schema":{"type":"object","properties":{"command":{"type":"string"},"reason":{"type":"string"}},"required":["command","reason"]}}
]'

TOOLS_ANTHROPIC_MEMORY='[
  {"name":"memory_add","description":"Save one short, stable, useful, non-sensitive fact or preference about the user for future chats.","input_schema":{"type":"object","properties":{"fact":{"type":"string"}},"required":["fact"]}},
  {"name":"memory_forget","description":"Forget saved user-memory facts containing the given text when the user asks.","input_schema":{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}}
]'

get_tools() {
  if [ "$CFG_MEMORY_ENABLED" = "true" ]; then jq -cn --argjson a "$TOOLS_BASE" --argjson b "$TOOLS_MEMORY" '$a+$b'; else printf '%s' "$TOOLS_BASE"; fi
}
get_anthropic_tools() {
  if [ "$CFG_MEMORY_ENABLED" = "true" ]; then jq -cn --argjson a "$TOOLS_ANTHROPIC_BASE" --argjson b "$TOOLS_ANTHROPIC_MEMORY" '$a+$b'; else printf '%s' "$TOOLS_ANTHROPIC_BASE"; fi
}

# ── TOOL EXECUTION ───────────────────────
run_tool() {
  local name="$1" args="$2"
  case "$name" in
    write_file)
      local path content
      path=$(echo "$args" | jq -r '.path//empty')
      content=$(echo "$args" | jq -r '.content//empty')
      if [ -z "$path" ] || [ "$path" = "null" ]; then
        echo "ERROR: Missing path argument."
        return
      fi
      path="${path/#\~/$HOME}"
      mkdir -p "$(dirname "$path")"
      printf "%s" "$content" > "$path"
      printf "  ${C_ASST}✓ write_file:${R} %s\n" "$path" >&2
      echo "File written successfully: $path" ;;
    read_file)
      local path; path=$(echo "$args" | jq -r '.path//empty')
      if [ -z "$path" ] || [ "$path" = "null" ]; then
        echo "ERROR: Missing path argument."
        return
      fi
      path="${path/#\~/$HOME}"
      if [ ! -f "$path" ]; then
        printf "  ${C_ERR}✗ Not found: %s${R}\n" "$path" >&2; echo "ERROR: File not found: $path"
      else
        printf "  ${C_ASST}✓ read_file:${R} %s\n" "$path" >&2; cat "$path"
      fi ;;
    list_files)
      local path; path=$(echo "$args" | jq -r '.path//empty')
      if [ -z "$path" ] || [ "$path" = "null" ]; then
        echo "ERROR: Missing path argument."
        return
      fi
      path="${path/#\~/$HOME}"
      if [ ! -d "$path" ]; then
        printf "  ${C_ERR}✗ Not a dir: %s${R}\n" "$path" >&2; echo "ERROR: Not a directory"
      else
        printf "  ${C_ASST}✓ list_files:${R} %s\n" "$path" >&2; ls -la "$path"
      fi ;;
    memory_add)
      local fact; fact=$(echo "$args" | jq -r '.fact//empty')
      if [ "$CFG_MEMORY_ENABLED" != "true" ]; then echo "ERROR: AI memory is disabled."
      elif memory_add_fact "$fact"; then printf "  ${C_ASST}✓ memory:${R} saved one fact\n" >&2; echo "Memory saved."
      else echo "ERROR: Empty memory fact."; fi ;;
    memory_forget)
      local query; query=$(echo "$args" | jq -r '.query//empty')
      if [ "$CFG_MEMORY_ENABLED" != "true" ]; then echo "ERROR: AI memory is disabled."
      elif memory_forget_matching "$query"; then printf "  ${C_ASST}✓ memory:${R} updated\n" >&2; echo "Matching memory removed."
      else echo "ERROR: Empty forget query."; fi ;;
    run_bash)
      local command reason
      command=$(echo "$args" | jq -r '.command//empty')
      reason=$(echo "$args" | jq -r '.reason//empty')
      if [ -z "$command" ] || [ "$command" = "null" ]; then
        printf "  ${C_ERR}✗ Guard blocked a malformed or null command string.${R}\n" >&2
        echo "ERROR: Received empty or null command parameter."; return
      fi
      if echo "$command" | grep -qE '^[[:space:]]*(touch[[:space:]]|echo[[:space:]].*>|cat[[:space:]].*>|tee[[:space:]]|printf[[:space:]].*>)'; then
        printf "  ${C_USER}⚠ Use write_file for file creation.${R}\n" >&2
        echo "ERROR: Use write_file instead."; return
      fi
      printf "\n  ${BOLD}${C_USER}⚡ bash:${R} %s\n" "$command" >&2
      printf "  ${C_DIM}Reason: %s${R}\n" "$reason" >&2
      printf "  ${BOLD}Allow? [Y/n]: ${R}" >&2; read -r allow < /dev/tty
      allow=$(echo "$allow" | tr -d '[:space:]')
      if [[ "$allow" =~ ^[Nn] ]]; then
        printf "  ${C_ERR}✗ Blocked by user.${R}\n" >&2; echo "Blocked by user."
      else
        local out code; out=$(bash -c "$command" 2>&1); code=$?
        [ $code -eq 0 ] && printf "  ${C_ASST}✓ Done${R}\n" >&2 || printf "  ${C_ERR}✗ Exit %d${R}\n" "$code" >&2
        if [ ${#out} -gt 4000 ]; then
          printf '%s\n\n[Output truncated to 4000 characters...]\n' "${out:0:4000}"
        else
          printf '%s\n' "$out"
        fi
      fi ;;
  esac
}

# ── TERMINAL OUTPUT ──────────────────────
terminal_cols() {
  local cols="${COLUMNS:-}"
  if [[ ! "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -le 0 ]; then
    cols=$(tput cols 2>/dev/null || true)
  fi
  if [[ ! "$cols" =~ ^[0-9]+$ ]] || [ "$cols" -le 0 ]; then
    cols=$(stty size 2>/dev/null < /dev/tty | awk '{print $2}')
  fi
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  [ "$cols" -lt 24 ] && cols=24
  printf '%s' "$cols"
}

print_wrapped_text() {
  local text="$1" cols width
  cols=$(terminal_cols)
  width=$((cols - 4))
  [ "$width" -lt 20 ] && width=20
  printf '%s\n' "$text" | fold -s -w "$width" | sed 's/^/  /'
}

# ── HISTORY ──────────────────────────────
HISTORY="[]"

# ── API CALLS ────────────────────────────
call_openrouter() {
  local sys tools body; sys=$(build_system_prompt); tools=$(get_tools)
  body=$(jq -n \
    --arg model "$MODEL" --arg system "$sys" --argjson max "$CFG_MAX_OUTPUT_TOKENS" \
    --argjson messages "$HISTORY" --argjson tools "$tools" \
    '{model:$model,messages:([{"role":"system","content":$system}]+$messages),tools:$tools,max_tokens:$max,stream:false}')
  curl -sS --connect-timeout 15 --max-time 180 "$API_URL" -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "$body"
}

call_openai() {
  local sys tools body response fallback; sys=$(build_system_prompt); tools=$(get_tools)
  body=$(jq -n \
    --arg model "$MODEL" --arg system "$sys" --argjson max "$CFG_MAX_OUTPUT_TOKENS" \
    --argjson messages "$HISTORY" --argjson tools "$tools" \
    '{model:$model,messages:([{"role":"system","content":$system}]+$messages),tools:$tools,max_completion_tokens:$max,stream:false}')
  response=$(curl -sS --connect-timeout 15 --max-time 180 "$API_URL" -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "$body")
  if jq -e '.error.param=="max_completion_tokens" or (.error.message? // "" | test("max_completion_tokens.*unsupported|unknown.*max_completion_tokens";"i"))' >/dev/null 2>&1 <<< "$response"; then
    fallback=$(jq --argjson max "$CFG_MAX_OUTPUT_TOKENS" 'del(.max_completion_tokens) + {max_tokens:$max}' <<< "$body")
    response=$(curl -sS --connect-timeout 15 --max-time 180 "$API_URL" -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" -d "$fallback")
  fi
  printf '%s' "$response"
}

call_gemini() {
  local url="${API_URL}/${MODEL}:generateContent"
  local sys tools contents funcs body; sys=$(build_system_prompt); tools=$(get_tools)
  contents=$(echo "$HISTORY" | jq '[.[]|{
    role:(if .role=="assistant" then "model" elif .role=="tool" then "user" else .role end),
    parts:(if .role=="tool" then
      [{"functionResponse":{"name":(.name//"tool"),"response":{"content":.content}}}]
    elif .gemini_parts!=null then .gemini_parts
    elif ((.tool_calls//[])|length)>0 then
      [.tool_calls[]|{"functionCall":{"name":.function.name,"args":(.function.arguments|fromjson)}}]
    else [{"text":(.content//"")}] end)
  }]')
  funcs=$(echo "$tools" | jq '[.[]|{name:.function.name,description:.function.description,parameters:.function.parameters}]')
  body=$(jq -n \
    --arg sys "$sys" --argjson max "$CFG_MAX_OUTPUT_TOKENS" \
    --argjson contents "$contents" --argjson funcs "$funcs" \
    '{systemInstruction:{parts:[{text:$sys}]},contents:$contents,tools:[{functionDeclarations:$funcs}],generationConfig:{maxOutputTokens:$max}}')
  curl -sS --connect-timeout 15 --max-time 180 "$url" -H "x-goog-api-key: $API_KEY" -H "Content-Type: application/json" -d "$body"
}

call_anthropic() {
  local sys tools msgs body; sys=$(build_system_prompt); tools=$(get_anthropic_tools)
  msgs=$(echo "$HISTORY" | jq '[.[]|select(.role!="system")|{
    role:(if .role=="tool" then "user" else .role end),
    content:(if .role=="tool" then
      [{"type":"tool_result","tool_use_id":.tool_call_id,"content":.content}]
    elif (.raw_content!=null) then .raw_content
    else (.content//"") end)
  }]')
  body=$(jq -n \
    --arg model "$MODEL" --arg sys "$sys" --argjson max "$CFG_MAX_OUTPUT_TOKENS" \
    --argjson messages "$msgs" --argjson tools "$tools" \
    '{model:$model,max_tokens:$max,system:$sys,messages:$messages,tools:$tools}')
  curl -sS --connect-timeout 15 --max-time 180 "$API_URL" \
    -H "x-api-key: $API_KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" -d "$body"
}

# ── AGENTIC LOOP ─────────────────────────
send_message() {
  local user_msg="$1"
  HISTORY=$(echo "$HISTORY" | jq \
    --arg role "user" --arg content "$user_msg" \
    '. + [{"role":$role,"content":$content}]')

  local hist_len; hist_len=$(echo "$HISTORY" | jq 'length')
  if [ "$hist_len" -gt 40 ]; then
    HISTORY=$(printf '%s\n' "$HISTORY" | jq '
      .[-40:]
      | (map(.role == "user") | index(true)) as $first_user
      | if $first_user == null then [] else .[$first_user:] end')
  fi

  while true; do
    local response
    case "$PROVIDER" in
      openrouter) response=$(call_openrouter) ;;
      gemini)     response=$(call_gemini) ;;
      anthropic)  response=$(call_anthropic) ;;
      openai)     response=$(call_openai) ;;
    esac

    if [ -z "$response" ]; then
      printf "\n  ${C_ERR}✗ Empty response from provider.${R}\n\n"
      return
    fi
    if ! jq -e . >/dev/null 2>&1 <<< "$response"; then
      printf "\n  ${C_ERR}✗ Provider returned invalid JSON or a network error:${R}\n"
      print_wrapped_text "$response"
      printf "\n"
      return
    fi

    local error
    error=$(jq -r 'if .error.message? then .error.message elif .error? then (.error|tostring) else empty end' <<< "$response" 2>/dev/null)
    if [ -n "$error" ]; then printf "\n  ${C_ERR}✗ %s${R}\n\n" "$error"; return; fi

    local text_content tool_calls tool_count

    case "$PROVIDER" in
      openrouter|openai)
        text_content=$(echo "$response" | jq -r '.choices[0].message.content//""')
        tool_calls=$(echo "$response" | jq -c '.choices[0].message.tool_calls//[]')
        tool_count=$(echo "$tool_calls" | jq 'length')
        HISTORY=$(echo "$HISTORY" | jq --argjson m "$(echo "$response"|jq -c '.choices[0].message')" '. + [$m]') ;;
      gemini)
        text_content=$(echo "$response" | jq -r '[.candidates[0].content.parts[]?|select(.text?)|.text]|join("")' 2>/dev/null)
        tool_calls=$(echo "$response" | jq -c '[.candidates[0].content.parts[]?|select(.functionCall?)|{"id":("call_"+.functionCall.name),"function":{"name":.functionCall.name,"arguments":(.functionCall.args|tostring)}}]' 2>/dev/null)
        tool_calls="${tool_calls:-[]}"; tool_count=$(echo "$tool_calls" | jq 'length')
        local parts; parts=$(echo "$response" | jq -c '.candidates[0].content.parts')
        HISTORY=$(echo "$HISTORY" | jq \
          --arg t "$text_content" --argjson tc "$tool_calls" --argjson p "$parts" \
          '. + [{"role":"assistant","content":$t,"tool_calls":$tc,"gemini_parts":$p}]') ;;
      anthropic)
        text_content=$(echo "$response" | jq -r '[.content[]?|select(.type=="text")|.text]|join("")' 2>/dev/null)
        tool_calls=$(echo "$response" | jq -c '[.content[]?|select(.type=="tool_use")|{"id":.id,"function":{"name":.name,"arguments":(.input|tostring)}}]' 2>/dev/null)
        tool_calls="${tool_calls:-[]}"; tool_count=$(echo "$tool_calls" | jq 'length')
        local raw; raw=$(echo "$response" | jq '[.content[]?|select((.type=="text" and .text!="") or .type=="tool_use")]')
        HISTORY=$(echo "$HISTORY" | jq \
          --arg text "$text_content" --argjson tc "$tool_calls" --argjson raw "$raw" \
          '. + [{"role":"assistant","content":$text,"raw_content":$raw,"tool_calls":$tc}]') ;;
    esac

    if [ -n "$text_content" ] && [ "$text_content" != "null" ] && [ "$text_content" != "" ]; then
      printf "\n  ${BOLD}${C_ASST}◆ Assistant${R}\n"
      local clean
      clean=$(printf '%s\n' "$text_content" \
        | sed 's/\*\*\([^*]*\)\*\*/\1/g' \
        | sed "s/\*\([^*]*\)\*/\1/g" \
        | sed 's/^### */  /g' \
        | sed 's/^## */  /g' \
        | sed 's/^# */  /g' \
        | sed 's/^```[a-z]*/  ─────/g' \
        | sed 's/^```/  ─────/g' \
        | sed 's/`\([^`]*\)`/\1/g')
      printf "${C_FONT}${C_TEXT}"
      print_wrapped_text "$clean"
      printf "${R}\n"
    fi

    [ "$tool_count" -eq 0 ] && break

    local i=0
    while [ $i -lt "$tool_count" ]; do
      local t_call; t_call=$(echo "$tool_calls" | jq -c ".[$i]")
      local tid tname targs
      tid=$(echo "$t_call" | jq -r '.id')
      tname=$(echo "$t_call" | jq -r '.function.name')
      targs=$(echo "$t_call" | jq -r '.function.arguments')
      printf "  ${BOLD}${C_TOOL}⚙ tool:${R} ${C_TOOL}%s${R}\n" "$tname" >&2
      local result; result=$(run_tool "$tname" "$targs")
      HISTORY=$(echo "$HISTORY" | jq \
        --arg id "$tid" --arg name "$tname" --arg content "$result" \
        '. + [{"role":"tool","tool_call_id":$id,"name":$name,"content":$content}]')
      ((i++))
    done
  done
}

# ── SAVE / LIST ──────────────────────────
save_chat() {
  local ts; ts=$(date +"%Y%m%d_%H%M%S")
  local f="$SAVE_DIR/chat_${ts}.txt"
  { printf "tchat — %s\nProvider: %s  Model: %s\n%s\n\n" \
      "$(date)" "$PROVIDER" "$MODEL" "$(printf '═%.0s' {1..50})"
    printf '%s\n' "$HISTORY" | jq -r '.[]|select(.role!="tool")|"[\(.role|ascii_upcase)]\n\(if .raw_content then (.raw_content[]?|select(.type=="text")|.text) else (.content//"") end)\n"'
  } > "$f"
  printf "  ${C_ASST}✓ Saved: %s${R}\n\n" "$f"
}

list_saved() {
  printf "\n  ${BOLD}${C_TOOL}Saved chats:${R}\n"
  local files=("$SAVE_DIR"/*)
  [ ! -e "${files[0]}" ] && printf "  ${C_DIM}None yet.${R}\n\n" && return
  for f in "${files[@]}"; do printf "  ${C_USER}•${R} %s\n" "$(basename "$f")"; done
  printf "\n"
}

switch_provider() {
  while true; do
    printf "\n  ${BOLD}Switch provider:${R}\n"
    printf "  ${C_USER}1)${R} OpenRouter\n  ${C_USER}2)${R} Gemini\n  ${C_USER}3)${R} Anthropic\n  ${C_USER}4)${R} OpenAI\n\n"
    printf "  ${C_DIM}Pick [1-4]: ${R}"; read -r pick
    pick=$(echo "$pick" | tr -d '[:space:]')
    case "$pick" in
      1) PROVIDER="openrouter"; break ;;
      2) PROVIDER="gemini"; break ;;
      3) PROVIDER="anthropic"; break ;;
      4) PROVIDER="openai"; break ;;
      *) printf "  ${C_ERR}Invalid option.${R}\n" ;;
    esac
  done
  set_provider_defaults
  local saved; saved=$(get_key "$PROVIDER")
  if [ -n "$saved" ]; then
    printf "  ${C_DIM}Found saved key. Use it? [Y/n]: ${R}"; read -r use
    if [[ ! "$use" =~ ^[Nn] ]]; then API_KEY="$saved"
    else printf "  ${C_USER}API key: ${R}"; read -r -s API_KEY; echo ""; save_key "$PROVIDER" "$API_KEY"; fi
  else
    printf "  ${C_USER}API key for %s: ${R}" "$PROVIDER"; read -r -s API_KEY; echo ""; save_key "$PROVIDER" "$API_KEY"
  fi
  HISTORY="[]"; MODELS_CACHE=""; fetch_models; print_header
}

install_self() {
  local target="$PREFIX/bin/tchat"
  [ -f "$target" ] && cp "$target" "${target}.backup" 2>/dev/null
  cp "$0" "$target" && chmod +x "$target"
  printf "  ${C_ASST}✓ Installed! Type 'tchat' anywhere.${R}\n\n"
}

# ── INPUT WITH COMMAND PREVIEW ────────────
COMMAND_HINTS=(
  "/help" "/q" "/quit" "/exit" "/clear" "/save" "/ls" "/list"
  "/switch" "/settings" "/install" "/balance" "/search " "/s "
  "/model" "/default" "/memory" "/key" "/refresh"
)
INPUT_HISTORY=()
INPUT_HISTORY_POS=0
INPUT_RESULT=""

get_command_suggestion() {
  local input="$1" cmd best=""
  [[ "$input" == /* ]] || return
  for cmd in "${COMMAND_HINTS[@]}"; do
    if [[ "$cmd" == "$input"* && "$cmd" != "$input" ]]; then
      if [ -z "$best" ] || [ "${#cmd}" -lt "${#best}" ]; then
        best="$cmd"
      fi
    fi
  done
  [ -n "$best" ] && printf '%s' "${best:${#input}}"
}

redraw_input_line() {
  local buffer="$1" suggestion="$2" cols prompt_width=8 available shown room
  cols=$(terminal_cols)
  available=$((cols - prompt_width - 1))
  [ "$available" -lt 8 ] && available=8

  shown="$buffer"
  if [ "${#shown}" -gt "$available" ]; then
    shown="…${shown: -$((available - 1))}"
  fi

  room=$((available - ${#shown}))
  [ "$room" -lt 0 ] && room=0
  suggestion="${suggestion:0:$room}"

  printf '\r\033[2K  %bYou › %b%s%b%s%b' "$BOLD$C_USER" "$R" "$shown" "$C_DIM" "$suggestion" "$R"
  [ -n "$suggestion" ] && printf '\033[%dD' "${#suggestion}"
}

read_input_with_preview() {
  local buffer="" key seq suggestion="" hist_count
  INPUT_RESULT=""

  if [ "$CFG_COMMAND_PREVIEW" != "true" ] || [ ! -t 0 ] || [ ! -r /dev/tty ]; then
    printf "  ${BOLD}${C_USER}You › ${R}"
    IFS= read -r INPUT_RESULT
    return $?
  fi

  hist_count=${#INPUT_HISTORY[@]}
  INPUT_HISTORY_POS=$hist_count
  redraw_input_line "$buffer" "$(get_command_suggestion "$buffer")"

  while true; do
    if ! IFS= read -rsn1 key < /dev/tty; then
      printf '\r\033[2K\n'
      return 1
    fi

    if [ -z "$key" ]; then
      printf '\r\033[2K  %bYou › %b%s\n' "$BOLD$C_USER" "$R" "$buffer"
      INPUT_RESULT="$buffer"
      if [ -n "$buffer" ]; then
        if [ "$hist_count" -eq 0 ] || [ "${INPUT_HISTORY[$((hist_count-1))]}" != "$buffer" ]; then
          INPUT_HISTORY+=("$buffer")
          [ "${#INPUT_HISTORY[@]}" -gt 100 ] && INPUT_HISTORY=("${INPUT_HISTORY[@]: -100}")
        fi
      fi
      return 0
    fi

    case "$key" in
      $'\177'|$'\b')
        [ -n "$buffer" ] && buffer="${buffer%?}" ;;
      $'\025')
        buffer="" ;;
      $'\027')
        while [[ "$buffer" == *' ' ]]; do buffer="${buffer%?}"; done
        while [ -n "$buffer" ] && [[ "${buffer: -1}" != ' ' ]]; do buffer="${buffer%?}"; done ;;
      $'\t')
        suggestion=$(get_command_suggestion "$buffer")
        [ -n "$suggestion" ] && buffer+="$suggestion" ;;
      $'\e')
        seq=""
        IFS= read -rsn2 -t 0.08 seq < /dev/tty || true
        case "$seq" in
          '[C')
            suggestion=$(get_command_suggestion "$buffer")
            [ -n "$suggestion" ] && buffer+="$suggestion" ;;
          '[A')
            if [ "$INPUT_HISTORY_POS" -gt 0 ]; then
              INPUT_HISTORY_POS=$((INPUT_HISTORY_POS - 1))
              buffer="${INPUT_HISTORY[$INPUT_HISTORY_POS]}"
            fi ;;
          '[B')
            if [ "$INPUT_HISTORY_POS" -lt "$hist_count" ]; then
              INPUT_HISTORY_POS=$((INPUT_HISTORY_POS + 1))
              if [ "$INPUT_HISTORY_POS" -eq "$hist_count" ]; then buffer=""; else buffer="${INPUT_HISTORY[$INPUT_HISTORY_POS]}"; fi
            fi ;;
        esac ;;
      $'\004')
        if [ -z "$buffer" ]; then
          printf '\r\033[2K\n'
          return 1
        fi ;;
      *) buffer+="$key" ;;
    esac

    suggestion=$(get_command_suggestion "$buffer")
    redraw_input_line "$buffer" "$suggestion"
  done
}

# ── BOOT ─────────────────────────────────
choose_provider
fetch_models
print_header

# ── MAIN LOOP ────────────────────────────
while true; do
  if ! read_input_with_preview; then
    printf "\n  ${C_DIM}Bye!${R}\n\n"
    exit 0
  fi
  input="$INPUT_RESULT"
  [ -z "$input" ] && continue
  case "$input" in
    /q|/quit|/exit) printf "\n  ${C_DIM}Bye!${R}\n\n"; exit 0 ;;
    /clear)         HISTORY="[]"; print_header ;;
    /save)          save_chat ;;
    /ls)            list_saved ;;
    /list)          list_all_models ;;
    /switch)        switch_provider ;;
    /settings)      open_settings ;;
    /install)       install_self ;;
    /bal|/balance)  check_balance ;;
    /s\ *|/search\ *)
      clean_in=$(echo "$input" | sed -E 's/^\/(s|search)//' | sed 's/^ *//')
      if [ -z "$clean_in" ]; then
        printf "  ${C_USER}Search: ${R}"; read -r q; search_models "$q"
      else
        search_models "$clean_in"
      fi ;;
    /s|/search)
      printf "  ${C_USER}Search: ${R}"; read -r q; search_models "$q" ;;
    /model)
      printf "  ${C_USER}Model ID: ${R}"; read -r MODEL; MODEL=$(echo "$MODEL" | tr -d '[:space:]')
      printf "  ${C_DIM}Switched to: ${C_USER}%s${R}\n\n" "$MODEL" ;;
    /default)
      if save_current_model_as_default; then printf "  ${C_ASST}✓ Saved %s as the %s default.${R}\n\n" "$MODEL" "$PROVIDER"; fi ;;
    /default\ clear)
      clear_provider_default_model; select_automatic_model
      printf "  ${C_ASST}✓ Default cleared. Using %s.${R}\n\n" "$MODEL" ;;
    /memory) memory_menu; print_header ;;
    /memory\ on) CFG_MEMORY_ENABLED="true"; save_config; printf "  ${C_ASST}✓ AI memory enabled.${R}\n\n" ;;
    /memory\ off) CFG_MEMORY_ENABLED="false"; save_config; printf "  ${C_ASST}✓ AI memory disabled.${R}\n\n" ;;
    /memory\ clear) memory_clear; printf "  ${C_ASST}✓ AI memory cleared.${R}\n\n" ;;
    /memory\ add\ *)
      memory_add_fact "${input#/memory add }" && printf "  ${C_ASST}✓ Remembered.${R}\n\n" ;;
    /memory\ forget\ *)
      memory_forget_matching "${input#/memory forget }" && printf "  ${C_ASST}✓ Updated memory.${R}\n\n" ;;
    /key)
      printf "  ${C_USER}New key: ${R}"; read -r -s API_KEY; echo ""
      save_key "$PROVIDER" "$API_KEY"
      printf "  ${C_DIM}✓ Key saved.${R}\n\n"; MODELS_CACHE=""; fetch_models ;;
    /refresh)       MODELS_CACHE=""; fetch_models ;;
    /help)
      printf "\n  ${BOLD}Commands:${R}\n"
      printf "  ${C_USER}/s <query>${R}    search models\n"
      printf "  ${C_USER}/list${R}         browse all models (pick to switch)\n"
      printf "  ${C_USER}/model${R}        enter model ID manually\n"
      printf "  ${C_USER}/default${R}      save current model as provider default\n"
      printf "  ${C_USER}/default clear${R} clear the saved provider default\n"
      printf "  ${C_USER}/memory${R}       manage compact persistent AI memory\n"
      printf "  ${C_USER}/switch${R}       switch provider\n"
      printf "  ${C_USER}/balance${R}      check remaining credits / provider metrics\n"
      printf "  ${C_USER}/settings${R}     colors, memory, output limit, defaults\n"
      printf "  ${C_USER}/key${R}          change & save API key\n"
      printf "  ${C_USER}/save${R}         save conversation\n"
      printf "  ${C_USER}/ls${R}           list saved chats\n"
      printf "  ${C_USER}/clear${R}        reset conversation\n"
      printf "  ${C_USER}/refresh${R}      re-fetch model list\n"
      printf "  ${C_USER}/install${R}      install as 'tchat' globally\n"
      printf "  ${C_USER}/q${R}            quit\n"
      printf "  ${C_DIM}While typing a command, press Tab or → to accept the gray preview.${R}\n\n" ;;
    *)
      printf "  ${C_DIM}thinking...${R}\n"
      send_message "$input" ;;
  esac
done
