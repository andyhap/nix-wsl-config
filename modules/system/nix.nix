{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;

    # Resource-conscious builds for WSL
    max-jobs = 1;
    cores = 2;
  };
}
