# Flake check for lib/hard-copy-skill-md.nix (Skill SKILL.md → command markdown).
{
  perSystem =
    { pkgs, ... }:
    let
      hardCopy = import ../../lib/hard-copy-skill-md.nix pkgs.lib;
      fixtures = ../../lib/hard-copy-skill-md/fixtures;

      read = name: builtins.readFile (fixtures + "/${name}");

      multiline = hardCopy (read "with-flag.md");
      plain = hardCopy (read "plain-desc.md");

      noDesc = builtins.tryEval (hardCopy (read "no-desc.md"));
      noFm = builtins.tryEval (hardCopy (read "no-fm.md"));

      # Forced at eval time; failure throws and the check never builds.
      ok =
        assert multiline == read "with-flag.want.md";
        assert plain == read "plain-desc.want.md";
        assert !noDesc.success;
        assert !noFm.success;
        "ok\n";
    in
    {
      checks.hard-copy-skill-md = pkgs.writeText "hard-copy-skill-md-ok" ok;
    };
}
