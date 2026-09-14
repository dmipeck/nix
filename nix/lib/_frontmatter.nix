# Eval-time Frontmatter Parser — owned YAML subset + importMarkdown.
# Same class as lib.importJSON: pure, no IFD. Swap to builtins.fromYAML later
# behind the same API.
#
# Subset: maps, lists, scalars (bool/null/int/float/string), block scalars
# (| / > / >-), nested metadata, quoted keys. No IFD.
{ lib }:
let
  inherit (builtins)
    substring
    stringLength
    elemAt
    length
    head
    filter
    genList
    split
    match
    fromJSON
    toJSON
    foldl'
    listToAttrs
    readFile
    ;

  inherit (lib)
    hasPrefix
    hasSuffix
    concatStringsSep
    concatMapStringsSep
    optionalString
    isAttrs
    isList
    isBool
    isInt
    isFloat
    isString
    reverseList
    sublist
    ;

  isNull = v: v == null;

  charAt = s: i: substring i 1 s;

  countIndent =
    line:
    let
      m = match "( *).*" line;
    in
    if m == null then 0 else stringLength (head m);

  trim =
    s:
    let
      # Strip leading + trailing ASCII space/tab.
      chars = genList (i: charAt s i) (stringLength s);
      dropL =
        xs: if xs == [ ] || (head xs != " " && head xs != "\t") then xs else dropL (builtins.tail xs);
      dropR = xs: reverseList (dropL (reverseList xs));
    in
    concatStringsSep "" (dropR (dropL chars));

  splitLines =
    text:
    let
      parts = split "\n" text;
    in
    map (p: if isString p then p else "") (filter isString parts);

  parseQuoted =
    s:
    let
      len = stringLength s;
    in
    if len >= 2 && charAt s 0 == "\"" && charAt s (len - 1) == "\"" then
      fromJSON s
    else if len >= 2 && charAt s 0 == "'" && charAt s (len - 1) == "'" then
      substring 1 (len - 2) s
    else
      null;

  parseScalar =
    raw:
    let
      s = trim raw;
      quoted = parseQuoted s;
      num = match "-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?" s;
    in
    if quoted != null then
      quoted
    else if s == "true" then
      true
    else if s == "false" then
      false
    else if s == "null" || s == "~" then
      null
    else if num != null then
      fromJSON s
    else
      s;

  # Position of mapping `:` outside quotes/brackets, or -1.
  findMappingColon =
    content:
    let
      len = stringLength content;
      go =
        i: inSingle: inDouble: depth:
        if i >= len then
          -1
        else
          let
            c = charAt content i;
          in
          if inDouble then
            if c == "\\" then
              go (i + 2) inSingle inDouble depth
            else if c == "\"" then
              go (i + 1) inSingle false depth
            else
              go (i + 1) inSingle inDouble depth
          else if inSingle then
            if c == "'" then go (i + 1) false inDouble depth else go (i + 1) inSingle inDouble depth
          else if c == "\"" then
            go (i + 1) inSingle true depth
          else if c == "'" then
            go (i + 1) true inDouble depth
          else if c == "[" || c == "{" then
            go (i + 1) inSingle inDouble (depth + 1)
          else if c == "]" || c == "}" then
            go (i + 1) inSingle inDouble (if depth > 0 then depth - 1 else 0)
          else if c == ":" && depth == 0 then
            if i + 1 >= len then
              i
            else if charAt content (i + 1) == " " || charAt content (i + 1) == "\t" then
              i
            else
              go (i + 1) inSingle inDouble depth
          else
            go (i + 1) inSingle inDouble depth;
    in
    go 0 false false 0;

  isBlockIndicator =
    s:
    let
      t = trim s;
    in
    t == "|" || t == "|-" || t == "|+" || t == ">" || t == ">-" || t == ">+";

  blockStyle =
    ind:
    let
      t = trim ind;
    in
    if hasPrefix "|" t then
      {
        fold = false;
        chomp =
          if hasSuffix "-" t then
            "strip"
          else if hasSuffix "+" t then
            "keep"
          else
            "clip";
      }
    else
      {
        fold = true;
        chomp =
          if hasSuffix "-" t then
            "strip"
          else if hasSuffix "+" t then
            "keep"
          else
            "clip";
      };

  # Collect block-scalar content lines after an indicator line at parentIndent.
  collectBlock =
    lines: startIdx: parentIndent: style:
    let
      contentIndent =
        let
          go =
            i:
            if i >= length lines then
              parentIndent + 2
            else
              let
                line = elemAt lines i;
                ind = countIndent line;
              in
              if trim line == "" then
                go (i + 1)
              else if ind > parentIndent then
                ind
              else
                parentIndent + 2;
        in
        go startIdx;

      collected =
        let
          go =
            i: acc:
            if i >= length lines then
              {
                inherit acc;
                next = i;
              }
            else
              let
                line = elemAt lines i;
                ind = countIndent line;
                empty = trim line == "";
              in
              if !empty && ind < contentIndent then
                {
                  inherit acc;
                  next = i;
                }
              else if empty then
                go (i + 1) (acc ++ [ "" ])
              else
                go (i + 1) (acc ++ [ (substring contentIndent (stringLength line - contentIndent) line) ]);
        in
        go startIdx [ ];

      raw = collected.acc;

      joined =
        if !style.fold then
          concatStringsSep "\n" raw
        else
          # Folded: non-empty lines join with space; blank line → paragraph break.
          foldl' (
            acc: line:
            if line == "" then
              if acc == "" then
                "\n"
              else if hasSuffix "\n" acc then
                acc + "\n"
              else
                acc + "\n"
            else if acc == "" then
              line
            else if hasSuffix "\n" acc then
              acc + line
            else
              acc + " " + line
          ) "" raw;

      chomped =
        if style.chomp == "strip" then
          if hasSuffix "\n" joined then substring 0 (stringLength joined - 1) joined else joined
        else if style.chomp == "keep" then
          if joined == "" || hasSuffix "\n" joined then joined else joined + "\n"
        else
        # clip: single trailing newline
        if joined == "" then
          ""
        else if hasSuffix "\n" joined then
          joined
        else
          joined;
    in
    {
      value = chomped;
      next = collected.next;
    };

  parseFlowList =
    content:
    let
      t = trim content;
      inner = trim (substring 1 (stringLength t - 2) t);
    in
    if inner == "" then
      [ ]
    else
      let
        parts =
          let
            go =
              i: cur: inQ: acc:
              if i >= stringLength inner then
                acc ++ [ (trim cur) ]
              else
                let
                  c = charAt inner i;
                in
                if inQ then
                  if c == "\"" then go (i + 1) (cur + c) false acc else go (i + 1) (cur + c) true acc
                else if c == "\"" then
                  go (i + 1) (cur + c) true acc
                else if c == "," then
                  go (i + 1) "" false (acc ++ [ (trim cur) ])
                else
                  go (i + 1) (cur + c) false acc;
          in
          go 0 "" false [ ];
      in
      map parseScalar parts;

  parseKey =
    raw:
    let
      q = parseQuoted (trim raw);
    in
    if q != null then q else trim raw;

  parseMapping =
    lines: idx: mapIndent:
    let
      go =
        i: attrs:
        if i >= length lines then
          {
            value = listToAttrs attrs;
            next = i;
          }
        else
          let
            line = elemAt lines i;
            ind = countIndent line;
            content = trim line;
          in
          if content == "" then
            go (i + 1) attrs
          else if ind < mapIndent then
            {
              value = listToAttrs attrs;
              next = i;
            }
          else if ind > mapIndent then
            {
              value = listToAttrs attrs;
              next = i;
            }
          else
            let
              colon = findMappingColon content;
            in
            if colon < 0 then
              {
                value = listToAttrs attrs;
                next = i;
              }
            else
              let
                key = parseKey (substring 0 colon content);
                restVal = trim (substring (colon + 1) (stringLength content - colon - 1) content);
                parsed =
                  if restVal == "" then
                    parseNode lines (i + 1) (mapIndent + 1)
                  else if isBlockIndicator restVal then
                    collectBlock lines (i + 1) mapIndent (blockStyle restVal)
                  else if hasPrefix "[" restVal then
                    {
                      value = parseFlowList restVal;
                      next = i + 1;
                    }
                  else
                    {
                      value = parseScalar restVal;
                      next = i + 1;
                    };
              in
              go parsed.next (
                attrs
                ++ [
                  {
                    name = key;
                    value = parsed.value;
                  }
                ]
              );
    in
    go idx [ ];

  parseSequence =
    lines: idx: seqIndent:
    let
      go =
        i: acc:
        if i >= length lines then
          {
            value = acc;
            next = i;
          }
        else
          let
            line = elemAt lines i;
            ind = countIndent line;
            content = trim line;
          in
          if content == "" then
            go (i + 1) acc
          else if ind < seqIndent then
            {
              value = acc;
              next = i;
            }
          else if ind == seqIndent && (hasPrefix "- " content || content == "-") then
            let
              rest = if content == "-" then "" else substring 2 (stringLength content - 2) content;
              item =
                if rest == "" then
                  parseNode lines (i + 1) (seqIndent + 2)
                else if isBlockIndicator rest then
                  collectBlock lines (i + 1) seqIndent (blockStyle rest)
                else if findMappingColon rest >= 0 then
                  # `- key: val` → mapping item; continue keys at seqIndent+2
                  let
                    colon = findMappingColon rest;
                    key = parseKey (substring 0 colon rest);
                    restVal = trim (substring (colon + 1) (stringLength rest - colon - 1) rest);
                    first =
                      if restVal == "" then
                        parseNode lines (i + 1) (seqIndent + 2)
                      else if isBlockIndicator restVal then
                        collectBlock lines (i + 1) seqIndent (blockStyle restVal)
                      else
                        {
                          value = parseScalar restVal;
                          next = i + 1;
                        };
                    restMap = parseMapping lines first.next (seqIndent + 2);
                  in
                  {
                    value = {
                      ${key} = first.value;
                    }
                    // restMap.value;
                    next = restMap.next;
                  }
                else
                  {
                    value = parseScalar rest;
                    next = i + 1;
                  };
            in
            go item.next (acc ++ [ item.value ])
          else
            {
              value = acc;
              next = i;
            };
    in
    go idx [ ];

  parseNode =
    lines: idx: minIndent:
    if idx >= length lines then
      {
        value = null;
        next = idx;
      }
    else
      let
        line = elemAt lines idx;
        ind = countIndent line;
        content = trim line;
      in
      if content == "" then
        parseNode lines (idx + 1) minIndent
      else if ind < minIndent then
        {
          value = null;
          next = idx;
        }
      else if hasPrefix "- " content || content == "-" then
        parseSequence lines idx ind
      else if findMappingColon content >= 0 then
        parseMapping lines idx ind
      else if hasPrefix "[" content then
        {
          value = parseFlowList content;
          next = idx + 1;
        }
      else
        {
          value = parseScalar content;
          next = idx + 1;
        };

  fromYAML =
    text:
    let
      lines = splitLines text;
      start =
        let
          go =
            i:
            if i >= length lines then
              i
            else
              let
                c = trim (elemAt lines i);
              in
              if c == "" || c == "---" || c == "..." then go (i + 1) else i;
        in
        go 0;
    in
    (parseNode lines start 0).value;

  # ---- toYAML -----------------------------------------------------------

  escapeKey = k: if match "[A-Za-z_][A-Za-z0-9_-]*" k != null then k else toJSON k;

  # Quote strings that would be ambiguous as plain YAML scalars.
  escapeStr =
    s:
    if
      match "[A-Za-z0-9_./@*+-][A-Za-z0-9_./@*+ -]*" s != null
      && match ".*:.*" s == null
      && s != "true"
      && s != "false"
      && s != "null"
      && s != "~"
    then
      s
    else
      toJSON s;

  spaces = n: concatStringsSep "" (genList (_: " ") n);

  # Render a value that appears after `key: ` on the same line (inline).
  toYAMLInline =
    value:
    if isNull value then
      "null"
    else if isBool value then
      (if value then "true" else "false")
    else if isInt value || isFloat value then
      # toJSON keeps float spelling (0.1) instead of toString's 0.100000.
      toJSON value
    else if isString value then
      escapeStr value
    else if isList value && value == [ ] then
      "[]"
    else if isAttrs value && value == { } then
      "{}"
    else
      null; # needs block form

  # Optional keyOrder keeps Authoring / emit field order stable (attrNames is sorted).
  toYAMLBlock =
    indent: keyOrder: value:
    if isList value then
      concatMapStringsSep "\n" (
        item:
        let
          inline = toYAMLInline item;
        in
        spaces indent
        + "- "
        + (
          if inline != null then
            inline
          else if isAttrs item then
            "\n" + toYAMLBlock (indent + 2) null item
          else
            toYAMLBlock (indent + 2) null item
        )
      ) value
    else if isAttrs value then
      let
        names =
          if keyOrder == null then
            builtins.attrNames value
          else
            let
              preferred = builtins.filter (k: value ? ${k}) keyOrder;
              rest = builtins.filter (k: !(builtins.elem k keyOrder)) (builtins.attrNames value);
            in
            preferred ++ rest;
      in
      concatMapStringsSep "\n" (
        k:
        let
          v = value.${k};
          key = escapeKey k;
          inline = toYAMLInline v;
        in
        if isString v && match ".*\n.*" v != null then
          let
            ls = splitLines v;
            ls' = if ls != [ ] && elemAt ls (length ls - 1) == "" then sublist 0 (length ls - 1) ls else ls;
            body = concatMapStringsSep "\n" (l: spaces (indent + 2) + l) ls';
          in
          spaces indent + key + ": |\n" + body
        else if inline != null then
          spaces indent + key + ": " + inline
        else
          spaces indent + key + ":\n" + toYAMLBlock (indent + 2) null v
      ) names
    else
      spaces indent + toYAMLInline value;

  toYAML =
    value:
    let
      inline = toYAMLInline value;
    in
    if inline != null then inline else toYAMLBlock 0 null value;

  # Like toYAML but emits attrs with a preferred key order (emit seam).
  toYAMLOrdered =
    keyOrder: value:
    let
      inline = toYAMLInline value;
    in
    if inline != null then inline else toYAMLBlock 0 keyOrder value;

  # ---- importMarkdown ---------------------------------------------------

  importMarkdown =
    path:
    let
      text = readFile path;
      lines = splitLines text;
    in
    if length lines < 2 || trim (head lines) != "---" then
      throw "importMarkdown: ${toString path} has no leading --- frontmatter fence"
    else
      let
        findClose =
          i:
          if i >= length lines then
            null
          else if trim (elemAt lines i) == "---" then
            i
          else
            findClose (i + 1);
        close = findClose 1;
      in
      if close == null then
        throw "importMarkdown: ${toString path} has no closing --- frontmatter fence"
      else
        {
          frontmatter = fromYAML (concatStringsSep "\n" (sublist 1 (close - 1) lines));
          body =
            let
              rest = sublist (close + 1) (length lines - close - 1) lines;
              # Drop one leading blank line after closing fence (common style).
              rest' = if rest != [ ] && head rest == "" then builtins.tail rest else rest;
            in
            concatStringsSep "\n" rest' + optionalString (rest' != [ ]) "\n";
        };

in
{
  inherit
    fromYAML
    toYAML
    toYAMLOrdered
    importMarkdown
    ;
}
