{ pkgs, lib, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_18;

    enableTCPIP = false;

    settings = {
      port = 5432;
      listen_addresses = "localhost";
      unix_socket_directories = "/run/postgresql";

      password_encryption = "scram-sha-256";
      timezone = "Asia/Jakarta";
      log_timezone = "Asia/Jakarta";

      logging_collector = false;
      log_min_duration_statement = 1000;
      log_line_prefix = "%m [%p] %u@%d ";

      max_connections = 100;
      autovacuum = true;
    };

    authentication = lib.mkForce ''
      local all postgres peer
      local all all scram-sha-256
      host all all 127.0.0.1/32 scram-sha-256
      host all all ::1/128 scram-sha-256
    '';

    initdbArgs = [
      "--locale-provider=icu"
      "--icu-locale=en-ID"
    ];
  };

  systemd.targets.postgresql.wantedBy = lib.mkForce [];
}
