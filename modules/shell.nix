
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

  programs.zsh = {
    enable = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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

    initContent = ''
      # --- Prompt & Navigation ---
      eval "$(zoxide init zsh)"
      eval "$(starship init zsh)"

      # --- Home Manager ---
      function rebuild {
        home-manager --flake "$HOME/nix-wsl-config#andyhap" switch "$@"
      }

      function rebuild-build {
        nix build "$HOME/nix-wsl-config#homeConfigurations.andyhap.activationPackage" --no-link "$@"
      }

      function rollback {
        home-manager --flake "$HOME/nix-wsl-config#andyhap" switch --rollback "$@"
      }

      function gens {
        home-manager generations
      }

      function nix-check {
        home-manager -n --flake "$HOME/nix-wsl-config#andyhap" switch
      }

      # --- Flake Management ---
      function update {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update &&
          rebuild
        )
      }

      function update-hm {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update home-manager
        )
      }

      function update-nixpkgs {
        (
          cd "$HOME/nix-wsl-config" &&
          nix flake update nixpkgs
        )
      }

      # --- Repository Diagnostics ---
      function dirty {
        git -C "$HOME/nix-wsl-config" status --short
      }
    '';
  };
}
