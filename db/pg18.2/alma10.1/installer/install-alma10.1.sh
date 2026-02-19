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

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: run as root."
  exit 1
fi

if [[ -z "${ARCHIVE}" ]]; then
  ARCHIVE="$(find . -maxdepth 1 -type f -name 'opt-pgsql-18.2-*.tgz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')"
  if [[ -z "${ARCHIVE}" ]]; then
    ARCHIVE="$(find "${SCRIPT_DIR}" -maxdepth 1 -type f -name 'opt-pgsql-18.2-*.tgz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')"
  fi
fi
if [[ -z "${ARCHIVE}" || ! -f "${ARCHIVE}" ]]; then
  echo "ERROR: cannot find artifact tgz. Set ARCHIVE=/path/to/opt-pgsql-18.2-*.tgz"
  exit 1
fi

echo "[1/9] Install runtime dependencies (AlmaLinux 10.1)..."
dnf -y install \
  ca-certificates \
  openssl-libs \
  llvm-libs \
  libicu \
  readline \
  zlib \
  libxml2 \
  libxslt \
  lz4-libs \
  zstd \
  libcurl \
  openldap \
  krb5-libs \
  numactl-libs \
  pam \
  libselinux \
  systemd-libs \
  liburing \
  libuuid \
  util-linux

echo "[2/9] Ensure postgres user/group exists..."
getent group postgres >/dev/null || groupadd -r postgres
id postgres >/dev/null 2>&1 || useradd -r -g postgres -d /var/lib/postgresql -m -s /sbin/nologin postgres

echo "[3/9] Extract binaries into /opt (from: ${ARCHIVE})..."
mkdir -p /opt
tar -xzf "${ARCHIVE}" -C /

if [[ ! -x "${PREFIX}/bin/postgres" ]]; then
  echo "ERROR: ${PREFIX}/bin/postgres not found after extraction."
  exit 1
fi

echo "[4/9] Ensure dynamic linker can find ${PREFIX}/lib (ldconfig)..."
cat > /etc/ld.so.conf.d/pgsql-18.2.conf <<EOF
${PREFIX}/lib
EOF
ldconfig

echo "[5/9] Install PATH helper..."
mkdir -p "${PROFILED_DIR}"
cat > "${PROFILED_DIR}/pgsql-18.2.sh" <<'EOF'
export PATH="/opt/pgsql/18.2/bin:${PATH}"
EOF
chmod 0644 "${PROFILED_DIR}/pgsql-18.2.sh"

echo "[6/9] Create data + config directories..."
mkdir -p "$(dirname "${PGDATA}")" "${PGDATA}" "${ETC_DIR}"
chown postgres:postgres "$(dirname "${PGDATA}")"
chown -R postgres:postgres "${PGDATA}" "${ETC_DIR}"
chmod 0700 "${PGDATA}"

echo "[7/9] Initialize cluster if empty..."
if [[ ! -f "${PGDATA}/PG_VERSION" ]]; then
  runuser -u postgres -- "${PREFIX}/bin/initdb" \
    --pgdata="${PGDATA}" \
    --auth-local=peer \
    --auth-host=scram-sha-256
fi

echo "[8/9] Move configs to ${ETC_DIR} and symlink back into PGDATA..."
for f in postgresql.conf pg_hba.conf pg_ident.conf; do
  if [[ -f "${PGDATA}/${f}" && ! -L "${PGDATA}/${f}" ]]; then
    mv -f "${PGDATA}/${f}" "${ETC_DIR}/${f}"
    ln -sf "${ETC_DIR}/${f}" "${PGDATA}/${f}"
  fi
done
chown -R postgres:postgres "${ETC_DIR}"

echo "[9/9] Install and enable systemd service..."
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
