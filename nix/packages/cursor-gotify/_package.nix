# Minimal Gotify push CLI for Cursor agent lifecycle hooks.
# Talks HTTP to a Gotify server (typically local); no agent judgment required.
{
  lib,
  writeShellApplication,
  curl,
  coreutils,
}:

writeShellApplication {
  name = "cursor-gotify";
  runtimeInputs = [
    curl
    coreutils
  ];
  text = ''
    set -euo pipefail

    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/cursor-gotify"
    config_file="$config_dir/env"

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

    usage() {
      cat <<'EOF'
    Usage:
      cursor-gotify push [-t title] [-p priority] <message>
      cursor-gotify hook-stop

    Config (env overrides file):
      GOTIFY_URL / GOTIFY_TOKEN
      $XDG_CONFIG_HOME/cursor-gotify/env

    hook-stop drains Cursor hook stdin and pushes "Agent stopped".
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
        cat >/dev/null || true
        message="Agent stopped"
        title="Cursor"
        push_message || true
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
    description = "Push Cursor agent stop events to a Gotify server";
    homepage = "https://gotify.net/docs/pushmsg";
    license = lib.licenses.mit;
    mainProgram = "cursor-gotify";
    platforms = lib.platforms.linux;
  };
}
