{ config, pkgs, ... }:

{
  imports = [
    ./modules/packages.nix
  ];

  home = {
    username = "andyhap";
    homeDirectory = "/home/andyhap";

    # Initial Home Manager compatibility version.
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
