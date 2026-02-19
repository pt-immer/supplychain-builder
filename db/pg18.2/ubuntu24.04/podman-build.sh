#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line ${LINENO}" >&2' ERR

IMAGE_NAME="${IMAGE_NAME:-immer/pg18-builder:ubuntu24.04}"
OUT_DIR="${OUT_DIR:-./out}"
PODMAN_VOLUME_LABEL="${PODMAN_VOLUME_LABEL:-:Z,U}"
PODMAN_PLATFORM="${PODMAN_PLATFORM:-linux/amd64/v2}"
mkdir -p "${OUT_DIR}"
IMAGE_ID_FILE="${OUT_DIR}/.builder-image-id"

if [[ ! -w "${OUT_DIR}" ]]; then
  echo "[preflight] OUT_DIR is not writable, attempting ownership repair via podman unshare..."
  podman unshare chown -R "$(id -u):$(id -g)" "${OUT_DIR}" || true
fi

if [[ ! -w "${OUT_DIR}" ]]; then
  echo "ERROR: OUT_DIR is not writable: ${OUT_DIR}" >&2
  exit 1
fi

echo "[1/3] Build builder image: ${IMAGE_NAME}"
podman build --platform "${PODMAN_PLATFORM}" --iidfile "${IMAGE_ID_FILE}" -t "${IMAGE_NAME}" -f Containerfile .
IMAGE_REF="$(cat "${IMAGE_ID_FILE}")"
if [[ -z "${IMAGE_REF}" ]]; then
  echo "ERROR: failed to capture built image ID" >&2
  exit 1
fi

echo "[2/3] Run builder container (outputs -> ${OUT_DIR})"
podman run --rm \
  --platform "${PODMAN_PLATFORM}" \
  --pull=never \
  --user "$(id -u):$(id -g)" \
  -v "${OUT_DIR}:/out${PODMAN_VOLUME_LABEL}" \
  -e PG_TAG="${PG_TAG:-REL_18_2}" \
  -e BRANCH_NAME="${BRANCH_NAME:-immer/pg18-202602}" \
  -e PREFIX="${PREFIX:-/opt/pgsql/18.2}" \
  -e INSTALL_TIMESCALEDB="${INSTALL_TIMESCALEDB:-1}" \
  -e TS_VERSION="${TS_VERSION:-2.25.1}" \
  -e RUN_TESTS="${RUN_TESTS:-0}" \
  -e RUN_CHECK_WORLD="${RUN_CHECK_WORLD:-0}" \
  "${IMAGE_REF}"

echo "[3/3] Done. Artifacts in ${OUT_DIR}:"
ls -lah "${OUT_DIR}"
