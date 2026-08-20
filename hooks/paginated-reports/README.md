# Paginated Reports Hooks

A hook that auto-validates paginated report (`.rdl`) files after an agent writes or edits them, in the spirit of the PBIP hooks' `validate-tmdl.sh` / `validate-pbir.sh` (which likewise fire only on writes and edits).

The script is platform-neutral: it takes file paths as arguments
(`bash validate-rdl.sh FILE...`) and works standalone, in CI, or behind any
agent's hook mechanism. `hook.yaml` describes when it should fire; adapters
(see `adapters/README.md`) translate that into platform wiring.

## Files

- `hook.yaml` - fires `validate-rdl.sh` on file writes and edits, filtered to `**/*.rdl` (10s timeout).
- `validate-rdl.sh` - runs the bundled `skills/paginated-report/scripts/validate_rdl.py` on each `.rdl` argument. Blocks with exit 2 + stderr on structural errors; exits 0 otherwise. It is intentionally not wired to shell commands: an after-command hook cannot tell whether a command wrote or merely read an `.rdl`, so blocking there would hard-stop reads/cleanup (`cat`/`grep`/`rm`) and the workflow's own validate command on a not-yet-fixed file. Validate a command-created `.rdl` by running `validate_rdl.py` directly.
- `config.yaml` - toggles: `rdl_validation` (this check) and `all_hooks_enabled` (master kill-switch). Set either to `false` to disable.

## What it checks

Whatever `validate_rdl.py` checks: XML well-formedness, the 2016 root namespace, a valid `rd:ReportID` GUID, top-level element order, namespace-scoped `Name` uniqueness, tablix column/row/cell-count invariants, dataset-to-datasource and tablix-to-dataset references, embedded-image references, and dimension unit suffixes. It does not check expressions, live field references, or render correctness; those surface at render time.

## Constraints

- Requires `python3` (or `python`); skips silently if it is missing or the validator script is not found.
- Works on bash 3.2 (macOS) and bash 4+ (Linux, Git Bash); no associative arrays, no `mapfile`.
- Only exit 2 + stderr surfaces to the agent; a passing run is invisible.

## Test

```bash
bash hooks/paginated-reports/validate-rdl.sh \
  skills/paginated-reports/paginated-report/assets/enter-data-starter.rdl; echo "exit=$?"
```
