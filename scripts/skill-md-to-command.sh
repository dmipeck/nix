#!/usr/bin/env bash
# Hard-copy a Skill SKILL.md into slash-command markdown on stdout.
#
# Frontmatter keeps only `description:` (skill-only keys dropped).
# Body is everything after the skill frontmatter.
# Exits non-zero if frontmatter or description is missing/unusable.
set -euo pipefail

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

[[ $# -eq 1 ]] || die "usage: $0 SKILL.md"
path=$1
[[ -f $path ]] || die "missing file: $path"

fm_lines=()
closed=0
body=

{
  IFS= read -r open || true
  [[ $open == '---' ]] || die "missing frontmatter"

  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line == '---' ]]; then
      closed=1
      break
    fi
    fm_lines+=("$line")
  done
  [[ $closed -eq 1 ]] || die "unclosed frontmatter"

  body=$(cat)
} <"$path"

# Drop a single leading blank line from the body for stable output.
if [[ $body == $'\n'* ]]; then
  body=${body#$'\n'}
elif [[ $body == $'\r\n'* ]]; then
  body=${body#$'\r\n'}
fi

desc=
desc_style=
in_desc_block=0
for line in "${fm_lines[@]+"${fm_lines[@]}"}"; do
  if [[ $in_desc_block -eq 1 ]]; then
    if [[ $line == ' '* || $line == $'\t'* || $line == '' ]]; then
      desc+=$'\n'"$line"
      continue
    fi
    break
  fi
  case $line in
  description:*)
    raw=${line#description:}
    stripped=${raw#"${raw%%[![:space:]]*}"}
    case $stripped in
    '>' | '>-' | '>|' | '|' | '|-' | '|+')
      desc_style=$stripped
      in_desc_block=1
      desc=
      ;;
    '')
      die "missing description"
      ;;
    *)
      desc=$stripped
      ;;
    esac
    ;;
  esac
done

if [[ -n $desc_style ]]; then
  [[ -n $desc ]] || die "missing description"
  desc_out="$desc_style$desc"
else
  [[ -n ${desc//[[:space:]]/} ]] || die "missing description"
  desc_out=$desc
fi

printf '%s\n' '---'
printf 'description: %s\n' "$desc_out"
printf '%s\n\n' '---'
printf '%s' "$body"
[[ -z $body || $body == *$'\n' ]] || printf '\n'
