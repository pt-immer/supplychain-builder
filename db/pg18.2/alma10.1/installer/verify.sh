#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-/opt/pgsql/18.2}"

if [[ ! -x "${PREFIX}/bin/postgres" ]]; then
  echo "ERROR: ${PREFIX}/bin/postgres not found or not executable." >&2
  exit 1
fi

echo "postgres: $("${PREFIX}/bin/postgres" --version)"
echo
check_targets=(
  "${PREFIX}/bin/postgres"
  "${PREFIX}/lib/postgresql/llvmjit.so"
  "${PREFIX}/lib/postgresql/timescaledb.so"
)

echo "Missing libs (should be empty):"
missing_count=0
for target in "${check_targets[@]}"; do
  if [[ -f "${target}" ]]; then
    target_missing="$(ldd "${target}" | awk '/not found/ {print}')"
    if [[ -n "${target_missing}" ]]; then
      echo "[${target}]"
      echo "${target_missing}"
      missing_count=$((missing_count + 1))
    fi
  fi
done

if [[ "${missing_count}" -gt 0 ]]; then
  echo "ERROR: missing shared libraries detected." >&2
  exit 1
fi
