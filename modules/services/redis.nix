
{ lib, ... }:

{
  services.redis.servers."" = {
    enable = true;

    # Local development only
    bind = "127.0.0.1";
    port = 6379;
    openFirewall = false;

    # Persistence menggunakan konfigurasi RDB default Redis
    appendOnly = false;

    settings = {
      protected-mode = true;
    };
  };

  # Jangan otomatis berjalan ketika WSL dimulai
  systemd.services.redis.wantedBy = lib.mkForce [];
}
