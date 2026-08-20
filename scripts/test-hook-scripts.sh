#!/usr/bin/env bash
#
# Smoke-test the neutral hook scripts and the Claude hook shim.
#
# Exercises hooks/ scripts standalone (file paths and command text as
# arguments) and through adapters/claude/claude-hook-adapter.sh with
# simulated Claude Code payloads. Requires jq; the TMDL case self-skips
# when no tmdl-validate binary runs on this platform.
#
# Usage: bash scripts/test-hook-scripts.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$REPO_ROOT/hooks"
SHIM="$REPO_ROOT/adapters/claude/claude-hook-adapter.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/hook-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }

PASS=0
FAIL=0

check() {
    # check <name> <expected-exit> <actual-exit>
    if [[ "$3" -eq "$2" ]]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $1 (expected exit $2, got $3)"
    fi
}

# The shim resolves scripts relative to its own directory, so stage a hooks
# directory the way the Claude adapter lays it out.
stage() {
    # stage <hook-group> -> echoes the staged dir
    local dir="$WORK/staged-$1"
    mkdir -p "$dir"
    cp -R "$HOOKS/$1/." "$dir/"
    cp "$SHIM" "$dir/"
    echo "$dir"
}

# ── Fixtures ────────────────────────────────────────────────────────────────
mkdir -p "$WORK/Demo.Report/pages/p1" "$WORK/Demo.SemanticModel/definition"
echo '{ bad json' > "$WORK/Demo.Report/pages/p1/page.json"
cat > "$WORK/Demo.Report/pages/p1/page-good.json" <<'EOF'
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json",
  "name": "p1",
  "displayName": "Page 1",
  "displayOption": "FitToPage"
}
EOF
cat > "$WORK/Demo.Report/definition.pbir" <<'EOF'
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/2.0.0/schema.json",
  "version": "4.0",
  "datasetReference": {}
}
EOF
printf 'table Sales\n\tcolumn Amount\n\t\t\tdataType: int64\n' > "$WORK/Demo.SemanticModel/definition/bad.tmdl"
cat > "$WORK/bad.rdl" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Report xmlns="http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition">
  <Body><ReportItems><Tablix Name="T1"><DataSetName>MissingDataset</DataSetName></Tablix></ReportItems></Body>
</Report>
EOF

PBIP="$(stage pbip)"
PBID="$(stage pbi-desktop)"

# ── Standalone: file paths as arguments ─────────────────────────────────────
bash "$PBIP/validate-pbir.sh" "$WORK/Demo.Report/pages/p1/page.json" 2>/dev/null
check "pbir standalone rejects bad JSON" 2 $?
bash "$PBIP/validate-pbir.sh" "$WORK/Demo.Report/pages/p1/page-good.json" 2>/dev/null
check "pbir standalone passes good page" 0 $?
bash "$PBIP/validate-pbir.sh" "$WORK/Demo.Report/pages/p1/page-good.json" "$WORK/Demo.Report/pages/p1/page.json" 2>/dev/null
check "pbir standalone aggregates multiple files" 2 $?
bash "$PBIP/validate-report-binding.sh" "$WORK/Demo.Report/definition.pbir" 2>/dev/null
check "report-binding standalone rejects empty binding" 2 $?
# Run in place: validate-rdl.sh finds its bundled validator relative to the
# hooks directory (staging it alone would leave the validator behind).
bash "$HOOKS/paginated-reports/validate-rdl.sh" "$WORK/bad.rdl" 2>/dev/null
check "rdl standalone rejects undefined dataset" 2 $?

# The TMDL check needs the bundled tmdl-validate binary. Decide availability
# up front so a silently skipping hook counts as a failure, not a skip.
TMDL_PLAT=""
case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) TMDL_PLAT="linux-x64" ;;
    Darwin-arm64) TMDL_PLAT="darwin-arm64" ;;
    Darwin-x86_64) TMDL_PLAT="darwin-x64" ;;
esac
if [[ -n "$TMDL_PLAT" && -x "$PBIP/bin/tmdl-validate-$TMDL_PLAT" ]]; then
    bash "$PBIP/validate-tmdl.sh" "$WORK/Demo.SemanticModel/definition/bad.tmdl" 2>/dev/null
    check "tmdl standalone rejects bad indentation" 2 $?
else
    echo "SKIP: no tmdl-validate binary for this platform"
fi

# ── Standalone: command text as argument ────────────────────────────────────
bash "$PBID/pbi-hooks.sh" validate-measure 'powershell -Command $t.Measures.Add($m)' 2>/dev/null
check "pbi-hooks rejects measure without metadata" 2 $?
bash "$PBID/pbi-hooks.sh" validate-measure '$m.DisplayFolder="F"; $m.Description="d"; $m.FormatString="0"; $t.Measures.Add($m)' 2>/dev/null
check "pbi-hooks passes complete measure" 0 $?
bash "$PBID/pbi-hooks.sh" validate-dax 'ls -la' 2>/dev/null
check "pbi-hooks no-ops on unrelated command" 0 $?

# ── Through the Claude shim: stdin JSON payloads ────────────────────────────
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$WORK/Demo.Report/pages/p1/page.json" \
    | bash "$PBIP/claude-hook-adapter.sh" files json,pbir validate-pbir.sh 2>/dev/null
check "shim Write payload reaches pbir" 2 $?
printf '{"tool_name":"Bash","tool_input":{"command":"cat \\"%s\\""}}' "$WORK/Demo.Report/pages/p1/page.json" \
    | bash "$PBIP/claude-hook-adapter.sh" files json,pbir validate-pbir.sh 2>/dev/null
check "shim extracts path from Bash command" 2 $?
printf '{"tool_name":"Read","tool_input":{"file_path":"x.json"}}' \
    | bash "$PBIP/claude-hook-adapter.sh" files json,pbir validate-pbir.sh 2>/dev/null
check "shim no-ops on irrelevant tool" 0 $?
printf '{"tool_name":"Bash","tool_input":{"command":"$t.Measures.Add($m)"}}' \
    | bash "$PBID/claude-hook-adapter.sh" command pbi-hooks.sh validate-measure 2>/dev/null
check "shim command mode reaches pbi-hooks" 2 $?
printf '{"tool_name":"Write","tool_input":{"file_path":"x"}}' \
    | bash "$PBID/claude-hook-adapter.sh" command pbi-hooks.sh validate-measure 2>/dev/null
check "shim command mode ignores non-command tools" 0 $?

echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
