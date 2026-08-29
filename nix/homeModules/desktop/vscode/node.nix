{ ... }:

{
  flake.vscodeModules.node = _pkgs: {
    userSettings = {
      "chat.tools.terminal.autoApprove" = {
        "/^npm\\s+(ls|list|outdated|view|info|show|explain|why|root|prefix|bin|search|doctor|fund|repo|bugs|docs|home|help(-search)?)\\b/" =
          true;
        "/^npm\\s+config\\s+(list|get)\\b/" = true;
        "/^npm\\s+pkg\\s+get\\b/" = true;
        "/^npm\\s+audit$/" = true;
        "/^npm\\s+cache\\s+verify\\b/" = true;
        "/^yarn\\s+(list|outdated|info|why|bin|help|versions)\\b/" = true;
        "/^yarn\\s+licenses\\b/" = true;
        "/^yarn\\s+audit\\b(?!.*\\bfix\\b)/" = true;
        "/^yarn\\s+config\\s+(list|get)\\b/" = true;
        "/^yarn\\s+cache\\s+dir\\b/" = true;
        "/^pnpm\\s+(ls|list|outdated|why|root|bin|doctor)\\b/" = true;
        "/^pnpm\\s+licenses\\b/" = true;
        "/^pnpm\\s+audit\\b(?!.*\\bfix\\b)/" = true;
        "/^pnpm\\s+config\\s+(list|get)\\b/" = true;
        "npm ci" = true;
        "/^yarn\\s+install\\s+--frozen-lockfile\\b/" = true;
        "/^pnpm\\s+install\\s+--frozen-lockfile\\b/" = true;
      };
    };
  };
}
