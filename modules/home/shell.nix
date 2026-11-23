
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    starship
    zoxide
    eza
    bat
    fd
    ripgrep
    fzf
  ];

  home.file.".config/starship.toml".source =
    ./starship/ctp-blue.toml;

  programs.bash = {
    enable = true;

    shellAliases = {
      # Git
      gs = "git status";
      ga = "git add .";
      gcm = "git commit -m";
      gp = "git push";

      # Navigation
      croot = "cd ~/nix-wsl-config";

      # PostgreSQL (on-demand)
      start-pg = "sudo systemctl start postgresql.target";
      stop-pg = "sudo systemctl stop postgresql.target";
      restart-pg = "sudo systemctl restart postgresql.target";
      status-pg = "systemctl status postgresql.target postgresql.service --no-pager";

      # Nix maintenance
      gc = "nix store gc";
      nix-clean = "nix store gc && nix store optimise";
      nixfast = "nix shell nixpkgs#";

      # Config editing
      edit-home = "nano ~/nix-wsl-config/home.nix";
      edit-flake = "nano ~/nix-wsl-config/flake.nix";
      edit-shell = "nano ~/nix-wsl-config/modules/home/shell.nix";

      # Shell utilities
      ll = "eza -lah";
      cat = "bat";
      grep = "rg";
    };

    initExtra = ''
      # Prompt & Navigation
      eval "$(zoxide init bash)"
      eval "$(starship init bash)"

      # NixOS configuration
      rebuild() {
        sudo nixos-rebuild switch --flake "$HOME/nix-wsl-config#nixos" "$@"
      }

      rebuild-build() {
        nix build "$HOME/nix-wsl-config#nixosConfigurations.nixos.config.system.build.toplevel" --no-link "$@"
      }

      rollback() {
        sudo nixos-rebuild switch --rollback "$@"
      }

      nix-check() {
        nix flake check "$HOME/nix-wsl-config" "$@"
      }

      # Flake management
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

      # Repository diagnostics
      dirty() {
        git -C "$HOME/nix-wsl-config" status --short
      }
    '';
  };
}
