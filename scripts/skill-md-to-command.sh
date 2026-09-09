#!/usr/bin/env bash
# Hard-copy Skill SKILL.md → slash-command markdown on stdout.
# See scripts/skill-md-to-command.py for behaviour.
set -euo pipefail
exec python3 "$(dirname "$0")/skill-md-to-command.py" "$@"
