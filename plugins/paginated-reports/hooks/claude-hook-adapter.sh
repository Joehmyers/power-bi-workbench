#!/bin/bash
#
# Claude hook shim: translate Claude Code's hook protocol into plain script calls.
#
# Claude Code sends hook input as JSON on stdin. The neutral hook scripts in
# hooks/ know nothing about that protocol; they take their input as arguments.
# This shim sits between the two. build.py copies it into every generated
# plugin's hooks/ directory and wires hooks.json commands through it:
#
#   claude-hook-adapter.sh files <ext,ext> <script>
#       For file-change events. Write/Edit payloads pass tool_input.file_path
#       to <script>; Bash payloads pass every path in tool_input.command whose
#       extension matches. No matching path is a no-op.
#
#   claude-hook-adapter.sh command <script> [args...]
#       For command-pre and command-post events. Passes <args...> and the
#       payload's tool_input.command as the final argument to <script>.
#
# <script> is resolved relative to this file's directory. The shim exits with
# the script's exit code (0 = OK, 2 = blocking error), and exits 0 whenever
# the payload is not applicable or jq is missing.

# Strict mode intentionally relaxed; favors continuing execution over spurious
# exits on Windows Git Bash. Every failing path below exits explicitly.
set -o pipefail

MODE="${1:-}"
[[ -z "$MODE" ]] && exit 0

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
command -v jq &>/dev/null || exit 0

SHIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || exit 0
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

if [[ "$MODE" == "files" ]]; then
    EXTS="${2:-}"
    SCRIPT="$SHIM_DIR/${3:-}"
    [[ -n "$EXTS" && -f "$SCRIPT" ]] || exit 0
    EXT_RE="${EXTS//,/|}"

    if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
        [[ -z "$FILE_PATH" ]] && exit 0
        bash "$SCRIPT" "$FILE_PATH"
        exit $?

    elif [[ "$TOOL_NAME" == "Bash" ]]; then
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
        [[ -z "$COMMAND" ]] && exit 0

        # Extract candidate file paths with matching extensions: bare tokens,
        # then double-quoted, then single-quoted.
        CANDIDATES=()
        while IFS= read -r path; do
            [[ -n "$path" ]] && CANDIDATES+=("$path")
        done < <(echo "$COMMAND" | grep -oE '[^ "'\''><|;]+\.('"$EXT_RE"')[^ "'\''><|;]*' 2>/dev/null)

        while IFS= read -r path; do
            [[ -n "$path" ]] && CANDIDATES+=("$path")
        done < <(echo "$COMMAND" | grep -oE '"[^"]+\.('"$EXT_RE"')"' 2>/dev/null | tr -d '"')

        while IFS= read -r path; do
            [[ -n "$path" ]] && CANDIDATES+=("$path")
        done < <(echo "$COMMAND" | grep -oE "'[^']+\.(${EXT_RE})'" 2>/dev/null | tr -d "'")

        [[ ${#CANDIDATES[@]} -eq 0 ]] && exit 0

        DEDUPED=()
        while IFS= read -r path; do
            [[ -n "$path" ]] && DEDUPED+=("$path")
        done < <(printf '%s\n' "${CANDIDATES[@]}" | sort -u)

        bash "$SCRIPT" "${DEDUPED[@]}"
        exit $?
    fi
    exit 0

elif [[ "$MODE" == "command" ]]; then
    SCRIPT="$SHIM_DIR/${2:-}"
    [[ -f "$SCRIPT" ]] || exit 0
    shift 2

    [[ "$TOOL_NAME" == "Bash" ]] || exit 0
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [[ -z "$COMMAND" ]] && exit 0

    bash "$SCRIPT" "$@" "$COMMAND"
    exit $?
fi

exit 0
