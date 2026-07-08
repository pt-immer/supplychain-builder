# Third-Party Licensing Notes

This repository contains build and installation scripts. It does not vendor third-party source code directly.

Built artifacts produced by this repository include third-party software and are subject to upstream license terms.

## Dependency Chain

### PostgreSQL

- Upstream: [postgres/postgres](https://github.com/postgres/postgres)
- Typical license: PostgreSQL License
- Source of truth for a built version: the `COPYRIGHT`/license files shipped in the checked out PostgreSQL tag (e.g. `REL_18_4`).

### TimescaleDB (optional)

- Upstream: [timescale/timescaledb](https://github.com/timescale/timescaledb)
- License terms depend on component/version: Apache-2.0 for the core, and the Timescale License (TSL) for community modules.
- Source of truth for a built version: the `LICENSE*` files and module-level notices in the checked out TimescaleDB tag (e.g. `2.28.2`).

### pgvector (optional)

- Upstream: [pgvector/pgvector](https://github.com/pgvector/pgvector)
- Typical license: PostgreSQL License
- Source of truth for a built version: the `LICENSE` file in the checked out pgvector tag (e.g. `v0.8.4`).

## Operational Guidance

- Before distributing produced binaries, review and retain upstream license files for each included component/version.
- If your distribution policy requires it, package upstream notices alongside released artifacts.
- This repository's own license (`LICENSE`) applies only to files in this repository, not to third-party dependencies.
