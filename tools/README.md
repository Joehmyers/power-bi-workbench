# Tools

Platform-neutral tool definitions, one YAML file per tool. A tool is an
external capability an agent can call; today every tool here is an MCP
server. Groups reference tools by file name in their `group.yaml`
(`tools: [pbiviz]`), and adapters translate them into whatever the platform
supports (the Claude adapter emits a `.mcp.json` per plugin; Genie and
OpenAI assistants cannot attach these servers, so their adapters skip them).

## Format

```yaml
name: fabric-sql            # file name without .yaml
description: ...            # optional
type: mcp
transport: http             # http or stdio
url: https://...            # http only
headers:                    # http only, optional
  Authorization: Bearer ${FABRIC_PBI_TOKEN}
command: npx                # stdio only
args: ["-y", "package", "mcp"]
```

Environment variable placeholders (`${FABRIC_PBI_TOKEN}`) pass through
verbatim; the consuming platform expands them at run time.

Note: this directory is otherwise gitignored (`/tools/*`) because hook
scripts look for locally built dev binaries under `tools/`. Only `*.yaml`
and this README are tracked.
