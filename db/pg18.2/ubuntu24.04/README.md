# IMMER PostgreSQL 18.2 + TimescaleDB Builder (Ubuntu 24.04)

Build PostgreSQL 18.2 (and optional TimescaleDB) in an Ubuntu 24.04 container and install on Ubuntu 24.04 hosts.

## Prerequisites

- Linux host with Podman
- Network access to clone PostgreSQL and TimescaleDB sources during build
- Ubuntu 24.04 target host for installation

## Build

```bash
./podman-build.sh
```

Troubleshooting-only build (not for release artifacts):

```bash
INSTALL_TIMESCALEDB=0 ./podman-build.sh
```

Optional image-build override:

```bash
podman build \
  --build-arg BUILDER_USER=builder \
  --build-arg BUILDER_UID=1000 \
  -t immer/pg18-builder:ubuntu24.04 \
  -f Containerfile \
  .
```

Outputs are written to `./out/`:

- `opt-pgsql-18.2-<branch>-<tag>.tgz` (extract at `/` -> `/opt/pgsql/18.2`)
- `meta/postgres.version.txt`
- `meta/pg_config.configure.txt`

## Install on target host

Copy the build artifact and installer files (`install-ubuntu24.04.sh`, `postgresql18-immer.service`, `verify.sh`) to target host:

```bash
chmod +x install-ubuntu24.04.sh verify.sh
ARCHIVE=./opt-pgsql-18.2-*.tgz ./install-ubuntu24.04.sh
systemctl start postgresql18-immer.service
journalctl -u postgresql18-immer.service -f
```

Default paths:

- Data: `/var/lib/pgsql/18/data`
- Config: `/etc/pgsql/18` (symlinked into PGDATA)

## Verify runtime linkage

```bash
./verify.sh
```

Expected result:

- No `not found` entries from `ldd`
- Exit status `0`
- Verification covers `postgres` and, when present, `llvmjit.so` and `timescaledb.so`

## Podman SELinux / non-SELinux note

`podman-build.sh` uses `PODMAN_VOLUME_LABEL` for mount labeling.

- Default value: `:Z,U` (SELinux hosts)
- For non-SELinux hosts: set `PODMAN_VOLUME_LABEL=""`

Examples:

```bash
./podman-build.sh
PODMAN_VOLUME_LABEL="" ./podman-build.sh
```

Mount format:

```bash
-v "${OUT_DIR}:/out${PODMAN_VOLUME_LABEL}"
```

## Licensing

- Repository files: MIT (`../../../LICENSE`)
- Built artifacts: upstream component licenses apply
- See `../THIRD_PARTY_LICENSES.md` before redistributing binaries
