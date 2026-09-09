#!/usr/bin/env bash
# Seam: nix/dotagents/hard-copy-skill-md.nix — SKILL.md text → command markdown.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="$(cd "$(dirname "$0")" && pwd)/fixtures"
LIB="$ROOT/nix/dotagents/hard-copy-skill-md.nix"
fail=0

eval_copy() {
  local src=$1
  nix-instantiate --eval --strict --json --expr "
    let
      pkgs = import <nixpkgs> { };
      hardCopy = import ${LIB} pkgs.lib;
      text = builtins.readFile ${src};
    in
    hardCopy text
  " | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

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
  local name="$1" src="$2"
  if eval_copy "$src" >/dev/null 2>&1; then
    echo "not ok - $name (expected non-zero exit)"
    fail=1
  else
    echo "ok - $name"
  fi
}

got=$(eval_copy "$FIX/with-flag.md")
want=$(cat "$FIX/with-flag.want.md")
assert_eq "multiline description hard-copy" "$want" "$got"

got=$(eval_copy "$FIX/plain-desc.md")
want=$(cat "$FIX/plain-desc.want.md")
assert_eq "plain description hard-copy" "$want" "$got"

assert_fails "missing description" "$FIX/no-desc.md"
assert_fails "no frontmatter" "$FIX/no-fm.md"

if [[ "$fail" -ne 0 ]]; then
  echo "FAILED"
  exit 1
fi
echo "ALL PASSED"
