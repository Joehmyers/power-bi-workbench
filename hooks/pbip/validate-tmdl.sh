#!/bin/bash
#
# Validate TMDL structural syntax.
#
# Usage: validate-tmdl.sh FILE [FILE...]
#
# Platform-neutral hook script: takes file paths as arguments and works
# standalone (shell, CI, pre-commit) or behind any agent's hook mechanism.
# Adapters translate agent events into this call; see adapters/README.md.
# Runs the tmdl-validate binary on any .tmdl file inside a .SemanticModel/
# or .Dataset/ directory; other arguments are ignored.
#
# NOTE: This is a lightweight structural linter, not a full TMDL parser.
# It will be superseded by `te validate` when the Tabular Editor CLI ships.
#
# Requires: tmdl-validate binary. Lookup order:
#   1. $HOOK_DIR/bin/tmdl-validate-<platform>[.exe]  (bundled with the plugin)
#   2. $PROJECT_DIR/tools/tmdl-validate/target/release/tmdl-validate[.exe]  (dev build;
#      PROJECT_DIR falls back to CLAUDE_PROJECT_DIR; skipped when neither is set)
#   3. tmdl-validate on PATH
# Silently skips if none are found.
#
# Checks can be toggled via config.yaml in the same directory as this script.
#
# Exit codes:
#   0 - OK or not applicable
#   2 - Blocking: TMDL validation error detected
#

# Strict mode intentionally relaxed; favors continuing execution over spurious
# exits on Windows Git Bash. Every failing path below exits 0 or 2 explicitly.
set -o pipefail

# ── Config ──────────────────────────────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || exit 0
HOOK_CONFIG="$HOOK_DIR/config.yaml"

check_enabled() {
    local check_name="$1"
    [[ -f "$HOOK_CONFIG" ]] || return 0
    grep -qE "^${check_name}:\\s*false" "$HOOK_CONFIG" 2>/dev/null && return 1
    return 0
}

# Master kill-switch (Windows escape hatch)
if [[ -f "$HOOK_CONFIG" ]] && grep -qE "^all_hooks_enabled:[[:space:]]*false" "$HOOK_CONFIG" 2>/dev/null; then
    exit 0
fi

check_enabled tmdl_syntax || exit 0

TMDL_TIP="Tip: use the tmdl skill if you are modifying TMDL files directly."

# ── Find the tmdl-validate binary ───────────────────────────────────────────

# Detect OS/arch to pick the right bundled binary.
UNAME_S=$(uname -s 2>/dev/null || echo "")
UNAME_M=$(uname -m 2>/dev/null || echo "")
PLATFORM=""
BIN_EXT=""
case "$UNAME_S" in
    Darwin)
        case "$UNAME_M" in
            arm64|aarch64) PLATFORM="darwin-arm64" ;;
            x86_64)        PLATFORM="darwin-x64" ;;
        esac
        ;;
    Linux)
        case "$UNAME_M" in
            x86_64) PLATFORM="linux-x64" ;;
        esac
        ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
        PLATFORM="windows-x64"
        BIN_EXT=".exe"
        ;;
esac

VALIDATOR=""
# 1. Bundled binary in $HOOK_DIR/bin/
if [[ -n "$PLATFORM" ]]; then
    CANDIDATE="$HOOK_DIR/bin/tmdl-validate-${PLATFORM}${BIN_EXT}"
    [[ -x "$CANDIDATE" ]] && VALIDATOR="$CANDIDATE"
fi
# 2. Local dev build under $PROJECT_DIR/tools/
PROJECT_DIR="${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-}}"
if [[ -z "$VALIDATOR" && -n "$PROJECT_DIR" ]]; then
    for EXT in "" ".exe"; do
        CANDIDATE="${PROJECT_DIR//\\//}/tools/tmdl-validate/target/release/tmdl-validate${EXT}"
        if [[ -x "$CANDIDATE" ]]; then
            VALIDATOR="$CANDIDATE"
            break
        fi
    done
fi
# 3. PATH
if [[ -z "$VALIDATOR" ]] && command -v tmdl-validate &>/dev/null; then
    VALIDATOR="tmdl-validate"
fi

# Skip silently if binary not available
[[ -z "$VALIDATOR" ]] && exit 0


# ── Validate a single TMDL file ────────────────────────────────────────────

validate_tmdl_file() {
    local FILE_PATH="$1"
    FILE_PATH="${FILE_PATH//\\//}"

    [[ "$FILE_PATH" == *.tmdl ]] || return 0

    # Must be inside a semantic model directory
    if [[ ! "$FILE_PATH" =~ \.SemanticModel/ ]] && \
       [[ ! "$FILE_PATH" =~ \.Dataset/ ]] && \
       [[ ! "$FILE_PATH" =~ /definition/ ]]; then
        return 0
    fi

    [[ -f "$FILE_PATH" ]] || return 0

    if ! ERROR=$("$VALIDATOR" "$FILE_PATH" 2>&1); then
        echo "TMDL validation failed: $FILE_PATH" >&2
        echo "" >&2
        echo "$ERROR" >&2
        echo "" >&2
        echo "Fix the TMDL structural errors before continuing." >&2
        echo "" >&2
        echo "$TMDL_TIP" >&2
        return 2
    fi

    return 0
}


# ── Validate every file passed as an argument ───────────────────────────────

RC=0
for FILE_ARG in "$@"; do
    validate_tmdl_file "$FILE_ARG" || RC=2
done

exit $RC
