{ ... }:

{
  imports = [
    ../../modules/system
  ];

  time.timeZone = "Asia/Jakarta";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.andyhap = import ../../home.nix;
  };

  system.stateVersion = "26.05";
}
