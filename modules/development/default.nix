{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # PHP
    php84
    php84Packages.composer

    # JavaScript / TypeScript
    nodejs
    bun
    pnpm

    # Python
    python313
    uv
    python313Packages.python-lsp-server

    # Rust
    rustc
    cargo
    rust-analyzer

    # Go
    go

    # Java
    jdk21

    # C / C++
    gcc
    llvmPackages_21.clang-unwrapped
    cmake
    gnumake

    # Version control
    git
    gh

    # Redis CLI / tools
    redis

    # Nix language server
    nixd

    # Networking & IPC
    socat

    # Shell checking
    shellcheck
  ];
}
