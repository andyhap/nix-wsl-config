
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zsh
    starship
    zoxide
    eza
    bat
    fd
    ripgrep
    fzf
  ];

  # --- Starship Theme ---
  home.file.".config/starship.toml".source =
    ./starship/ctp-blue.toml;

  programs.bash = {
    enable = true;

    shellAliases = {
      # --- Git ---
      gs = "git status";
      ga = "git add .";
      gcm = "git commit -m";
      gp = "git push";

      # --- Navigation ---
      croot = "cd ~/nix-wsl-config";

      # --- Nix maintenance ---
      gc = "nix store gc";
      nix-clean = "nix store gc && nix store optimise";
      nixfast = "nix shell nixpkgs#";

      # --- Config editing ---
      edit-home = "nano ~/nix-wsl-config/home.nix";
      edit-flake = "nano ~/nix-wsl-config/flake.nix";
      edit-shell = "nano ~/nix-wsl-config/modules/shell.nix";

      # --- Shell utilities ---
      ll = "eza -lah";
      cat = "bat";
      grep = "rg";
    };

    initExtra = ''
      # --- Prompt & Navigation ---
      eval "$(zoxide init bash)"
      eval "$(starship init bash)"

      # --- Home Manager ---
      rebuild() {
        home-manager --flake "$HOME/nix-wsl-config#andyhap" switch "$@"
      }

      rebuild-build() {
        nix build "$HOME/nix-wsl-config#homeConfigurations.andyhap.activationPackage" --no-link "$@"
      }

      rollback() {
        home-manager --flake "$HOME/nix-wsl-config#andyhap" switch --rollback "$@"
      }

      gens() {
        home-manager generations
      }

      nix-check() {
        home-manager -n --flake "$HOME/nix-wsl-config#andyhap" switch
      }

      # --- Flake Management ---
      update() {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update &&
          rebuild
        )
      }

      update-hm() {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update home-manager
        )
      }

      update-nixpkgs() {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update nixpkgs
        )
      }

      # --- Repository Diagnostics ---
      dirty() {
        git -C "$HOME/nix-wsl-config" status --short
      }
    '';
  };
}
