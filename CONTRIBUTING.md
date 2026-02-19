# Contributing

## Scope

This repository currently prioritizes manual, explicit build/install workflows over automation.

## Development Guidelines

- Keep changes minimal and distro-specific when required.
- Preserve parity between `alma10.1/` and `ubuntu24.04/` unless a distro difference is intentional.
- Document every behavior change in the relevant README.

## Shell Script Standards

- Use `bash` with `set -euo pipefail`.
- Quote variable expansions.
- Resolve paths relative to script location where file coupling exists.
- Avoid assumptions that fail on minimal installations.

## Validation Before PR

- Lint changed scripts with `shellcheck`.
- Run build + installer + verify manually for affected distro track.
- Confirm `installer/verify.sh` exits non-zero when dependencies are missing.
