
{ pkgs, ... }:

let
  postgresql = pkgs.postgresql;

  dataDir = "/var/lib/postgresql/18/main";
  configDir = "/etc/postgresql/18/main";

  configSource = ../services/postgresql;
in
{
  # PostgreSQL server configuration
  home.file = {
    ".config/nix-wsl-config/postgresql/postgresql.conf".text =
      builtins.readFile "${configSource}/postgresql.conf";

    ".config/nix-wsl-config/postgresql/pg_hba.conf".text =
      builtins.readFile "${configSource}/pg_hba.conf";

    # System-level systemd unit template
    ".config/nix-wsl-config/postgresql/postgresql.service".text = ''
      [Unit]
      Description=PostgreSQL Database Server 18
      Documentation=https://www.postgresql.org/docs/18/
      After=network.target
      RequiresMountsFor=${dataDir}

      [Service]
      Type=simple
      User=postgres
      Group=postgres

      RuntimeDirectory=postgresql
      RuntimeDirectoryMode=2775

      UMask=0077
      LimitNOFILE=65536

      ExecStart=${postgresql}/bin/postgres -D ${dataDir} -c config_file=${configDir}/postgresql.conf -c hba_file=${configDir}/pg_hba.conf
      ExecReload=/bin/kill -HUP $MAINPID

      KillSignal=SIGINT
      TimeoutStopSec=120

      Restart=on-failure
      RestartSec=5

      [Install]
      WantedBy=multi-user.target
    '';
  };
}
