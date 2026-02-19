#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line ${LINENO}" >&2' ERR

PREFIX="${PREFIX:-/opt/pgsql/18.2}"
PGDATA="${PGDATA:-/var/lib/pgsql/18/data}"
ETC_DIR="${ETC_DIR:-/etc/pgsql/18}"
PROFILED_DIR="${PROFILED_DIR:-/etc/profile.d}"
SERVICE_NAME="${SERVICE_NAME:-postgresql18-immer.service}"
ARCHIVE="${ARCHIVE:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pick_archive() {
  local -a candidates=()
  mapfile -t candidates < <(
    {
      find . -maxdepth 1 -type f -name 'opt-pgsql-18.2-*.tgz' -printf '%T@ %p\n'
      find "${SCRIPT_DIR}" -maxdepth 1 -type f -name 'opt-pgsql-18.2-*.tgz' -printf '%T@ %p\n'
    } 2>/dev/null | sort -nr | awk '!seen[$2]++ {print $2}'
  )

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    return 1
  fi

  if [[ "${#candidates[@]}" -gt 1 ]]; then
    echo "WARN: multiple artifacts found; auto-selecting newest: ${candidates[0]}"
    echo "WARN: for reproducible installs, set ARCHIVE=/path/to/opt-pgsql-18.2-*.tgz"
  fi

  ARCHIVE="${candidates[0]}"
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run as root."
  exit 1
fi

if [[ -z "${ARCHIVE}" ]]; then
  pick_archive || true
fi
if [[ -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
  echo "ERROR: cannot find artifact tgz. Set ARCHIVE=/path/to/opt-pgsql-18.2-*.tgz"
  exit 1
fi

echo "[1/10] Validate artifact archive safety..."
if ! tar -tzf "${ARCHIVE}" >/dev/null 2>&1; then
  echo "ERROR: archive is unreadable or invalid: ${ARCHIVE}"
  exit 1
fi
if ! tar -tzf "${ARCHIVE}" | grep -E '^(\./)?opt/pgsql/18\.2(/|$)' > /dev/null; then
  echo "ERROR: archive does not contain expected opt/pgsql/18.2 payload: ${ARCHIVE}"
  exit 1
fi
unsafe_paths="$(tar -tzf "${ARCHIVE}" | awk '($0 ~ /^\//) || ($0 ~ /(^|\/)\.\.(\/|$)/) { print; found=1 } END { if (!found) exit 1 }' || true)"
if [[ -n "${unsafe_paths}" ]]; then
  echo "ERROR: archive contains unsafe paths; refusing extraction to /"
  echo "${unsafe_paths}" | head -n 10
  exit 1
fi

echo "[2/10] Install runtime dependencies (Ubuntu 24.04)..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  libllvm18 \
  libssl3 \
  libicu74 \
  libreadline8 \
  zlib1g \
  libxml2 \
  libxslt1.1 \
  liblz4-1 \
  libzstd1 \
  libcurl4 \
  libldap2 \
  libkrb5-3 \
  libnuma1 \
  libpam0g \
  libselinux1 \
  libsystemd0 \
  liburing2 \
  libuuid1 \
  util-linux \
  locales

echo "[3/10] Ensure postgres user/group exists..."
getent group postgres >/dev/null || groupadd --system postgres
id postgres >/dev/null 2>&1 || useradd --system --gid postgres --home-dir /var/lib/postgresql --create-home --shell /usr/sbin/nologin postgres

echo "[4/10] Extract binaries into /opt (from: ${ARCHIVE})..."
mkdir -p /opt
tar -xzf "${ARCHIVE}" -C /

if [[ ! -x "${PREFIX}/bin/postgres" ]]; then
  echo "ERROR: ${PREFIX}/bin/postgres not found after extraction."
  exit 1
fi

echo "[5/10] Ensure dynamic linker can find ${PREFIX}/lib (ldconfig)..."
cat > /etc/ld.so.conf.d/pgsql-18.2.conf <<EOF
${PREFIX}/lib
EOF
ldconfig

echo "[6/10] Install PATH helper..."
mkdir -p "${PROFILED_DIR}"
cat > "${PROFILED_DIR}/pgsql-18.2.sh" <<'EOF'
export PATH="/opt/pgsql/18.2/bin:${PATH}"
EOF
chmod 0644 "${PROFILED_DIR}/pgsql-18.2.sh"

echo "[7/10] Create data + config directories..."
mkdir -p "$(dirname "${PGDATA}")" "${PGDATA}" "${ETC_DIR}"
chown postgres:postgres "$(dirname "${PGDATA}")"
chown -R postgres:postgres "${PGDATA}" "${ETC_DIR}"
chmod 0700 "${PGDATA}"

echo "[8/10] Initialize cluster if empty..."
if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  runuser -u postgres -- "${PREFIX}/bin/initdb" \
    --pgdata="${PGDATA}" \
    --auth-local=peer \
    --auth-host=scram-sha-256
fi

echo "[9/10] Move configs to ${ETC_DIR} and symlink back into PGDATA..."
for f in postgresql.conf pg_hba.conf pg_ident.conf; do
  if [[ -f "${PGDATA}/${f}" && ! -L "${PGDATA}/${f}" ]]; then
    mv -f "${PGDATA}/${f}" "${ETC_DIR}/${f}"
    ln -sf "${ETC_DIR}/${f}" "${PGDATA}/${f}"
  fi
done
chown -R postgres:postgres "${ETC_DIR}"

echo "[10/10] Install and enable systemd service..."
if [[ ! -f "${SCRIPT_DIR}/${SERVICE_NAME}" ]]; then
  echo "ERROR: missing service unit at ${SCRIPT_DIR}/${SERVICE_NAME}"
  exit 1
fi
install -m 0644 "${SCRIPT_DIR}/${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

echo
echo "OK. Start with: systemctl start ${SERVICE_NAME}"
echo "Config dir: ${ETC_DIR}"
echo "Data dir: ${PGDATA}"
