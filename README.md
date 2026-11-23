# nix-wsl-config

**English** | [Bahasa Indonesia](README.id.md)

My personal **NixOS-WSL** configuration for a development workstation on Windows (WSL2), managed fully declaratively with **Nix Flakes** + **Home Manager**.

This repo serves as a backup of my setup and as a reference for anyone who wants to copy or adapt it.

## What's Included

| Category | Contents |
| --- | --- |
| **Base** | NixOS 26.05 · NixOS-WSL · Home Manager (as a NixOS module) |
| **Languages & Toolchains** | PHP 8.4 + Composer · Node.js, Bun, pnpm · Python 3.13 + uv · Rust (rustc, cargo) · Go · JDK 21 · GCC, Clang 21, CMake, Make |
| **Language Servers** | `nixd`, `rust-analyzer`, `python-lsp-server` |
| **Databases** | PostgreSQL 18 · Redis (neither starts automatically; run them on demand) |
| **CLI Tools** | git, gh, starship, zoxide, eza, bat, fd, ripgrep, fzf, shellcheck, socat |
| **AI Agents** | [Claude Code](https://github.com/sadjow/claude-code-nix) · [Google Antigravity CLI](https://github.com/jacopone/antigravity-nix) |
| **Prompt** | Starship with the Catppuccin Mocha theme |

## Directory Structure

```
.
├── flake.nix                     # Entry point: inputs & nixosConfigurations.nixos
├── flake.lock
├── home.nix                      # Home Manager configuration for the user
├── hosts/
│   └── wsl/default.nix           # WSL host: timezone, home-manager, stateVersion
└── modules/
    ├── system/                   # System-level (NixOS) modules
    │   ├── wsl.nix               # NixOS-WSL settings (default user)
    │   ├── users.nix             # User definition
    │   ├── nix.nix               # Flakes, auto-optimise, build limits for WSL
    │   ├── packages.nix          # Imports the development module
    │   └── services.nix          # Imports services (PostgreSQL, Redis)
    ├── development/default.nix   # Programming languages & toolchains
    ├── services/
    │   ├── postgresql.nix        # PostgreSQL 18, localhost-only, scram-sha-256
    │   └── redis.nix             # Redis, bound to 127.0.0.1:6379
    └── home/                     # Home Manager modules
        ├── shell.nix             # Bash, aliases, helper functions, CLI tools
        ├── agents.nix            # Claude Code & Antigravity CLI
        └── starship/ctp-blue.toml
```

## Installation

### 1. Install NixOS-WSL

Follow the official [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) guide: download `nixos.wsl` from the releases page, then open it (double-click) or import it from PowerShell:

```powershell
wsl --install --from-file nixos.wsl
```

### 2. Clone this repo

This configuration assumes the repo lives at `~/nix-wsl-config` (the aliases and helper functions rely on it).

```bash
nix-shell -p git --run "git clone https://github.com/andyhap/nix-wsl-config.git ~/nix-wsl-config"
cd ~/nix-wsl-config
```

### 3. Adapt it to your user (if you're not me)

The username `andyhap` is hardcoded in a few places. Replace it with your own username in:

- `modules/system/wsl.nix` → `wsl.defaultUser`
- `modules/system/users.nix` → `users.users.<name>` and `description`
- `hosts/wsl/default.nix` → `home-manager.users.<name>`
- `home.nix` → `home.username` and `home.homeDirectory`

Also adjust `time.timeZone` (in `hosts/wsl/default.nix`) and the PostgreSQL timezone (in `modules/services/postgresql.nix`) if you're not in Asia/Jakarta (WIB).

> **Note:** Don't change `system.stateVersion` / `home.stateVersion` on an existing system unless you understand the consequences.

### 4. Build & switch

```bash
sudo nixos-rebuild switch --flake ~/nix-wsl-config#nixos
```

Afterwards, restart WSL from PowerShell (`wsl --shutdown`) and open it again, especially if you changed `defaultUser`.

## Daily Usage

After the first build, the following commands are available in Bash.

### NixOS Management

| Command | Description |
| --- | --- |
| `rebuild` | `nixos-rebuild switch` from this flake |
| `rebuild-build` | Build the configuration without switching (to check for errors) |
| `rollback` | Switch back to the previous generation |
| `nix-check` | `nix flake check` |
| `update` | Update all flake inputs, then rebuild |
| `update-nixpkgs` / `update-hm` | Update only the `nixpkgs` / `home-manager` input |
| `dirty` | Show uncommitted changes in the config repo |
| `gc` / `nix-clean` | Garbage-collect the store (+ optimise) |
| `nixfast <pkg>` | Temporary shell with a package from nixpkgs, e.g. `nixfast htop` |
| `croot` | `cd` into the config repo |

### Databases (on demand)

PostgreSQL and Redis intentionally do **not** start when WSL boots, to save resources.

| PostgreSQL | Redis |
| --- | --- |
| `start-pg` | `start-redis` |
| `stop-pg` | `stop-redis` |
| `restart-pg` | `restart-redis` |
| `status-pg` | `status-redis` |

**PostgreSQL notes:**
- Listens only on `localhost:5432`; not exposed to the network.
- The `postgres` user logs in via peer auth: `sudo -u postgres psql`.
- Every other user/role must use a password (`scram-sha-256`), so create a role with a password first, for example:
  ```sql
  CREATE ROLE myapp WITH LOGIN PASSWORD 'secret' CREATEDB;
  ```

**Redis notes:** bound to `127.0.0.1:6379`, `protected-mode` enabled, persistence uses the default RDB snapshots.

### Other Aliases

| Alias | Command |
| --- | --- |
| `gs`, `ga`, `gcm`, `gp` | `git status` / `add .` / `commit -m` / `push` |
| `ll` | `eza -lah` |
| `cat` | `bat` |
| `grep` | `rg` |
| `edit-home`, `edit-flake`, `edit-shell` | Open the related config file in `nano` |

## Design Notes

- **Builds are limited** (`max-jobs = 1`, `cores = 2`) in `modules/system/nix.nix` so WSL doesn't eat up Windows' RAM/CPU. Raise them if your machine can handle it.
- **`auto-optimise-store`** is enabled to save space on the VHDX disk.
- Home Manager is used as a NixOS module (`useGlobalPkgs` + `useUserPackages`), so a single `rebuild` applies both the system and the user configuration.
- External flake inputs (`claude-code`, `antigravity-nix`) are passed to modules via `specialArgs` / `extraSpecialArgs`.

## Adding Things

- **Development packages / toolchains** → `modules/development/default.nix`
- **CLI tools or user aliases** → `modules/home/shell.nix`
- **New services** → create a file in `modules/services/`, then import it in `modules/system/services.nix`
- **New flake inputs** → add them to `flake.nix` and pass them via `specialArgs` (and `extraSpecialArgs` in `hosts/wsl/default.nix` if Home Manager needs them)

Then run `rebuild`.

## Credits

- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
- [Home Manager](https://github.com/nix-community/home-manager)
- [claude-code-nix](https://github.com/sadjow/claude-code-nix) by sadjow
- [antigravity-nix](https://github.com/jacopone/antigravity-nix) by jacopone
- Starship theme by a3chron, using the [Catppuccin](https://github.com/catppuccin/catppuccin) palette
