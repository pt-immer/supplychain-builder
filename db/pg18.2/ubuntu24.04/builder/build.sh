#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line ${LINENO}" >&2' ERR

OUT_DIR="${OUT_DIR:-/out}"
STAGE_DIR="${STAGE_DIR:-/work/stage}"

REPO_DIR="${REPO_DIR:-pg18}"
PG_TAG="${PG_TAG:-REL_18_2}"
BRANCH_NAME="${BRANCH_NAME:-immer/pg18-202602}"
PREFIX="${PREFIX:-/opt/pgsql/18.2}"

INSTALL_TIMESCALEDB="${INSTALL_TIMESCALEDB:-1}"
TS_VERSION="${TS_VERSION:-2.25.1}"
TS_DIR="${TS_DIR:-timescaledb}"

RUN_TESTS="${RUN_TESTS:-0}"
RUN_CHECK_WORLD="${RUN_CHECK_WORLD:-0}"

mkdir -p "${OUT_DIR}" "${STAGE_DIR}"

echo "[1/7] Toolchain (clang+lld) + ThinLTO flags..."
export CC="clang"
export CXX="clang++"
export AR="llvm-ar"
export NM="llvm-nm"
export RANLIB="llvm-ranlib"

export CFLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
export CXXFLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
export LDFLAGS="-flto=thin -fuse-ld=lld"

echo "[2/7] Clone PostgreSQL tag ${PG_TAG} into ./${REPO_DIR}..."
rm -rf "${REPO_DIR}" "${TS_DIR}" || true
git clone --branch "${PG_TAG}" --recurse-submodules https://github.com/postgres/postgres.git "${REPO_DIR}"
cd "${REPO_DIR}"

echo "[3/7] Create local branch ${BRANCH_NAME} and set extra-version..."
git checkout -B "${BRANCH_NAME}"
BRANCH="$(git branch --show-current)"
SAFE_BRANCH="${BRANCH//\//-}"
EXTRA_VERSION="-${SAFE_BRANCH}"

echo "[4/7] Configure PostgreSQL..."
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

echo "[5/7] Build PostgreSQL (world-bin)..."
make -j"$(nproc)" world-bin

if [[ "${RUN_TESTS}" == "1" ]]; then
  if [[ "${RUN_CHECK_WORLD}" == "1" ]]; then
    echo "[5.1/7] Tests: make check-world..."
    make -j"$(nproc)" check-world
  else
    echo "[5.1/7] Tests: make check..."
    make -j"$(nproc)" check
  fi
else
  echo "[5.1/7] Tests: skipped (RUN_TESTS=0)"
fi

echo "[6/7] Stage install PostgreSQL into ${STAGE_DIR} (DESTDIR)..."
rm -rf "${STAGE_DIR:?}/opt" || true
make install-world-bin DESTDIR="${STAGE_DIR}"

mkdir -p "${OUT_DIR}/meta"
"${STAGE_DIR}${PREFIX}/bin/postgres" --version | tee "${OUT_DIR}/meta/postgres.version.txt"
"${STAGE_DIR}${PREFIX}/bin/pg_config" --configure | tee "${OUT_DIR}/meta/pg_config.configure.txt"

if [[ "${INSTALL_TIMESCALEDB}" == "1" ]]; then
  echo "[6.1/7] Clone TimescaleDB ${TS_VERSION}..."
  cd /work
  git clone --branch "${TS_VERSION}" --recurse-submodules https://github.com/timescale/timescaledb.git "${TS_DIR}"
  cd "${TS_DIR}"

  echo "[6.2/7] Build TimescaleDB (Thin LTO, IPO OFF)..."
  export PG_CONFIG="${STAGE_DIR}${PREFIX}/bin/pg_config"
  export PATH="${STAGE_DIR}${PREFIX}/bin:${PATH}"

  CMAKE_C_FLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
  CMAKE_CXX_FLAGS="-O3 -g -fno-omit-frame-pointer -march=x86-64-v2 -flto=thin"
  CMAKE_LINK_FLAGS="-flto=thin -fuse-ld=lld"

  ./bootstrap \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_LINK_FLAGS}" \
    -DCMAKE_SHARED_LINKER_FLAGS="${CMAKE_LINK_FLAGS}" \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    -DREGRESS_CHECKS=OFF \
    -DTAP_CHECKS=OFF

  cd build
  make -j"$(nproc)"
  make install DESTDIR="${STAGE_DIR}"
else
  echo "[6.1/7] TimescaleDB: skipped (INSTALL_TIMESCALEDB=0)"
fi

echo "[7/7] Package /opt tree into .tgz (extract at / to land in /opt/pgsql/18.2)..."
ART_NAME="opt-pgsql-18.2-${SAFE_BRANCH}-${PG_TAG}.tgz"
tar -C "${STAGE_DIR}" -czf "${OUT_DIR}/${ART_NAME}" "opt/pgsql/18.2"

echo "OK: wrote ${OUT_DIR}/${ART_NAME}"
echo "Also wrote build metadata under ${OUT_DIR}/meta/"
