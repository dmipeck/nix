# Pure-Nix hard-copy: Skill SKILL.md text → slash-command markdown.
# Frontmatter keeps only `description:`; skill-only keys are dropped.
# Throws if frontmatter or description is missing/unusable.
lib: text:
let
  die = msg: throw "hard-copy-skill-md: ${msg}";

  trim =
    s:
    let
      # Strip leading/trailing ASCII whitespace.
      match = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" s;
    in
    if s == "" then
      ""
    else if match == null then
      ""
    else
      builtins.head match;

  # Split into lines; tolerate a missing final newline.
  lines = lib.splitString "\n" (if lib.hasSuffix "\n" text then lib.removeSuffix "\n" text else text);

  open = builtins.head lines;
  rest = lib.drop 1 lines;

  closeIdxs = builtins.filter (i: (builtins.elemAt rest i) == "---") (
    lib.range 0 (builtins.length rest - 1)
  );
  closeAt = if closeIdxs == [ ] then die "unclosed frontmatter" else builtins.head closeIdxs;

  fmLines = lib.take closeAt rest;
  bodyLines = lib.drop (closeAt + 1) rest;

  # Drop a single leading blank line from the body.
  bodyLines' =
    if bodyLines != [ ] && builtins.head bodyLines == "" then lib.drop 1 bodyLines else bodyLines;
  body = lib.concatStringsSep "\n" bodyLines';

  # Walk fm lines for description (plain or YAML block/folded scalar).
  extract =
    ls:
    if ls == [ ] then
      null
    else
      let
        line = builtins.head ls;
        tail = lib.drop 1 ls;
      in
      if lib.hasPrefix "description:" line then
        let
          raw = lib.removePrefix "description:" line;
          stripped = trim raw;
        in
        if
          builtins.elem stripped [
            ">"
            ">-"
            ">|"
            "|"
            "|-"
            "|+"
          ]
        then
          let
            takeBlock =
              xs: acc:
              if xs == [ ] then
                acc
              else
                let
                  h = builtins.head xs;
                  t = lib.drop 1 xs;
                in
                if h == "" || lib.hasPrefix " " h || lib.hasPrefix "\t" h then takeBlock t (acc ++ [ h ]) else acc;
            block = takeBlock tail [ ];
          in
          if block == [ ] then null else stripped + "\n" + lib.concatStringsSep "\n" block
        else if stripped == "" then
          null
        else
          stripped
      else
        extract tail;

  desc = extract fmLines;
  desc' = if desc == null || trim desc == "" then die "missing description" else desc;

  out =
    "---\n"
    + "description: ${desc'}\n"
    + "---\n\n"
    + body
    + (if body == "" || lib.hasSuffix "\n" body then "" else "\n");
in
if open != "---" then die "missing frontmatter" else out
