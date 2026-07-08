# IMMER's PostgreSQL 18.4 (OLAP/OLGP)

Build and package PostgreSQL 18.4 (with TimescaleDB and pgvector) in a Docker builder image, then install on AlmaLinux/RHEL 10.x targets.

## Module Layout

- `alma10.2/`: Build and installer flow for AlmaLinux/RHEL 10.x targets.

The track contains:

- `Dockerfile`: builder image definition
- `builder/build.sh`: PostgreSQL, TimescaleDB, and pgvector build script
- `docker-build.sh`: local wrapper to build and run the builder image
- `installer/install-*.sh`: target host installer
- `installer/verify.sh`: runtime linkage sanity check
- `installer/postgresql18-immer.service`: systemd service unit

## Bundled Components

- PostgreSQL 18.4 (clang + ThinLTO, tuned for x86-64-v2)
- TimescaleDB 2.28.2
- pgvector 0.8.4
- Key/value: `hstore` + `JSONB` ship with core/contrib (no separate build); they are the recommended in-database KV store.

## Supported Matrix

- Host (build): Linux with Docker
- Target (install): AlmaLinux/RHEL 10.x for `alma10.2`

Use the `alma10.2` builder and installer track for supported target OSes.

## Quick Start (Manual)

### 1) Build artifact

```bash
cd alma10.2
./docker-build.sh
```

Artifacts are written to `out/`:

- `opt-pgsql-18.4-<branch>-<tag>.tgz`
- `meta/postgres.version.txt`
- `meta/pg_config.configure.txt`

### 2) Install on target host

Copy the artifact and installer files from `installer/` to target host, then run:

```bash
chmod +x install-*.sh
ARCHIVE=./opt-pgsql-18.4-*.tgz ./install-*.sh
systemctl start postgresql18-immer.service
```

### 3) Verify runtime linkage

```bash
./verify.sh
```

`verify.sh` should print no missing shared libraries and exit `0`.
It checks runtime linkage for `postgres` and, when present, `llvmjit.so`, `timescaledb.so`, and `vector.so`.

## Docker SELinux / Non-SELinux

`docker-build.sh` supports configurable mount labeling via `DOCKER_VOLUME_LABEL`:

- Default (SELinux hosts): `:Z`
- Non-SELinux hosts: set it to an empty string

Examples:

```bash
./docker-build.sh
DOCKER_VOLUME_LABEL="" ./docker-build.sh
```

## Safety and Validation

- Run installers as `root` on target hosts.
- `INSTALL_TIMESCALEDB=0` / `INSTALL_PGVECTOR=0` are troubleshooting build modes and are not intended for release artifacts.
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
5. Collect pgvector license/notice file for the included version.
6. Bundle those notices with your release artifact package.
7. Ensure release notes identify included third-party components and versions.
8. Keep this repository's `LICENSE` included for repo-sourced scripts/docs.

## Track Checklist

When updating this module, review:

- `alma10.2/Dockerfile`
- `alma10.2/docker-build.sh`
- `alma10.2/builder/build.sh`
- `alma10.2/installer/install-alma10.2.sh`
- `alma10.2/installer/verify.sh`
- `alma10.2/installer/postgresql18-immer.service`
- `alma10.2/README.md`
