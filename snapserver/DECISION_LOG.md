# Snapcast Add-on Decision Log

This document captures notable runtime and packaging decisions so we do not
repeat earlier experiments when troubleshooting future regressions.

## Privilege management history

- **0.1.90 and earlier – s6 `su-exec` helper**  
  Relying on `/command/s6-overlay-suexec` caused the add-on to crash with
  `s6-overlay-suexec: fatal: can only run as pid 1` when services attempted to
  drop privileges.
- **0.1.92 – Explicit `su-exec` package**  
  Installing the Alpine `su-exec` package reintroduced the same PID 1 failure on
  Home Assistant OS, so the change was reverted.
- **0.1.93 – util-linux fallback chain**  
  We attempted to use `setpriv`, `runuser`, and `su`. Falling back to `su`
  regressed into the PID 1 failure again on certain Supervisor releases.
- **0.1.94 – `setpriv` / `runuser` only**
  The add-on now restricts itself to util-linux helpers that are known to work
  inside the Supervisor environment. If neither helper exists we keep running as
  root and emit a warning instead of invoking the incompatible `su` path.
- **0.1.95 – Resilient Snapserver supervision**
  Snapserver occasionally received external `SIGTERM` signals which stopped the
  entire add-on. The service wrapper now restarts Snapserver automatically
  unless the Supervisor explicitly requested a shutdown.
- **0.1.96 – Ignore `/command` shim symlinks**
  Some Supervisor releases ship `/usr/bin/setpriv` and friends as symlinks that
  resolve into `/command/s6-overlay-suexec`, reintroducing the PID 1 crash when
  dropping privileges. The helper discovery now resolves symlinks and skips any
  helper that ultimately points into `/command`.
- **0.1.97 – Use stable Alpine repository for snapcast-server**
  Changed from using the edge/community repository to the stable v3.22/community
  repository for snapcast-server installation. Mixing stable and edge packages
  can cause dependency conflicts and installation failures. The stable repository
  provides snapcast-server 0.31.0 which is sufficient and more reliable.

## Future guidance

- Prefer native util-linux tools (`setpriv`, `runuser`) when dropping
  privileges. Avoid `/command/*` helpers because they are wrappers around the
  s6 overlay PID 1 binary.
- If a change requires additional privilege helpers, document the behaviour and
  version impact here before shipping.
