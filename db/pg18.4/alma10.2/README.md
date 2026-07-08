# IMMER PostgreSQL 18.4 + TimescaleDB + pgvector Builder (AlmaLinux 10.2)

Build PostgreSQL 18.4 (with TimescaleDB and pgvector) in an AlmaLinux 10 minimal Docker container and install on AlmaLinux/RHEL 10.x hosts. Everything is compiled with clang + ThinLTO and tuned for the x86-64-v2 microarchitecture.

## Bundled Components

- PostgreSQL 18.4
- TimescaleDB 2.28.2
- pgvector 0.8.4
- `hstore` + `JSONB` (core/contrib) as the in-database key/value store — no separate build step.

## Prerequisites

- Linux host with Docker
- Network access to clone PostgreSQL, TimescaleDB, and pgvector sources during build
- AlmaLinux/RHEL 10.x target host for installation

## Build

```bash
./docker-build.sh
```

The builder container runs as root and installs into the real `${PREFIX}` inside the throwaway container before packaging a relocatable tarball; the host is not modified.

Optional platform override (advanced/debug only; the x86-64-v2 tuning comes from `build.sh` CFLAGS, not the platform flag):

```bash
DOCKER_PLATFORM="linux/amd64" ./docker-build.sh
```

Troubleshooting-only builds (not for release artifacts):

```bash
INSTALL_TIMESCALEDB=0 ./docker-build.sh
INSTALL_PGVECTOR=0 ./docker-build.sh
```

Optional image-build override:

```bash
docker build \
  --platform linux/amd64 \
  -t immer/pg18-builder:alma10.2 \
  -f Dockerfile \
  .
```

Outputs are written to `./out/`:

- `opt-pgsql-18.4-<branch>-<tag>.tgz` (extract at `/` -> `/opt/pgsql/18.4`)
- `meta/postgres.version.txt`
- `meta/pg_config.configure.txt`

## Install on target host

Copy the build artifact and installer files (`install-alma10.2.sh`, `postgresql18-immer.service`, `verify.sh`) to target host:

```bash
chmod +x install-alma10.2.sh verify.sh
ARCHIVE=./opt-pgsql-18.4-*.tgz ./install-alma10.2.sh
systemctl start postgresql18-immer.service
journalctl -u postgresql18-immer.service -f
```

Default paths:

- Data: `/var/lib/pgsql/18/data`
- Config: `/etc/pgsql/18` (symlinked into PGDATA)

On SELinux enforcing hosts, `install-alma10.2.sh` also applies:

- `semanage fcontext` for PGDATA (`postgresql_db_t`) and config dir (`postgresql_etc_t`)
- `restorecon -Rv` on both paths

## Enabling extensions

After the cluster is running, enable the bundled extensions per database as needed:

```sql
CREATE EXTENSION IF NOT EXISTS timescaledb;   -- requires shared_preload_libraries = 'timescaledb'
CREATE EXTENSION IF NOT EXISTS vector;        -- pgvector
CREATE EXTENSION IF NOT EXISTS hstore;        -- key/value (contrib)
```

`timescaledb` must be listed in `shared_preload_libraries`; add it to `postgresql.conf` and restart before running `CREATE EXTENSION timescaledb`.

## Verify runtime linkage

```bash
./verify.sh
```

Expected result:

- No `not found` entries from `ldd`
- Exit status `0`
- Verification covers `postgres` and, when present, `llvmjit.so`, `timescaledb.so`, and `vector.so`

## Docker SELinux / non-SELinux note

`docker-build.sh` uses `DOCKER_VOLUME_LABEL` for mount labeling.

- Default value: `:Z` (SELinux hosts)
- For non-SELinux hosts: set `DOCKER_VOLUME_LABEL=""`

Examples:

```bash
./docker-build.sh
DOCKER_VOLUME_LABEL="" ./docker-build.sh
```

Mount format:

```bash
-v "${OUT_DIR}:/out${DOCKER_VOLUME_LABEL}"
```

## Licensing

- Repository files: MIT (`../../../LICENSE`)
- Built artifacts: upstream component licenses apply
- See `../THIRD_PARTY_LICENSES.md` before redistributing binaries
