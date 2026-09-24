# Cursor CLI status line — context + subscription usage left, then model; repo below.
# Reads StatusLinePayload JSON on stdin; optional plan usage via DashboardService
# (cached under $XDG_CACHE_HOME/cursor-statusline-usage.json).
{
  lib,
  stdenvNoCC,
  makeWrapper,
  writeTextFile,
  bash,
  jq,
  curl,
  git,
  coreutils,
}:

let
  script = writeTextFile {
    name = "cursor-statusline.sh";
    executable = true;
    text = ''
      #!${bash}/bin/bash
      input=$(cat)

      MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
      PARAM=$(echo "$input" | jq -r '.model.param_summary // empty')
      PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
      TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
      DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
      VIM=$(echo "$input" | jq -r '.vim.mode // empty')
      WT=$(echo "$input" | jq -r '.worktree.name // empty')

      RESET=$'\033[0m'
      DIM=$'\033[90m'
      CYAN=$'\033[36m'
      BULLET='•'

      make_bar() {
        local pct="''${1:-0}" width="''${2:-10}"
        [ "$pct" -lt 0 ] 2>/dev/null && pct=0
        [ "$pct" -gt 100 ] 2>/dev/null && pct=100
        local filled=$((pct * width / 100))
        local empty=$((width - filled))
        local bar="" fill pad
        [ "$filled" -gt 0 ] && printf -v fill "%''${filled}s" && bar="''${fill// /▓}"
        [ "$empty" -gt 0 ] && printf -v pad "%''${empty}s" && bar="''${bar}''${pad// /░}"
        printf '%s' "$bar"
      }

      bar_color() {
        local pct="''${1:-0}"
        if [ "$pct" -ge 80 ]; then printf '%s' $'\033[31m'
        elif [ "$pct" -ge 50 ]; then printf '%s' $'\033[33m'
        else printf '%s' $'\033[32m'
        fi
      }

      # ── Cached GetCurrentPeriodUsage (subscription bar) ──
      CACHE_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/cursor-statusline-usage.json"
      AUTH_FILE="''${CURSOR_AUTH_FILE:-$HOME/.config/cursor/auth.json}"
      CACHE_TTL=60

      refresh_usage_cache() {
        local token tmp
        token=$(jq -r '.accessToken // empty' "$AUTH_FILE" 2>/dev/null) || return 1
        [ -n "$token" ] || return 1
        mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true
        tmp=$(mktemp "''${CACHE_FILE}.XXXXXX" 2>/dev/null) || return 1
        if curl -sS --max-time 1.5 \
            -X POST 'https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage' \
            -H "Authorization: Bearer ''${token}" \
            -H 'Content-Type: application/json' \
            -H 'Connect-Protocol-Version: 1' \
            -d '{}' \
            -o "$tmp" 2>/dev/null \
          && jq -e '.planUsage' "$tmp" >/dev/null 2>&1; then
          mv -f "$tmp" "$CACHE_FILE"
          return 0
        fi
        rm -f "$tmp"
        return 1
      }

      cache_is_fresh() {
        local mtime now
        [ -f "$CACHE_FILE" ] || return 1
        mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null) || return 1
        now=$(date +%s)
        [ $((now - mtime)) -lt "$CACHE_TTL" ]
      }

      cache_is_fresh || refresh_usage_cache || true

      SUB_USAGE=""
      SUB_CYCLE=""
      if [ -f "$CACHE_FILE" ]; then
        SUB_USAGE=$(jq -r '
          (.planUsage.totalPercentUsed // .planUsage.apiPercentUsed // empty)
          | if . == null or . == "" then empty else floor end
        ' "$CACHE_FILE" 2>/dev/null)
        SUB_CYCLE=$(jq -r '
          (.billingCycleStart | tonumber) as $s
          | (.billingCycleEnd | tonumber) as $e
          | if $e > $s then
              (((now * 1000) - $s) / ($e - $s) * 100 | floor)
            else empty end
        ' "$CACHE_FILE" 2>/dev/null)
      fi

      CTX_BAR=$(make_bar "$PCT" 10)
      CTX_COLOR=$(bar_color "$PCT")

      if [ "$TOKENS" -ge 1000 ] 2>/dev/null; then
        TOK_LABEL="$((TOKENS / 1000))K"
      else
        TOK_LABEL="$TOKENS"
      fi

      REPO="''${DIR##*/}"
      BRANCH=""
      if git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
      fi

      # Line 1: bars left, then model (+param +vim mode)
      MODEL_LABEL="$MODEL"
      [ -n "$PARAM" ] && MODEL_LABEL="$MODEL $PARAM"
      [ -n "$VIM" ] && MODEL_LABEL="$MODEL_LABEL $VIM"
      MODE_FMT="''${CYAN}''${MODEL_LABEL}''${RESET}"

      # Line 2: repo / branch / worktree
      if [ -n "$BRANCH" ]; then
        REPO_LABEL="''${REPO} on  ''${BRANCH}"
      else
        REPO_LABEL="$REPO"
      fi
      [ -n "$WT" ] && REPO_LABEL="''${REPO_LABEL} [''${WT}]"

      CTX_FMT="''${DIM}Context''${RESET} ''${CTX_COLOR}''${CTX_BAR} ''${TOK_LABEL} (''${PCT}%)''${RESET}"
      BARS_FMT="$CTX_FMT"

      if [ -n "$SUB_USAGE" ] && [ -n "$SUB_CYCLE" ]; then
        [ "$SUB_CYCLE" -gt 100 ] 2>/dev/null && SUB_CYCLE=100
        [ "$SUB_CYCLE" -lt 0 ] 2>/dev/null && SUB_CYCLE=0
        SUB_BAR=$(make_bar "$SUB_USAGE" 10)
        SUB_COLOR=$(bar_color "$SUB_USAGE")
        SUB_FMT="''${DIM}Usage''${RESET} ''${SUB_COLOR}''${SUB_BAR} ''${SUB_USAGE}%/''${SUB_CYCLE}%''${RESET}"
        BARS_FMT="''${BARS_FMT} ''${DIM}''${BULLET}''${RESET} ''${SUB_FMT}"
      fi

      # bars • mode — left-aligned, no width padding
      SEP_FMT=" ''${DIM}''${BULLET}''${RESET} "
      printf "%b%b%b\n" "$BARS_FMT" "$SEP_FMT" "$MODE_FMT"
      printf "%b\n" "''${DIM}''${REPO_LABEL}''${RESET}"
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "cursor-statusline";
  version = "0.1.0";

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp ${script} $out/bin/cursor-statusline
    chmod +x $out/bin/cursor-statusline
    wrapProgram $out/bin/cursor-statusline --prefix PATH : ${
      lib.makeBinPath [
        bash
        jq
        curl
        git
        coreutils
      ]
    }
    runHook postInstall
  '';

  meta = {
    description = "Cursor CLI status line (model, context bar, plan usage)";
    license = lib.licenses.mit;
    mainProgram = "cursor-statusline";
    platforms = lib.platforms.linux;
  };
}
