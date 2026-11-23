{ ... }:

{
  imports = [
    ./modules/home
  ];

  home = {
    username = "andyhap";
    homeDirectory = "/home/andyhap";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
