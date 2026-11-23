
{ config, pkgs, ... }:

{
  imports = [
    ../../modules/nixos
  ];

  # NixOS-WSL integration
  wsl = {
    enable = true;
    defaultUser = "andyhap";
  };

  # User account
  users.users.andyhap = {
    isNormalUser = true;
    description = "Andy Hikmal Parakkasi";
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
  };

  # Timezone
  time.timeZone = "Asia/Jakarta";

  # Nix configuration
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;
  };

  # Home Manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.andyhap = import ../../home.nix;
  };

  # Keep this unchanged after installation
  system.stateVersion = "26.05";
}
