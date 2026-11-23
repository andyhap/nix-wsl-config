{ pkgs, ... }:

{
  users.users.andyhap = {
    isNormalUser = true;
    description = "Andy Hikmal Parakkasi";
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
  };
}
