# Agent Notes

## Goal
This repository is the standalone Julia package for Zed plot-pane integration logic.
Keep Zed extension-specific config (for example `tasks.json`) out of this repo.

## Scope boundaries
- Keep this package editor-agnostic where possible.
- Do not add assumptions that require the `zed` CLI to exist at import time.
- Runtime integration with Zed should degrade gracefully when `zed` is missing.

## Development guidelines
1. Prefer incremental API changes over breaking refactors.
2. Add or update tests when behavior changes.
3. Keep startup side effects minimal and explicit.
4. Use `julia --project=. -e 'using Pkg; Pkg.test()'` before finishing changes.

## Near-term tasks
- Split display setup into explicit public functions (optional auto-init path).
- Add tests around display registration idempotency.
- Add README examples for Plots.jl and Makie.jl usage.
