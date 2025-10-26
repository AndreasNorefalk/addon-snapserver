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

## Future guidance

- Prefer native util-linux tools (`setpriv`, `runuser`) when dropping
  privileges. Avoid `/command/*` helpers because they are wrappers around the
  s6 overlay PID 1 binary.
- If a change requires additional privilege helpers, document the behaviour and
  version impact here before shipping.
