#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line ${LINENO}" >&2' ERR

# Builds PostgreSQL 18.4 (+ TimescaleDB + pgvector) with clang/ThinLTO tuned for
# x86-64-v2 and packages the result as a relocatable /opt tarball.
#
# The script installs into the REAL ${PREFIX} (e.g. /opt/pgsql/18.4) so that
# pg_config reports resolvable paths and the extensions compile against the
# freshly built server. Run it where ${PREFIX}'s parent is writable:
#   - docker builder container: runs as root, /opt is writable (see docker-build.sh)
#   - native build: pre-create a writable parent, e.g.
#       sudo install -d -o "$USER" -g "$USER" /opt/pgsql
# The running system PostgreSQL is unaffected as long as ${PREFIX} is a fresh path.

OUT_DIR="${OUT_DIR:-/out}"
WORK_DIR="${WORK_DIR:-/work}"

REPO_DIR="${REPO_DIR:-pg18}"
PG_TAG="${PG_TAG:-REL_18_4}"
BRANCH_NAME="${BRANCH_NAME:-immer/pg18-202607}"
PREFIX="${PREFIX:-/opt/pgsql/18.4}"

INSTALL_TIMESCALEDB="${INSTALL_TIMESCALEDB:-1}"
TS_VERSION="${TS_VERSION:-2.28.2}"
TS_DIR="${TS_DIR:-timescaledb}"

INSTALL_PGVECTOR="${INSTALL_PGVECTOR:-1}"
PGVECTOR_VERSION="${PGVECTOR_VERSION:-v0.8.4}"
PGVECTOR_DIR="${PGVECTOR_DIR:-pgvector}"

RUN_TESTS="${RUN_TESTS:-0}"
RUN_CHECK_WORLD="${RUN_CHECK_WORLD:-0}"

mkdir -p "${OUT_DIR}" "${WORK_DIR}"
cd "${WORK_DIR}"

echo "[1/8] Toolchain (clang+lld) + ThinLTO flags..."
export CC="clang"
export CXX="clang++"
export AR="llvm-ar"
export NM="llvm-nm"
export RANLIB="llvm-ranlib"

export CFLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
export CXXFLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
export LDFLAGS="-flto=thin -fuse-ld=lld"

echo "[2/8] Clone PostgreSQL tag ${PG_TAG}..."
rm -rf "${REPO_DIR}" "${TS_DIR}" "${PGVECTOR_DIR}" || true
git clone --branch "${PG_TAG}" --recurse-submodules https://github.com/postgres/postgres.git "${REPO_DIR}"
cd "${REPO_DIR}"

echo "[3/8] Create local branch ${BRANCH_NAME} and set extra-version..."
git checkout -B "${BRANCH_NAME}"
BRANCH="$(git branch --show-current)"
SAFE_BRANCH="${BRANCH//\//-}"
EXTRA_VERSION="-${SAFE_BRANCH}"

echo "[4/8] Configure PostgreSQL (prefix=${PREFIX})..."
make distclean >/dev/null 2>&1 || true

./configure \
  --prefix="${PREFIX}" \
  --with-extra-version="${EXTRA_VERSION}" \
  --with-ssl=openssl \
  --with-llvm \
  --with-icu \
  --with-gssapi \
  --with-ldap \
  --with-pam \
  --with-libcurl \
  --with-uuid=e2fs \
  --with-libnuma \
  --with-selinux \
  --with-systemd \
  --with-liburing \
  --with-lz4 \
  --with-zstd \
  --with-libxml \
  --with-libxslt

echo "[5/8] Build PostgreSQL (world-bin)..."
make -j"$(nproc)" world-bin

if [[ "${RUN_TESTS}" == "1" ]]; then
  if [[ "${RUN_CHECK_WORLD}" == "1" ]]; then
    echo "[5.1/8] Tests: make check-world..."
    make -j"$(nproc)" check-world
  else
    echo "[5.1/8] Tests: make check..."
    make -j"$(nproc)" check
  fi
else
  echo "[5.1/8] Tests: skipped (RUN_TESTS=0)"
fi

echo "[6/8] Install PostgreSQL into ${PREFIX}..."
make install-world-bin

mkdir -p "${OUT_DIR}/meta"
"${PREFIX}/bin/postgres" --version | tee "${OUT_DIR}/meta/postgres.version.txt"
"${PREFIX}/bin/pg_config" --configure | tee "${OUT_DIR}/meta/pg_config.configure.txt"

# Extensions build against the freshly installed server.
export PG_CONFIG="${PREFIX}/bin/pg_config"
export PATH="${PREFIX}/bin:${PATH}"

if [[ "${INSTALL_TIMESCALEDB}" == "1" ]]; then
  echo "[7/8] Clone + build TimescaleDB ${TS_VERSION} (Thin LTO, IPO OFF)..."
  cd "${WORK_DIR}"
  git clone --branch "${TS_VERSION}" --recurse-submodules https://github.com/timescale/timescaledb.git "${TS_DIR}"
  cd "${TS_DIR}"

  CMAKE_C_FLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
  CMAKE_CXX_FLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
  CMAKE_LINK_FLAGS="-flto=thin -fuse-ld=lld"

  ./bootstrap \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_C_COMPILER=clang \
    -D CMAKE_CXX_COMPILER=clang++ \
    -D CMAKE_AR="$(which llvm-ar)" \
    -D CMAKE_RANLIB="$(which llvm-ranlib)" \
    -D CMAKE_NM="$(which llvm-nm)" \
    -D CMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -D CMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
    -D CMAKE_EXE_LINKER_FLAGS="${CMAKE_LINK_FLAGS}" \
    -D CMAKE_SHARED_LINKER_FLAGS="${CMAKE_LINK_FLAGS}" \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -D REGRESS_CHECKS=OFF \
    -D TAP_CHECKS=OFF \
    -D CMAKE_INSTALL_LIBDIR=lib

  cd build
  make -j"$(nproc)"
  make install
else
  echo "[7/8] TimescaleDB: skipped (INSTALL_TIMESCALEDB=0)"
fi

if [[ "${INSTALL_PGVECTOR}" == "1" ]]; then
  echo "[7.1/8] Clone + build pgvector ${PGVECTOR_VERSION} (clang, x86-64-v2)..."
  cd "${WORK_DIR}"
  git clone --branch "${PGVECTOR_VERSION}" --depth 1 https://github.com/pgvector/pgvector.git "${PGVECTOR_DIR}"
  cd "${PGVECTOR_DIR}"
  # pgvector defaults OPTFLAGS to -march=native; override for a portable x86-64-v2 build.
  make clean >/dev/null 2>&1 || true
  make -j"$(nproc)" CC=clang OPTFLAGS="-O3 -march=x86-64-v2" PG_CONFIG="${PG_CONFIG}"
  make install PG_CONFIG="${PG_CONFIG}"
else
  echo "[7.1/8] pgvector: skipped (INSTALL_PGVECTOR=0)"
fi

echo "[8/8] Package ${PREFIX} tree into .tgz (extract at / to land in ${PREFIX})..."
REL_PREFIX="${PREFIX#/}"
PG_MINOR="$(basename "${PREFIX}")"
ART_NAME="opt-pgsql-${PG_MINOR}-${SAFE_BRANCH}-${PG_TAG}.tgz"
tar -C / -czf "${OUT_DIR}/${ART_NAME}" "${REL_PREFIX}"

# When built as root in a container, hand outputs back to the invoking host user.
if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
  chown -R "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" || true
fi

echo "OK: wrote ${OUT_DIR}/${ART_NAME}"
echo "Also wrote build metadata under ${OUT_DIR}/meta/"
