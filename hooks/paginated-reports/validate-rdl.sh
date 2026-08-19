#!/bin/bash
#
# Validate paginated report (.rdl) structure.
#
# Usage: validate-rdl.sh FILE [FILE...]
#
# Platform-neutral hook script: takes file paths as arguments and works
# standalone (shell, CI, pre-commit) or behind any agent's hook mechanism.
# Adapters translate agent events into this call; see adapters/README.md.
# Runs the bundled validate_rdl.py on each .rdl argument and blocks on
# structural errors (element order, name collisions, tablix count invariants,
# dataset/datasource references, embedded-image references, dimension units).
# It does not check expressions or live field references; those surface at
# render time.
#
# Adapters should wire this to file writes and edits only, not to shell
# commands: an after-command hook cannot tell whether a command wrote or
# merely read a .rdl, so blocking there would hard-stop reads/cleanup
# (cat/grep/rm) and the skill's own validate command on a not-yet-fixed file.
# Validate a command-created .rdl by running validate_rdl.py directly (the
# workflow already does this at the validate step).
#
# Requires: python3 (or python). Silently skips if it is missing or the
# bundled validator cannot be found.
#
# Toggle via config.yaml in this directory (rdl_validation: false, or
# all_hooks_enabled: false as a master kill-switch).
#
# Exit codes:
#   0 - OK or not applicable
#   2 - Blocking: RDL validation error detected
#

set -o pipefail

# ── Config ──────────────────────────────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || exit 0
HOOK_CONFIG="$HOOK_DIR/config.yaml"

check_enabled() {
    local check_name="$1"
    [[ -f "$HOOK_CONFIG" ]] || return 0
    grep -qE "^${check_name}:[[:space:]]*false" "$HOOK_CONFIG" 2>/dev/null && return 1
    return 0
}

if [[ -f "$HOOK_CONFIG" ]] && grep -qE "^all_hooks_enabled:[[:space:]]*false" "$HOOK_CONFIG" 2>/dev/null; then
    exit 0
fi

check_enabled rdl_validation || exit 0

RDL_TIP="Tip: use the paginated-report skill when authoring or editing .rdl files."

# ── Locate python and the bundled validator ──────────────────────────────────
PYTHON=""
for cand in python3 python; do
    if command -v "$cand" &>/dev/null; then PYTHON="$cand"; break; fi
done
[[ -z "$PYTHON" ]] && exit 0

# First path: generated plugin layout. Second path: neutral source layout.
VALIDATOR_PY=""
for cand in "$HOOK_DIR/../skills/paginated-report/scripts/validate_rdl.py" \
            "$HOOK_DIR/../../skills/paginated-reports/paginated-report/scripts/validate_rdl.py"; do
    if [[ -f "$cand" ]]; then VALIDATOR_PY="$cand"; break; fi
done
[[ -n "$VALIDATOR_PY" ]] || exit 0

# ── Validate a single .rdl file ──────────────────────────────────────────────
validate_rdl_file() {
    local FILE_PATH="$1"
    FILE_PATH="${FILE_PATH//\\//}"

    [[ "$FILE_PATH" == *.rdl ]] || return 0
    [[ -f "$FILE_PATH" ]] || return 0

    if ! OUTPUT=$("$PYTHON" "$VALIDATOR_PY" "$FILE_PATH" 2>&1); then
        echo "RDL validation failed: $FILE_PATH" >&2
        echo "" >&2
        echo "$OUTPUT" >&2
        echo "" >&2
        echo "Fix the structural errors before continuing." >&2
        echo "" >&2
        echo "$RDL_TIP" >&2
        return 2
    fi

    return 0
}

# ── Validate every file passed as an argument ────────────────────────────────
RC=0
for FILE_ARG in "$@"; do
    validate_rdl_file "$FILE_ARG" || RC=2
done

exit $RC
