#!/usr/bin/env python3
"""Hard-copy a Skill SKILL.md into slash-command markdown.

Reads SKILL.md at argv[1], writes a Command file to stdout:
  - frontmatter keeps only `description:` (skill-only keys dropped)
  - body is everything after the skill frontmatter
Exits non-zero if frontmatter or description is missing/unusable.
"""
from __future__ import annotations

import sys


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(1)


def split_frontmatter(text: str) -> tuple[str, str]:
    if text.startswith("---\r\n"):
        rest = text[5:]
    elif text.startswith("---\n"):
        rest = text[4:]
    else:
        die("missing frontmatter")

    for sep in ("\n---\n", "\n---\r\n"):
        idx = rest.find(sep)
        if idx >= 0:
            return rest[:idx], rest[idx + len(sep) :]
    # Closing --- at EOF
    if rest.endswith("\n---"):
        return rest[: -len("\n---")], ""
    if rest == "---":
        return "", ""
    die("unclosed frontmatter")


def extract_description(fm: str) -> str | None:
    """Return description value suitable after `description: `, or None."""
    lines = fm.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.startswith("description:"):
            i += 1
            continue
        raw = line[len("description:") :]
        stripped = raw.strip()
        # YAML block/folded scalar indicators
        if stripped in (">", ">-", ">|", "|", "|-", "|+"):
            i += 1
            block: list[str] = []
            while i < len(lines):
                cont = lines[i]
                if cont.startswith((" ", "\t")) or cont == "":
                    block.append(cont)
                    i += 1
                    continue
                break
            if not block:
                return None
            return stripped + "\n" + "\n".join(block)
        if stripped == "":
            return None
        return stripped
    return None


def main(argv: list[str]) -> None:
    if len(argv) != 2:
        die(f"usage: {argv[0]} SKILL.md")
    path = argv[1]
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        die(str(e))

    fm, body = split_frontmatter(text)
    desc = extract_description(fm)
    if desc is None or desc.strip() == "":
        die("missing description")

    if body.startswith("\r\n"):
        body = body[2:]
    elif body.startswith("\n"):
        body = body[1:]

    sys.stdout.write("---\n")
    sys.stdout.write(f"description: {desc}")
    if not desc.endswith("\n"):
        sys.stdout.write("\n")
    sys.stdout.write("---\n\n")
    sys.stdout.write(body)
    if body and not body.endswith("\n"):
        sys.stdout.write("\n")


if __name__ == "__main__":
    main(sys.argv)
