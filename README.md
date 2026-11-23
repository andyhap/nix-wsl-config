# nix-wsl-config

Konfigurasi **NixOS-WSL** pribadi untuk workstation development di Windows (WSL2), dikelola sepenuhnya secara deklaratif dengan **Nix Flakes** + **Home Manager**.

Repo ini berfungsi sebagai cadangan setup saya sekaligus referensi kalau ada yang ingin meniru atau mengadaptasinya.

## Isi Setup

| Kategori | Isi |
| --- | --- |
| **Base** | NixOS 26.05 · NixOS-WSL · Home Manager (sebagai modul NixOS) |
| **Bahasa & Toolchain** | PHP 8.4 + Composer · Node.js, Bun, pnpm · Python 3.13 + uv · Rust (rustc, cargo) · Go · JDK 21 · GCC, Clang 21, CMake, Make |
| **Language Server** | `nixd`, `rust-analyzer`, `python-lsp-server` |
| **Database** | PostgreSQL 18 · Redis (keduanya **tidak** auto-start, dijalankan saat dibutuhkan) |
| **CLI Tools** | git, gh, starship, zoxide, eza, bat, fd, ripgrep, fzf, shellcheck, socat |
| **AI Agents** | [Claude Code](https://github.com/sadjow/claude-code-nix) · [Google Antigravity CLI](https://github.com/jacopone/antigravity-nix) |
| **Prompt** | Starship dengan tema Catppuccin Mocha |

## Struktur Direktori

```
.
├── flake.nix                     # Entry point: inputs & nixosConfigurations.nixos
├── flake.lock
├── home.nix                      # Konfigurasi Home Manager untuk user
├── hosts/
│   └── wsl/default.nix           # Host WSL: timezone, home-manager, stateVersion
└── modules/
    ├── system/                   # Modul level sistem (NixOS)
    │   ├── wsl.nix               # Pengaturan NixOS-WSL (default user)
    │   ├── users.nix             # Definisi user
    │   ├── nix.nix               # Flakes, auto-optimise, limit build untuk WSL
    │   ├── packages.nix          # Import modul development
    │   └── services.nix          # Import service (PostgreSQL, Redis)
    ├── development/default.nix   # Bahasa pemrograman & toolchain
    ├── services/
    │   ├── postgresql.nix        # PostgreSQL 18, localhost-only, scram-sha-256
    │   └── redis.nix             # Redis, bind 127.0.0.1:6379
    └── home/                     # Modul Home Manager
        ├── shell.nix             # Bash, alias, fungsi helper, CLI tools
        ├── agents.nix            # Claude Code & Antigravity CLI
        └── starship/ctp-blue.toml
```

## Instalasi

### 1. Pasang NixOS-WSL

Ikuti panduan resmi [NixOS-WSL](https://github.com/nix-community/NixOS-WSL): unduh `nixos.wsl` dari halaman release, lalu jalankan (double-click) atau impor lewat PowerShell:

```powershell
wsl --install --from-file nixos.wsl
```

### 2. Clone repo ini

Konfigurasi ini mengasumsikan repo berada di `~/nix-wsl-config` (dipakai oleh alias & fungsi helper).

```bash
nix-shell -p git --run "git clone https://github.com/andyhap/nix-wsl-config.git ~/nix-wsl-config"
cd ~/nix-wsl-config
```

### 3. Sesuaikan dengan user kamu (kalau bukan saya)

Username `andyhap` di-hardcode di beberapa tempat. Ganti dengan username kamu di:

- `modules/system/wsl.nix` → `wsl.defaultUser`
- `modules/system/users.nix` → `users.users.<nama>` dan `description`
- `hosts/wsl/default.nix` → `home-manager.users.<nama>`
- `home.nix` → `home.username` dan `home.homeDirectory`

Sesuaikan juga `time.timeZone` (di `hosts/wsl/default.nix`) dan timezone PostgreSQL (di `modules/services/postgresql.nix`) kalau tidak berada di WIB.

> **Catatan:** Jangan ubah `system.stateVersion` / `home.stateVersion` pada sistem yang sudah berjalan kecuali kamu paham konsekuensinya.

### 4. Build & switch

```bash
sudo nixos-rebuild switch --flake ~/nix-wsl-config#nixos
```

Setelah itu restart WSL dari PowerShell (`wsl --shutdown`) lalu buka lagi, terutama jika `defaultUser` diganti.

## Penggunaan Sehari-hari

Setelah build pertama, perintah-perintah berikut tersedia di Bash.

### Manajemen NixOS

| Perintah | Fungsi |
| --- | --- |
| `rebuild` | `nixos-rebuild switch` dari flake ini |
| `rebuild-build` | Build konfigurasi tanpa switch (untuk mengecek error) |
| `rollback` | Kembali ke generasi sebelumnya |
| `nix-check` | `nix flake check` |
| `update` | Update semua input flake lalu rebuild |
| `update-nixpkgs` / `update-hm` | Update input `nixpkgs` / `home-manager` saja |
| `dirty` | Lihat perubahan yang belum di-commit di repo config |
| `gc` / `nix-clean` | Garbage collect store (+ optimise) |
| `nixfast <pkg>` | Shell sementara dengan paket dari nixpkgs, mis. `nixfast htop` |
| `croot` | `cd` ke repo config |

### Database (on-demand)

PostgreSQL dan Redis sengaja **tidak** dijalankan otomatis saat WSL start supaya hemat resource.

| PostgreSQL | Redis |
| --- | --- |
| `start-pg` | `start-redis` |
| `stop-pg` | `stop-redis` |
| `restart-pg` | `restart-redis` |
| `status-pg` | `status-redis` |

**Catatan PostgreSQL:**
- Hanya listen di `localhost:5432`, tidak terekspos ke jaringan.
- User `postgres` login via peer auth: `sudo -u postgres psql`.
- User/role lain wajib memakai password (`scram-sha-256`), jadi buat role dengan password dulu, misalnya:
  ```sql
  CREATE ROLE myapp WITH LOGIN PASSWORD 'secret' CREATEDB;
  ```

**Catatan Redis:** bind ke `127.0.0.1:6379`, `protected-mode` aktif, persistence memakai RDB bawaan.

### Alias lain

| Alias | Perintah |
| --- | --- |
| `gs`, `ga`, `gcm`, `gp` | `git status` / `add .` / `commit -m` / `push` |
| `ll` | `eza -lah` |
| `cat` | `bat` |
| `grep` | `rg` |
| `edit-home`, `edit-flake`, `edit-shell` | Buka file config terkait dengan `nano` |

## Catatan Desain

- **Build dibatasi** (`max-jobs = 1`, `cores = 2`) di `modules/system/nix.nix` agar WSL tidak menghabiskan RAM/CPU Windows. Naikkan kalau mesin kamu kuat.
- **`auto-optimise-store`** aktif untuk menghemat ruang disk VHDX.
- Home Manager dipakai sebagai modul NixOS (`useGlobalPkgs` + `useUserPackages`), jadi cukup satu perintah `rebuild` untuk sistem dan user sekaligus.
- Input flake eksternal (`claude-code`, `antigravity-nix`) diteruskan ke modul lewat `specialArgs` / `extraSpecialArgs`.

## Menambah Sesuatu

- **Paket development / toolchain** → `modules/development/default.nix`
- **CLI tool atau alias user** → `modules/home/shell.nix`
- **Service baru** → buat file di `modules/services/`, lalu import di `modules/system/services.nix`
- **Input flake baru** → tambahkan di `flake.nix`, teruskan via `specialArgs` (dan `extraSpecialArgs` di `hosts/wsl/default.nix` jika dipakai Home Manager)

Lalu jalankan `rebuild`.

## Kredit

- [NixOS-WSL](https://github.com/nix-community/NixOS-WSL)
- [Home Manager](https://github.com/nix-community/home-manager)
- [claude-code-nix](https://github.com/sadjow/claude-code-nix) oleh sadjow
- [antigravity-nix](https://github.com/jacopone/antigravity-nix) oleh jacopone
- Tema Starship oleh a3chron, memakai palet [Catppuccin](https://github.com/catppuccin/catppuccin)
