# IMMER's PostgreSQL 18.2 (OLAP/OLGP)

Build and package PostgreSQL 18.2 (with optional TimescaleDB) in a Podman builder image, then install on AlmaLinux/RHEL 10.x targets.

## Module Layout

- `alma10.1/`: Build and installer flow for AlmaLinux/RHEL 10.x targets.

The track contains:

- `Containerfile`: builder image definition
- `builder/build.sh`: PostgreSQL and TimescaleDB build script
- `podman-build.sh`: local wrapper to build and run builder image
- `installer/install-*.sh`: target host installer
- `installer/verify.sh`: runtime linkage sanity check
- `installer/postgresql18-immer.service`: systemd service unit

## Supported Matrix

- Host (build): Linux with Podman
- Target (install): AlmaLinux/RHEL 10.x for `alma10.1`

Use the `alma10.1` builder and installer track for supported target OSes.

## Quick Start (Manual)

### 1) Build artifact

Example:

```bash
cd alma10.1
./podman-build.sh
```

Optional: override builder UID/user at image build time to match host policies:

```bash
cd alma10.1
podman build \
  --build-arg BUILDER_USER=builder \
  --build-arg BUILDER_UID=1000 \
  -t immer/pg18-builder:alma10.1 \
  -f Containerfile \
  .
```

Artifacts are written to `out/`:

- `opt-pgsql-18.2-<branch>-<tag>.tgz`
- `meta/postgres.version.txt`
- `meta/pg_config.configure.txt`

### 2) Install on target host

Copy the artifact and installer files from `installer/` to target host, then run:

```bash
chmod +x install-*.sh
ARCHIVE=./opt-pgsql-18.2-*.tgz ./install-*.sh
systemctl start postgresql18-immer.service
```

### 3) Verify runtime linkage

```bash
./verify.sh
```

`verify.sh` should print no missing shared libraries and exit `0`.
It checks runtime linkage for `postgres` and, when present, `llvmjit.so` and `timescaledb.so`.

## Podman SELinux / Non-SELinux

`podman-build.sh` supports configurable mount labeling via `PODMAN_VOLUME_LABEL`:

- Default (SELinux hosts): `:Z,U`
- Non-SELinux hosts: set it to an empty string

Examples:

```bash
./podman-build.sh
PODMAN_VOLUME_LABEL="" ./podman-build.sh
```

Mount format used by scripts:

```bash
-v "${OUT_DIR}:/out${PODMAN_VOLUME_LABEL}"
```

## Safety and Validation

- Run installers as `root` on target hosts.
- `INSTALL_TIMESCALEDB=0` is a troubleshooting build mode and is not intended for release artifacts.
- Use `shellcheck` on all shell scripts before merging changes.

## Licensing

- Repository files are licensed under MIT: see `../../LICENSE`.
- Built artifacts include third-party components under their upstream licenses.
- See `THIRD_PARTY_LICENSES.md` for dependency-chain licensing guidance.

## Release Compliance Checklist

Before publishing any binary artifact built with this repo:

1. Record exact component versions/tags from build metadata in `out/meta/`.
2. Collect upstream license/notice files for each included dependency version.
3. Collect PostgreSQL `COPYRIGHT` and related notices from the checked out tag.
4. Collect TimescaleDB license/notice files for the included modules and version.
5. Bundle those notices with your release artifact package.
6. Ensure release notes identify included third-party components and versions.
7. Keep this repository's `LICENSE` included for repo-sourced scripts/docs.

## Track Checklist

When updating this module, review:

- `alma10.1/Containerfile`
- `alma10.1/podman-build.sh`
- `alma10.1/builder/build.sh`
- `alma10.1/installer/install-alma10.1.sh`
- `alma10.1/installer/verify.sh`
- `alma10.1/installer/postgresql18-immer.service`
- `alma10.1/README.md`
