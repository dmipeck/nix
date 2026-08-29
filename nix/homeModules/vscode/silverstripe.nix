{ ... }:

{
  flake.vscodeModules.silverstripe = pkgs: {
    extensions = with pkgs.vscode-extensions; [
      pkgs.vscode-marketplace.adrianhumphreys.silverstripe
      pkgs.vscode-marketplace.shevaua.phpcs
      bmewburn.vscode-intelephense-client
      xdebug.php-debug
    ];
  };
}
