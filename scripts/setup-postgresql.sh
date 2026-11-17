#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

# ============================================================
# PostgreSQL 18 - WSL Provisioning Script
# Target: Ubuntu 24.04 WSL2 + Nix PostgreSQL 18.7
# Locale: UTF8 + ICU en-ID
#
# Safety:
# - Preflights existing state before making system changes.
# - Never deletes database data.
# - Never overwrites different configuration files.
# - Never changes metadata of existing directories/files.
# - Never reinitializes an existing cluster.
# - Enables systemd service without starting it.
# ============================================================

readonly PG_VERSION="18"
readonly EXPECTED_PG_RELEASE="18.7"

readonly PG_ROOT="/var/lib/postgresql"
readonly DATA_PARENT="${PG_ROOT}/18"
readonly DATA_DIR="${DATA_PARENT}/main"

readonly ETC_PG_ROOT="/etc/postgresql"
readonly ETC_PG_VERSION="${ETC_PG_ROOT}/18"
readonly CONFIG_DIR="${ETC_PG_VERSION}/main"

readonly SERVICE_NAME="postgresql.service"
readonly SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

readonly HM_CONFIG_REL=".config/nix-wsl-config/postgresql"

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 ||
        die "Required command not found: $1"
}

# Validate an existing directory without modifying it.
check_directory_state() {
    local path="$1"
    local owner="$2"
    local group="$3"
    shift 3

    local actual
    local allowed
    local valid="no"

    if [[ -L "$path" ]]; then
        die "Refusing symlink directory: $path"
    fi

    if [[ ! -e "$path" ]]; then
        return 0
    fi

    [[ -d "$path" ]] ||
        die "Path exists but is not a directory: $path"

    actual="$(stat -c '%U:%G:%a' -- "$path")"

    for allowed in "$@"; do
        if [[ "$actual" == "${owner}:${group}:${allowed}" ]]; then
            valid="yes"
            break
        fi
    done

    [[ "$valid" == "yes" ]] ||
        die "Unexpected directory metadata: $path ($actual). Manual review required."
}

# Validate an existing file without modifying it.
check_file_state() {
    local source="$1"
    local destination="$2"
    local owner="$3"
    local group="$4"
    local mode="$5"

    if [[ -L "$destination" ]]; then
        die "Refusing symlink destination: $destination"
    fi

    if [[ ! -e "$destination" ]]; then
        return 0
    fi

    [[ -f "$destination" ]] ||
        die "Destination is not a regular file: $destination"

    cmp -s -- "$source" "$destination" ||
        die "Existing file differs from repository artifact: $destination"

    local actual
    actual="$(stat -c '%U:%G:%a' -- "$destination")"

    [[ "$actual" == "${owner}:${group}:${mode}" ]] ||
        die "Unexpected file metadata: $destination ($actual)"
}

# Create a directory only when absent. Existing directories are never chmod/chown'ed.
ensure_directory() {
    local path="$1"
    local owner="$2"
    local group="$3"
    local mode="$4"
    shift 4

    if [[ -e "$path" ]]; then
        check_directory_state "$path" "$owner" "$group" "$@"
        return 0
    fi

    log "Creating directory: $path"
    install -d -o "$owner" -g "$group" -m "$mode" -- "$path"
}

# Install a file only when absent. Existing files must be identical and correctly owned.
install_file_safely() {
    local source="$1"
    local destination="$2"
    local owner="$3"
    local group="$4"
    local mode="$5"

    if [[ -L "$destination" ]]; then
        die "Refusing symlink destination: $destination"
    fi

    if [[ -e "$destination" ]]; then
        check_file_state "$source" "$destination" "$owner" "$group" "$mode"
        log "Already installed and identical: $destination"
        return 0
    fi

    log "Installing: $destination"
    install -o "$owner" -g "$group" -m "$mode" -- "$source" "$destination"
}

# ============================================================
# 1. Validate execution context and required tools
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    die "Run using sudo from your normal WSL user."
fi

if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == "root" ]]; then
    die "Do not execute from a root login. Use sudo from your normal user."
fi

for cmd in \
    getent install useradd groupadd runuser systemctl \
    readlink dirname grep cmp stat id cut ss
do
    require_command "$cmd"
done

USER_ENTRY="$(getent passwd "$SUDO_USER")" ||
    die "Invoking user does not exist."

USER_HOME="$(printf '%s\n' "$USER_ENTRY" | cut -d: -f6)"

[[ -n "$USER_HOME" && -d "$USER_HOME" ]] ||
    die "Invalid home directory for $SUDO_USER."

readonly USER_HOME
readonly SOURCE_DIR="${USER_HOME}/${HM_CONFIG_REL}"

readonly POSTGRES_CONF="${SOURCE_DIR}/postgresql.conf"
readonly HBA_CONF="${SOURCE_DIR}/pg_hba.conf"
readonly SERVICE_FILE="${SOURCE_DIR}/postgresql.service"

log "Invoking user: $SUDO_USER"
log "Home directory: $USER_HOME"

# ============================================================
# 2. Validate Home Manager artifacts
# ============================================================

for file in "$POSTGRES_CONF" "$HBA_CONF" "$SERVICE_FILE"; do
    [[ -f "$file" && -r "$file" ]] ||
        die "Missing or unreadable artifact: $file. Run home-manager switch first."
done

log "Home Manager artifacts found."

# ============================================================
# 3. Validate PostgreSQL binaries and service definition
# ============================================================

readonly PG_POSTGRES="${USER_HOME}/.nix-profile/bin/postgres"

[[ -x "$PG_POSTGRES" ]] ||
    die "PostgreSQL binary not found or not executable: $PG_POSTGRES"

PG_BINARY="$(readlink -f -- "$PG_POSTGRES")"
PG_BIN="$(dirname -- "$PG_BINARY")"
readonly PG_BINARY PG_BIN

case "$PG_BINARY" in
    /nix/store/*/bin/postgres) ;;
    *)
        die "PostgreSQL binary must resolve inside /nix/store; found: $PG_BINARY"
        ;;
esac

[[ -x "${PG_BIN}/postgres" ]] || die "Invalid PostgreSQL server binary."
[[ -x "${PG_BIN}/initdb" ]] || die "initdb not found."
[[ -x "${PG_BIN}/pg_ctl" ]] || die "pg_ctl not found."

PG_VERSION_OUTPUT="$("${PG_BIN}/postgres" --version)"

case "$PG_VERSION_OUTPUT" in
    *" ${EXPECTED_PG_RELEASE}") ;;
    *)
        die "Expected PostgreSQL ${EXPECTED_PG_RELEASE}; found: $PG_VERSION_OUTPUT"
        ;;
esac

EXPECTED_EXECSTART="ExecStart=${PG_BINARY} -D ${DATA_DIR} -c config_file=${CONFIG_DIR}/postgresql.conf -c hba_file=${CONFIG_DIR}/pg_hba.conf"

grep -Fqx -- "$EXPECTED_EXECSTART" "$SERVICE_FILE" ||
    die "Unexpected ExecStart in systemd unit."

grep -Fqx -- "User=postgres" "$SERVICE_FILE" ||
    die "Systemd unit must specify User=postgres."

grep -Fqx -- "Group=postgres" "$SERVICE_FILE" ||
    die "Systemd unit must specify Group=postgres."

grep -Fqx -- "RuntimeDirectory=postgresql" "$SERVICE_FILE" ||
    die "Systemd unit must define RuntimeDirectory=postgresql."

log "PostgreSQL binary: $PG_BINARY"
log "PostgreSQL version: $PG_VERSION_OUTPUT"

# ============================================================
# 4. Preflight: service, ports, account, directories, files
#    No system changes are made in this section.
# ============================================================

if systemctl is-active --quiet "$SERVICE_NAME"; then
    die "$SERVICE_NAME is already active. Inspect it first."
fi

# Refuse a masked unit, and refuse a different unit loaded from elsewhere.
UNIT_ENABLED_STATE="$(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || true)"
case "$UNIT_ENABLED_STATE" in
    masked|masked-runtime)
        die "$SERVICE_NAME is masked. Unmask/review it manually first."
        ;;
esac

UNIT_FRAGMENT="$(systemctl show -p FragmentPath --value "$SERVICE_NAME" 2>/dev/null || true)"
if [[ -n "$UNIT_FRAGMENT" && "$UNIT_FRAGMENT" != "$SERVICE_PATH" ]]; then
    die "A different $SERVICE_NAME already exists at $UNIT_FRAGMENT."
fi

# Check TCP port 5432 before any provisioning.
if ss -H -ltn 'sport = :5432' | grep -q .; then
    die "TCP port 5432 is already occupied."
fi

# Refuse an existing PostgreSQL Unix socket path. Do not remove stale sockets automatically.
if [[ -e /run/postgresql/.s.PGSQL.5432 || -L /run/postgresql/.s.PGSQL.5432 ]]; then
    die "PostgreSQL Unix socket path already exists: /run/postgresql/.s.PGSQL.5432"
fi

# Validate existing postgres group/account as a pair.
GROUP_ENTRY="$(getent group postgres || true)"
USER_ENTRY_POSTGRES="$(getent passwd postgres || true)"

if [[ -n "$GROUP_ENTRY" && -z "$USER_ENTRY_POSTGRES" ]]; then
    GROUP_GID="$(printf '%s\n' "$GROUP_ENTRY" | cut -d: -f3)"
    [[ "$GROUP_GID" =~ ^[0-9]+$ && "$GROUP_GID" -lt 1000 ]] ||
        die "Existing postgres group is not a conventional system group (GID $GROUP_GID)."
fi

if [[ -z "$GROUP_ENTRY" && -n "$USER_ENTRY_POSTGRES" ]]; then
    die "A postgres user exists without a postgres group. Manual review required."
fi

if [[ -n "$GROUP_ENTRY" && -n "$USER_ENTRY_POSTGRES" ]]; then
    GROUP_GID="$(printf '%s\n' "$GROUP_ENTRY" | cut -d: -f3)"
    USER_UID="$(printf '%s\n' "$USER_ENTRY_POSTGRES" | cut -d: -f3)"
    USER_GID="$(printf '%s\n' "$USER_ENTRY_POSTGRES" | cut -d: -f4)"
    USER_HOME_EXISTING="$(printf '%s\n' "$USER_ENTRY_POSTGRES" | cut -d: -f6)"
    USER_SHELL="$(printf '%s\n' "$USER_ENTRY_POSTGRES" | cut -d: -f7)"

    [[ "$GROUP_GID" =~ ^[0-9]+$ && "$GROUP_GID" -lt 1000 ]] ||
        die "Existing postgres group is not a conventional system group."

    [[ "$USER_UID" =~ ^[0-9]+$ && "$USER_UID" -lt 1000 ]] ||
        die "Existing postgres user is not a conventional system account."

    [[ "$USER_GID" == "$GROUP_GID" ]] ||
        die "Existing postgres user has an unexpected primary group."

    [[ "$USER_HOME_EXISTING" == "$PG_ROOT" ]] ||
        die "Existing postgres user has unexpected home directory: $USER_HOME_EXISTING"

    [[ "$USER_SHELL" == "/usr/sbin/nologin" ]] ||
        die "Existing postgres user has unexpected shell: $USER_SHELL"
fi

# Validate all existing directory metadata before creating anything.
check_directory_state "$PG_ROOT" postgres postgres 750 755
check_directory_state "$DATA_PARENT" postgres postgres 750 755
check_directory_state "$DATA_DIR" postgres postgres 700

check_directory_state "$ETC_PG_ROOT" root root 755
check_directory_state "$ETC_PG_VERSION" root root 755
check_directory_state "$CONFIG_DIR" root postgres 750

# Validate configuration/service file contents AND metadata before creating anything.
check_file_state "$POSTGRES_CONF" "${CONFIG_DIR}/postgresql.conf" root postgres 640
check_file_state "$HBA_CONF" "${CONFIG_DIR}/pg_hba.conf" root postgres 640
check_file_state "$SERVICE_FILE" "$SERVICE_PATH" root root 644

# Inspect existing cluster. Never initialize over non-empty unknown data.
CLUSTER_EXISTS="no"

if [[ -L "${DATA_DIR}/PG_VERSION" ]]; then
    die "Refusing symlink PG_VERSION."
fi

if [[ -e "${DATA_DIR}/PG_VERSION" ]]; then
    [[ -f "${DATA_DIR}/PG_VERSION" ]] ||
        die "PG_VERSION is not a regular file."

    EXISTING_VERSION="$(<"${DATA_DIR}/PG_VERSION")"
    [[ "$EXISTING_VERSION" == "$PG_VERSION" ]] ||
        die "Existing cluster version is $EXISTING_VERSION; expected $PG_VERSION."

    CLUSTER_EXISTS="yes"
elif [[ -d "$DATA_DIR" ]]; then
    shopt -s nullglob dotglob
    existing_entries=("${DATA_DIR}"/*)
    shopt -u nullglob dotglob

    (( ${#existing_entries[@]} == 0 )) ||
        die "Data directory is non-empty without PG_VERSION. Manual inspection required."
fi

log "All preflight checks passed."
log "Existing cluster: $CLUSTER_EXISTS"

# ============================================================
# 5. Create or validate Linux postgres account/group
# ============================================================

if [[ -z "$GROUP_ENTRY" ]]; then
    log "Creating system group postgres."
    groupadd --system postgres
fi

POSTGRES_GROUP_GID="$(getent group postgres | cut -d: -f3)"

if [[ -z "$USER_ENTRY_POSTGRES" ]]; then
    log "Creating system user postgres."
    useradd \
        --system \
        --gid "$POSTGRES_GROUP_GID" \
        --home-dir "$PG_ROOT" \
        --no-create-home \
        --shell /usr/sbin/nologin \
        postgres
else
    log "Existing postgres user/group validated."
fi

# ============================================================
# 6. Create required directories
# ============================================================

ensure_directory "$PG_ROOT" postgres postgres 0750 750 755
ensure_directory "$DATA_PARENT" postgres postgres 0750 750 755
ensure_directory "$DATA_DIR" postgres postgres 0700 700

ensure_directory "$ETC_PG_ROOT" root root 0755 755
ensure_directory "$ETC_PG_VERSION" root root 0755 755
ensure_directory "$CONFIG_DIR" root postgres 0750 750

# ============================================================
# 7. Install PostgreSQL configuration
# ============================================================

install_file_safely \
    "$POSTGRES_CONF" \
    "${CONFIG_DIR}/postgresql.conf" \
    root postgres 0640

install_file_safely \
    "$HBA_CONF" \
    "${CONFIG_DIR}/pg_hba.conf" \
    root postgres 0640

# ============================================================
# 8. Initialize cluster only if it does not exist
# ============================================================

if [[ "$CLUSTER_EXISTS" == "yes" ]]; then
    log "Existing PostgreSQL ${PG_VERSION} cluster detected."
    log "Skipping initdb."
else
    runuser -u postgres -- test -x "$DATA_PARENT" ||
        die "postgres cannot traverse $DATA_PARENT."

    runuser -u postgres -- test -w "$DATA_DIR" ||
        die "postgres cannot write to $DATA_DIR."

    log "Initializing PostgreSQL cluster."
    log "Encoding: UTF8"
    log "Locale provider: ICU"
    log "ICU locale: en-ID"

    runuser -u postgres -- "${PG_BIN}/initdb" \
        --pgdata="$DATA_DIR" \
        --username=postgres \
        --encoding=UTF8 \
        --locale-provider=icu \
        --icu-locale=en-ID \
        --auth-local=peer \
        --auth-host=scram-sha-256

    [[ -f "${DATA_DIR}/PG_VERSION" ]] ||
        die "initdb did not create PG_VERSION."

    INITIALIZED_VERSION="$(<"${DATA_DIR}/PG_VERSION")"
    [[ "$INITIALIZED_VERSION" == "$PG_VERSION" ]] ||
        die "Unexpected initialized cluster version: $INITIALIZED_VERSION."

    log "Cluster initialization completed."
fi

# ============================================================
# 9. Install systemd unit and enable (do not start)
# ============================================================

install_file_safely \
    "$SERVICE_FILE" \
    "$SERVICE_PATH" \
    root root 0644

systemctl daemon-reload

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    log "$SERVICE_NAME is already enabled."
else
    log "Enabling $SERVICE_NAME."
    systemctl enable "$SERVICE_NAME"
fi

# ============================================================
# 10. Final status
# ============================================================

printf '\n'
printf '%s\n' "PostgreSQL provisioning completed."
printf '  Binary       : %s\n' "$PG_BINARY"
printf '  Version      : %s\n' "$PG_VERSION_OUTPUT"
printf '  Data         : %s\n' "$DATA_DIR"
printf '  Configuration: %s\n' "$CONFIG_DIR"
printf '  Service      : %s\n' "$SERVICE_NAME"
printf '  Locale       : UTF8 / ICU en-ID\n'
printf '  Enabled      : yes\n'
printf '  Started      : no\n'
printf '\n'

warn "PostgreSQL service has NOT been started."
warn "Review the cluster and configuration before starting it."
warn "If initdb fails after creating partial files, inspect the data directory manually; this script will not delete it."
