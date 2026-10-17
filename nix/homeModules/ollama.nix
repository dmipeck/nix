{
  flake.homeModules.ollama =
    { ... }:
    {
      services.ollama.enable = true;
    };
}
