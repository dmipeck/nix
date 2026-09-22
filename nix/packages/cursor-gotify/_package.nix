# Minimal Gotify push CLI for Cursor agent lifecycle hooks.
# Talks HTTP to a Gotify server (typically local); no agent judgment required.
{
  lib,
  writeShellApplication,
  curl,
  coreutils,
  jq,
}:

writeShellApplication {
  name = "cursor-gotify";
  runtimeInputs = [
    curl
    coreutils
    jq
  ];
  text = ''
    set -euo pipefail

    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/cursor-gotify"
    config_file="$config_dir/env"
    reply_marker_dir="$config_dir/reply-by-gen"
    last_reply_file="$config_dir/last-reply-push"
    # Fallback window when generation_id is missing (seconds).
    stop_dedupe_secs="''${CURSOR_GOTIFY_STOP_DEDUPE_SECS:-30}"

    # Optional env file (GOTIFY_URL / GOTIFY_TOKEN). Shell env wins.
    if [ -f "$config_file" ]; then
      set -a
      # shellcheck disable=SC1090
      . "$config_file"
      set +a
    fi

    url="''${GOTIFY_URL:-}"
    token="''${GOTIFY_TOKEN:-}"
    title="Cursor"
    priority="5"
    message=""
    # Max body length for heuristic afterAgentResponse pushes (chars).
    max_chars="''${CURSOR_GOTIFY_MAX_CHARS:-400}"

    usage() {
      cat <<'EOF'
    Usage:
      cursor-gotify push [-t title] [-p priority] <message>
      cursor-gotify hook-stop
      cursor-gotify hook-after-agent-response

    Config (env overrides file):
      GOTIFY_URL / GOTIFY_TOKEN
      $XDG_CONFIG_HOME/cursor-gotify/env
      CURSOR_GOTIFY_MAX_CHARS (default 400) — truncate afterAgentResponse text
      CURSOR_GOTIFY_STOP_DEDUPE_SECS (default 30) — fallback stop suppress window

    hook-after-agent-response reads afterAgentResponse JSON (.text), truncates,
    and pushes a heuristic "Agent replied" notification (noisy; not needs-input).
    On successful push it records the generation so hook-stop can stay quiet.

    hook-stop pushes "Agent stopped" only when no "agent replied" push was
    recorded for this generation (abort/error/empty text, or afterAgentResponse
    disabled). Skips when a reply notification already covered the turn.
    EOF
    }

    push_message() {
      if [ -z "$url" ] || [ -z "$token" ]; then
        echo "cursor-gotify: GOTIFY_URL and GOTIFY_TOKEN are required" >&2
        exit 1
      fi
      if [ -z "$message" ]; then
        echo "cursor-gotify: message is required" >&2
        exit 1
      fi
      base="''${url%/}"
      curl -fsS \
        -H "X-Gotify-Key: $token" \
        -F "title=$title" \
        -F "message=$message" \
        -F "priority=$priority" \
        "$base/message" >/dev/null
    }

    # Collapse whitespace and truncate to max_chars (append … if cut).
    truncate_message() {
      local raw="$1"
      local flat
      flat="$(printf '%s' "$raw" | tr '\n\r\t' '   ' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [ "''${#flat}" -le "$max_chars" ]; then
        printf '%s' "$flat"
        return
      fi
      printf '%s…' "''${flat:0:max_chars}"
    }

    safe_gen_name() {
      printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'
    }

    mark_reply_sent() {
      local gen="$1"
      mkdir -p "$reply_marker_dir"
      date +%s > "$last_reply_file"
      if [ -n "$gen" ]; then
        : > "$reply_marker_dir/$(safe_gen_name "$gen")"
      fi
    }

    # True if an agent-replied push already covered this turn.
    reply_already_notified() {
      local gen="$1"
      if [ -n "$gen" ] && [ -f "$reply_marker_dir/$(safe_gen_name "$gen")" ]; then
        return 0
      fi
      # Fallback when generation_id missing from either hook payload.
      if [ -z "$gen" ] && [ -f "$last_reply_file" ]; then
        local now prev age
        now="$(date +%s)"
        prev="$(cat "$last_reply_file" 2>/dev/null || echo 0)"
        age=$((now - prev))
        if [ "$age" -ge 0 ] && [ "$age" -le "$stop_dedupe_secs" ]; then
          return 0
        fi
      fi
      return 1
    }

    clear_reply_marker() {
      local gen="$1"
      if [ -n "$gen" ]; then
        rm -f "$reply_marker_dir/$(safe_gen_name "$gen")"
      fi
    }

    if [ "$#" -lt 1 ]; then
      usage
      exit 2
    fi

    cmd="$1"
    shift

    case "$cmd" in
      push)
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -t|--title)
              title="''${2:-}"
              shift 2
              ;;
            -p|--priority)
              priority="''${2:-}"
              shift 2
              ;;
            -h|--help)
              usage
              exit 0
              ;;
            --)
              shift
              break
              ;;
            -*)
              echo "cursor-gotify: unknown option: $1" >&2
              usage
              exit 2
              ;;
            *)
              break
              ;;
          esac
        done
        message="$*"
        push_message
        ;;
      hook-stop)
        # Only notify when "agent replied" did not already cover this generation.
        payload="$(cat || true)"
        gen="$(printf '%s' "$payload" | jq -r '.generation_id // empty' 2>/dev/null || true)"
        if reply_already_notified "$gen"; then
          clear_reply_marker "$gen"
          exit 0
        fi
        message="Agent stopped"
        title="Cursor"
        push_message || true
        exit 0
        ;;
      hook-after-agent-response)
        # Heuristic: last assistant text from afterAgentResponse hook stdin.
        # Not a reliable "needs input" signal — fires on every agent reply.
        payload="$(cat || true)"
        text="$(printf '%s' "$payload" | jq -r '.text // empty' 2>/dev/null || true)"
        gen="$(printf '%s' "$payload" | jq -r '.generation_id // empty' 2>/dev/null || true)"
        if [ -z "$text" ]; then
          exit 0
        fi
        message="$(truncate_message "$text")"
        if [ -z "$message" ]; then
          exit 0
        fi
        title="Cursor · agent replied"
        if push_message; then
          mark_reply_sent "$gen"
        fi
        exit 0
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        echo "cursor-gotify: unknown command: $cmd" >&2
        usage
        exit 2
        ;;
    esac
  '';

  meta = {
    description = "Push Cursor agent stop / reply events to a Gotify server";
    homepage = "https://gotify.net/docs/pushmsg";
    license = lib.licenses.mit;
    mainProgram = "cursor-gotify";
    platforms = lib.platforms.linux;
  };
}
