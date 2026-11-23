{ claude-code, antigravity-nix, pkgs, ... }:

{
  home.packages = [
    # Claude Code
    claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Antigravity CLI
    antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];
}
