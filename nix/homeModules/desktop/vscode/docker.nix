{ ... }:

{
  flake.vscodeModules.docker = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      docker.docker
    ];

    userSettings = {
      "docker.extension.enableComposeLanguageServer" = false;
      "yaml.disableSchemaDetection" = [
        "**/docker-compose.yml"
        "**/docker-compose.yaml"
        "**/docker-compose.*.yml"
        "**/docker-compose.*.yaml"
        "**/compose.yml"
        "**/compose.yaml"
        "**/compose.*.yml"
        "**/compose.*.yaml"
      ];
    };
  };
}
