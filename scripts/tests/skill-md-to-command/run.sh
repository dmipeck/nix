#!/usr/bin/env bash
# Seam: scripts/skill-md-to-command.sh — SKILL.md path → command markdown on stdout.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$ROOT/scripts/skill-md-to-command.sh"
FIX="$(cd "$(dirname "$0")" && pwd)/fixtures"
fail=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok - $name"
  else
    echo "not ok - $name"
    echo "expected:"
    printf '%s\n' "$expected" | sed 's/^/  /'
    echo "actual:"
    printf '%s\n' "$actual" | sed 's/^/  /'
    fail=1
  fi
}

assert_fails() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "not ok - $name (expected non-zero exit)"
    fail=1
  else
    echo "ok - $name"
  fi
}

# --- happy: multiline description, strips skill-only keys ---
got=$("$SCRIPT" "$FIX/with-flag.md")
want=$(cat "$FIX/with-flag.want.md")
assert_eq "multiline description hard-copy" "$want" "$got"

# --- happy: plain single-line description ---
got=$("$SCRIPT" "$FIX/plain-desc.md")
want=$(cat "$FIX/plain-desc.want.md")
assert_eq "plain description hard-copy" "$want" "$got"

# --- missing description fails ---
assert_fails "missing description" "$SCRIPT" "$FIX/no-desc.md"

# --- no frontmatter fails ---
assert_fails "no frontmatter" "$SCRIPT" "$FIX/no-fm.md"

if [[ "$fail" -ne 0 ]]; then
  echo "FAILED"
  exit 1
fi
echo "ALL PASSED"
