# db module template

Use this template when adding a new module under `db/<module-name>/`.

## Required structure

```text
db/<module-name>/
  README.md
  LICENSE
  THIRD_PARTY_LICENSES.md
  .editorconfig
  .gitignore
  <distro-or-target-1>/
    Containerfile
    podman-build.sh
    builder/build.sh
    installer/
      install-<target>.sh
      verify.sh
      <service>.service
  <distro-or-target-2>/
    ...
```

## Required README sections (`db/<module-name>/README.md`)

1. Module name and purpose
2. Module layout
3. Supported host/target matrix
4. Build flow (manual)
5. Install flow (manual)
6. Verify flow and expected exit behavior
7. SELinux/non-SELinux mount guidance
8. Licensing and third-party notice handling
9. Release compliance checklist
10. Parity checklist for multi-target modules

## Naming conventions

- Container images: `immer/<module>-builder:<target>`
- Service unit names: `<module>-<target>.service` (or documented equivalent)
- Installer scripts: `install-<target>.sh`
- Verification scripts: `verify.sh`

## Quality gates before publishing

- `shellcheck` clean on all module shell scripts
- No diagnostics/errors in module docs and scripts
- Verify script fails non-zero on missing runtime dependencies
- README commands tested at least once on intended target
