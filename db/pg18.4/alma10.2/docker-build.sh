#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line ${LINENO}" >&2' ERR

# Docker-based builder for the IMMER PostgreSQL 18.4 + TimescaleDB + pgvector artifact.
#
# Intended for CI / dedicated builder hosts. The builder container runs as root and
# installs into the real ${PREFIX} inside the throwaway container, then packages a
# relocatable tarball into ${OUT_DIR}.

IMAGE_NAME="${IMAGE_NAME:-immer/pg18-builder:alma10.2}"
OUT_DIR="${OUT_DIR:-./out}"
# SELinux relabel for the bind mount; set empty ("") on non-SELinux hosts.
DOCKER_VOLUME_LABEL="${DOCKER_VOLUME_LABEL:-:Z}"
# x86-64-v2 tuning is applied via CFLAGS in build.sh; the platform stays base amd64.
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
mkdir -p "${OUT_DIR}"
IMAGE_ID_FILE="${OUT_DIR}/.builder-image-id"

if [[ ! -w "${OUT_DIR}" ]]; then
  echo "ERROR: OUT_DIR is not writable: ${OUT_DIR}" >&2
  exit 1
fi

echo "[1/3] Build builder image: ${IMAGE_NAME}"
docker build --platform "${DOCKER_PLATFORM}" --iidfile "${IMAGE_ID_FILE}" -t "${IMAGE_NAME}" -f Dockerfile .
IMAGE_REF="$(cat "${IMAGE_ID_FILE}")"
if [[ -z "${IMAGE_REF}" ]]; then
  echo "ERROR: failed to capture built image ID" >&2
  exit 1
fi

echo "[2/3] Run builder container (outputs -> ${OUT_DIR})"
docker run --rm \
  --platform "${DOCKER_PLATFORM}" \
  -v "${OUT_DIR}:/out${DOCKER_VOLUME_LABEL}" \
  -e PG_TAG="${PG_TAG:-REL_18_4}" \
  -e BRANCH_NAME="${BRANCH_NAME:-immer/pg18-202607}" \
  -e PREFIX="${PREFIX:-/opt/pgsql/18.4}" \
  -e INSTALL_TIMESCALEDB="${INSTALL_TIMESCALEDB:-1}" \
  -e TS_VERSION="${TS_VERSION:-2.28.2}" \
  -e INSTALL_PGVECTOR="${INSTALL_PGVECTOR:-1}" \
  -e PGVECTOR_VERSION="${PGVECTOR_VERSION:-v0.8.4}" \
  -e RUN_TESTS="${RUN_TESTS:-0}" \
  -e RUN_CHECK_WORLD="${RUN_CHECK_WORLD:-0}" \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  "${IMAGE_REF}"

echo "[3/3] Done. Artifacts in ${OUT_DIR}:"
ls -lah "${OUT_DIR}"
