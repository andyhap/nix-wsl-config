{ claude-code, antigravity-nix, ... }:

{
  imports = [
    ../../modules/system
  ];

  time.timeZone = "Asia/Jakarta";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      inherit claude-code antigravity-nix;
    };

    users.andyhap = import ../../home.nix;
  };

  system.stateVersion = "26.05";
}
