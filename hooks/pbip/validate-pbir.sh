#!/bin/bash
#
# Validate PBIR structure in .Report/ files.
#
# Usage: validate-pbir.sh FILE [FILE...]
#
# Platform-neutral hook script: takes file paths as arguments and works
# standalone (shell, CI, pre-commit) or behind any agent's hook mechanism.
# Adapters translate agent events into this call; see adapters/README.md.
# For each .json or .pbir argument inside a .Report/ directory, validates:
#   1. JSON syntax (jq empty)
#   2. Folder name spaces (pages/visuals won't render)
#   3. Required fields per file type (from Microsoft JSON schemas)
#   4. $schema URL format
#   5. Visual/page name format (word chars and hyphens only)
#   6. visualContainerObjects names against Microsoft's core visual catalog
#      (self-contained enum check; allowlist in core-visual-catalog.json)
#
# Checks can be toggled via config.yaml in the same directory as this script.
#
# Exit codes:
#   0 - OK or not applicable
#   2 - Blocking: validation error detected
#

# Strict mode intentionally relaxed; favors continuing execution over spurious
# exits on Windows Git Bash. Every failing path below exits 0 or 2 explicitly.
set -o pipefail

# Skip if jq not available (needed to inspect the JSON files themselves)
command -v jq &>/dev/null || exit 0

# ── Config ──────────────────────────────────────────────────────────────────
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || exit 0
HOOK_CONFIG="$HOOK_DIR/config.yaml"

# Master kill-switch (Windows escape hatch)
if [[ -f "$HOOK_CONFIG" ]] && grep -qE "^all_hooks_enabled:[[:space:]]*false" "$HOOK_CONFIG" 2>/dev/null; then
    exit 0
fi

check_enabled() {
    local check_name="$1"
    [[ -f "$HOOK_CONFIG" ]] || return 0
    grep -qE "^${check_name}:\\s*false" "$HOOK_CONFIG" 2>/dev/null && return 1
    return 0
}

SKILL_TIP="Tip: use the pbir-format skill if you are modifying PBIR files directly. Use the pbir-cli skill if you are using the pbir CLI."


# ── Validate a single file ──────────────────────────────────────────────────
# Returns 0 on pass, 2 on blocking error (message already written to stderr).

validate_file() {
    local FILE_PATH="$1"

    # Normalize path separators
    FILE_PATH="${FILE_PATH//\\//}"

    # Must be a JSON or PBIR file
    case "$FILE_PATH" in
        *.json|*.pbir) ;;
        *) return 0 ;;
    esac

    # Must be inside a .Report/ directory
    [[ ! "$FILE_PATH" =~ \.Report/ ]] && return 0

    # File must exist
    [[ -f "$FILE_PATH" ]] || return 0

    # ── JSON syntax ─────────────────────────────────────────────────────
    if check_enabled json_syntax && ! ERROR=$(jq empty "$FILE_PATH" 2>&1); then
        echo "JSON validation failed: $FILE_PATH" >&2
        echo "" >&2
        echo "$ERROR" >&2
        echo "" >&2
        echo "Fix the JSON syntax error before continuing." >&2
        echo "" >&2
        echo "$SKILL_TIP" >&2
        return 2
    fi

    # Remaining checks only apply to .Report/ files
    [[ ! "$FILE_PATH" =~ \.Report/ ]] && return 0

    local BASENAME
    BASENAME=$(basename "$FILE_PATH")

    # ── Folder name spaces ──────────────────────────────────────────────
    local REPORT_RELATIVE="${FILE_PATH#*\.Report/}"
    local DIR_PATH
    DIR_PATH=$(dirname "$REPORT_RELATIVE")
    if check_enabled folder_spaces && [[ "$DIR_PATH" =~ \  ]]; then
        echo "PBIR validation failed: $FILE_PATH" >&2
        echo "" >&2
        echo "Folder path contains spaces: $DIR_PATH" >&2
        echo "Pages and visuals with spaces in folder names deploy but won't render in Power BI." >&2
        echo "Rename folders to use underscores or hyphens instead of spaces." >&2
        echo "" >&2
        echo "$SKILL_TIP" >&2
        return 2
    fi

    # ── Per-file-type validation ────────────────────────────────────────
    local RESULT VALS SCHEMA MISSING

    case "$BASENAME" in
        visual.json)
            RESULT=$(jq -r '
                (."$schema" // ""),
                (has("name") | tostring),
                (has("position") | tostring),
                (has("visual") | tostring),
                (has("visualGroup") | tostring),
                (.name // "")
            ' "$FILE_PATH" 2>/dev/null) || return 0

            VALS=()
            while IFS= read -r line; do VALS+=("$line"); done <<< "$RESULT"
            SCHEMA="${VALS[0]:-}"
            local HAS_NAME="${VALS[1]:-}" HAS_POSITION="${VALS[2]:-}"
            local HAS_VISUAL="${VALS[3]:-}" HAS_VISUAL_GROUP="${VALS[4]:-}"
            local NAME="${VALS[5]:-}"

            if check_enabled required_fields; then
                MISSING=()
                [[ -z "$SCHEMA" ]] && MISSING+=("\$schema")
                [[ "$HAS_NAME" != "true" ]] && MISSING+=("name")
                [[ "$HAS_POSITION" != "true" ]] && MISSING+=("position")
                if [[ "$HAS_VISUAL" != "true" ]] && [[ "$HAS_VISUAL_GROUP" != "true" ]]; then
                    MISSING+=("visual or visualGroup (oneOf)")
                fi
                if [[ ${#MISSING[@]} -gt 0 ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Missing required fields: ${MISSING[*]}" >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            if check_enabled schema_url && [[ -n "$SCHEMA" ]]; then
                if [[ ! "$SCHEMA" =~ ^https://developer\.microsoft\.com/json-schemas/fabric/item/report/definition/ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Unexpected \$schema URL: $SCHEMA" >&2
                    echo "Expected: https://developer.microsoft.com/json-schemas/fabric/item/report/definition/..." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            if check_enabled name_format && [[ -n "$NAME" ]]; then
                if [[ ! "$NAME" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Invalid name: '$NAME'" >&2
                    echo "Names must consist of word characters (letters, digits, underscores) or hyphens." >&2
                    echo "Non-compliant names cause Power BI to silently ignore the object." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            # visualContainerObjects names against the core visual catalog allowlist.
            # The 15 container objects are universal (same for built-in and custom
            # visuals), so this is safe to enforce. Visual type ids are NOT checked:
            # custom visuals use arbitrary type strings. Allowlist + catalog version
            # in core-visual-catalog.json; degrades silently if that file is absent.
            if check_enabled visual_catalog_enum && [[ -f "$HOOK_DIR/core-visual-catalog.json" ]]; then
                local VCO_ALLOW BAD_VCO CATVER ALLOWED
                VCO_ALLOW=$(jq -c '.vcoNames' "$HOOK_DIR/core-visual-catalog.json" 2>/dev/null)
                if [[ -n "$VCO_ALLOW" && "$VCO_ALLOW" != "null" ]]; then
                    BAD_VCO=$(jq -r --argjson allow "$VCO_ALLOW" '
                        ((.visual.visualContainerObjects // {}) | keys) - $allow | .[]?
                    ' "$FILE_PATH" 2>/dev/null)
                    if [[ -n "$BAD_VCO" ]]; then
                        CATVER=$(jq -r '.catalogVersion // "?"' "$HOOK_DIR/core-visual-catalog.json" 2>/dev/null)
                        ALLOWED=$(jq -r '.vcoNames | join(", ")' "$HOOK_DIR/core-visual-catalog.json" 2>/dev/null)
                        echo "PBIR validation failed: $FILE_PATH" >&2
                        echo "" >&2
                        echo "Unrecognized visualContainerObjects name(s):" >&2
                        printf '  - %s\n' $BAD_VCO >&2
                        echo "" >&2
                        echo "Valid container objects (core visual catalog $CATVER):" >&2
                        echo "  $ALLOWED" >&2
                        echo "" >&2
                        echo "Container objects are the same for every visual. Power BI silently" >&2
                        echo "ignores an unknown name. Disable with visual_catalog_enum: false." >&2
                        echo "" >&2
                        echo "$SKILL_TIP" >&2
                        return 2
                    fi
                fi
            fi
            ;;

        page.json)
            RESULT=$(jq -r '
                (."$schema" // ""),
                (has("name") | tostring),
                (has("displayName") | tostring),
                (has("displayOption") | tostring),
                (.name // ""),
                (.displayOption // "")
            ' "$FILE_PATH" 2>/dev/null) || return 0

            VALS=()
            while IFS= read -r line; do VALS+=("$line"); done <<< "$RESULT"
            SCHEMA="${VALS[0]:-}"
            local HAS_NAME="${VALS[1]:-}" HAS_DISPLAY_NAME="${VALS[2]:-}"
            local HAS_DISPLAY_OPTION="${VALS[3]:-}" NAME="${VALS[4]:-}"
            local DISPLAY_OPTION="${VALS[5]:-}"

            if check_enabled required_fields; then
                MISSING=()
                [[ -z "$SCHEMA" ]] && MISSING+=("\$schema")
                [[ "$HAS_NAME" != "true" ]] && MISSING+=("name")
                [[ "$HAS_DISPLAY_NAME" != "true" ]] && MISSING+=("displayName")
                [[ "$HAS_DISPLAY_OPTION" != "true" ]] && MISSING+=("displayOption")
                if [[ ${#MISSING[@]} -gt 0 ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Missing required fields: ${MISSING[*]}" >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            # Valid displayOption values per the Microsoft PageDisplayOption schema.
            if check_enabled enum_values && [[ -n "$DISPLAY_OPTION" ]]; then
                case "$DISPLAY_OPTION" in
                    FitToPage|FitToWidth|ActualSize|DeprecatedDynamic|ActualSizeTopLeft) ;;
                    *)
                        echo "PBIR validation failed: $FILE_PATH" >&2
                        echo "" >&2
                        echo "Invalid displayOption value: '$DISPLAY_OPTION'" >&2
                        echo "Valid: FitToPage, FitToWidth, ActualSize (DeprecatedDynamic and ActualSizeTopLeft are deprecated)." >&2
                        echo "A 16:9 page ratio comes from height/width (e.g. 1080/1920), not displayOption." >&2
                        echo "" >&2
                        echo "$SKILL_TIP" >&2
                        return 2
                        ;;
                esac
            fi

            if check_enabled schema_url && [[ -n "$SCHEMA" ]]; then
                if [[ ! "$SCHEMA" =~ ^https://developer\.microsoft\.com/json-schemas/fabric/item/report/definition/ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Unexpected \$schema URL: $SCHEMA" >&2
                    echo "Expected: https://developer.microsoft.com/json-schemas/fabric/item/report/definition/..." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            if check_enabled name_format && [[ -n "$NAME" ]]; then
                if [[ ! "$NAME" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Invalid name: '$NAME'" >&2
                    echo "Names must consist of word characters (letters, digits, underscores) or hyphens." >&2
                    echo "Non-compliant names cause Power BI to silently ignore the object." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi
            ;;

        report.json)
            RESULT=$(jq -r '
                (."$schema" // ""),
                (has("themeCollection") | tostring)
            ' "$FILE_PATH" 2>/dev/null) || return 0

            VALS=()
            while IFS= read -r line; do VALS+=("$line"); done <<< "$RESULT"
            SCHEMA="${VALS[0]:-}"
            local HAS_THEME="${VALS[1]:-}"

            if check_enabled required_fields; then
                MISSING=()
                [[ -z "$SCHEMA" ]] && MISSING+=("\$schema")
                [[ "$HAS_THEME" != "true" ]] && MISSING+=("themeCollection")
                if [[ ${#MISSING[@]} -gt 0 ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Missing required fields: ${MISSING[*]}" >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            if check_enabled schema_url && [[ -n "$SCHEMA" ]]; then
                if [[ ! "$SCHEMA" =~ ^https://developer\.microsoft\.com/json-schemas/fabric/item/report/definition/ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Unexpected \$schema URL: $SCHEMA" >&2
                    echo "Expected: https://developer.microsoft.com/json-schemas/fabric/item/report/definition/..." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi
            ;;

        definition.pbir)
            # Schema: definitionProperties/2.0.0
            # Required: $schema, version, datasetReference
            # Note: definition.pbir uses a different $schema URL base path (definitionProperties/)
            RESULT=$(jq -r '
                (."$schema" // ""),
                (has("version") | tostring),
                (has("datasetReference") | tostring)
            ' "$FILE_PATH" 2>/dev/null) || return 0

            VALS=()
            while IFS= read -r line; do VALS+=("$line"); done <<< "$RESULT"
            SCHEMA="${VALS[0]:-}"
            local HAS_VERSION="${VALS[1]:-}" HAS_DATASET_REF="${VALS[2]:-}"

            if check_enabled required_fields; then
                MISSING=()
                [[ -z "$SCHEMA" ]] && MISSING+=("\$schema")
                [[ "$HAS_VERSION" != "true" ]] && MISSING+=("version")
                [[ "$HAS_DATASET_REF" != "true" ]] && MISSING+=("datasetReference")
                if [[ ${#MISSING[@]} -gt 0 ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Missing required fields: ${MISSING[*]}" >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi

            if check_enabled schema_url && [[ -n "$SCHEMA" ]]; then
                if [[ ! "$SCHEMA" =~ ^https://developer\.microsoft\.com/json-schemas/fabric/item/report/definitionProperties/2\.[0-9]+\.[0-9]+/schema\.json$ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Unexpected \$schema URL: $SCHEMA" >&2
                    echo "Expected pattern: https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.x.x/schema.json" >&2
                    echo "Note: definition.pbir uses a different schema path (definitionProperties/) than other PBIR files." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi
            ;;

        reportExtensions.json|*.bookmark.json)
            if check_enabled schema_url; then
                SCHEMA=$(jq -r '."$schema" // empty' "$FILE_PATH" 2>/dev/null)
                if [[ -n "$SCHEMA" ]] && [[ ! "$SCHEMA" =~ ^https://developer\.microsoft\.com/json-schemas/fabric/item/report/definition/ ]]; then
                    echo "PBIR validation failed: $FILE_PATH" >&2
                    echo "" >&2
                    echo "Unexpected \$schema URL: $SCHEMA" >&2
                    echo "Expected: https://developer.microsoft.com/json-schemas/fabric/item/report/definition/..." >&2
                    echo "" >&2
                    echo "$SKILL_TIP" >&2
                    return 2
                fi
            fi
            ;;
    esac

    return 0
}


# ── Validate every file passed as an argument ───────────────────────────────

RC=0
for FILE_ARG in "$@"; do
    validate_file "$FILE_ARG" || RC=2
done

exit $RC
