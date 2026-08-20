# Claude adapter

Generates the Claude Code plugin marketplace from the platform-neutral
sources. This is the adapter whose output ships in this repository:
`plugins/` and `.claude-plugin/` are its build artifacts, committed so
`claude plugin marketplace add` can install straight from the repo.

## Build

```bash
python3 adapters/claude/build.py
```

Wipes and regenerates `plugins/` and `.claude-plugin/marketplace.json`.
Run it after any change under `marketplace.yaml`, `skills/`, `tools/`, or
`hooks/`, and commit the regenerated output together with the source change.
CI runs the same build and fails if the committed output drifts from the
sources.

## Mapping

| Neutral source | Claude output |
|---|---|
| `marketplace.yaml` | `.claude-plugin/marketplace.json`; shared fields of every `plugin.json` |
| `skills/<group>/group.yaml` | `plugins/<group>/.claude-plugin/plugin.json` |
| `skill.yaml` + `instructions.md` | `plugins/<group>/skills/<skill>/SKILL.md` (YAML frontmatter + body) |
| skill resources | copied verbatim next to `SKILL.md` |
| `skills/<group>/{agents,commands,scripts}/` | copied verbatim into the plugin |
| `tools/<name>.yaml` (via the group's `tools` list) | `plugins/<group>/.mcp.json` |
| `hooks/<name>/hook.yaml` | `plugins/<group>/hooks/hooks.json` |
| `hooks/<name>/` scripts and assets | copied verbatim into `plugins/<group>/hooks/` |
| `AGENTS.md` | `CLAUDE.md` (an import shim, since Claude Code does not read AGENTS.md natively) |

Hook events map to Claude Code's hook model: `file-change` becomes
PostToolUse `Edit` and `Write` matchers, `command-pre` becomes a PreToolUse
`Bash` matcher, and `command-post` a PostToolUse `Bash` matcher, each with
the event's glob as the `if` filter and its `timeout`.

## The hook shim

The neutral hook scripts take their input as arguments; Claude Code sends
hook input as JSON on stdin. `claude-hook-adapter.sh` (copied into every
generated hooks directory) bridges the two: it parses the payload, extracts
the file path or command text, and calls the neutral script. See the header
comment in the shim for the exact contract.

## Example

A minimal skill in the neutral tree:

```
skills/demo/hello/skill.yaml
skills/demo/hello/instructions.md
skills/demo/group.yaml
```

```yaml
# skills/demo/hello/skill.yaml
name: hello
description: Say hello. Use when the user greets you.
instructions: instructions.md
```

Add `demo` to `groups` in `marketplace.yaml`, run the build, and the output
appears as `plugins/demo/skills/hello/SKILL.md` with the marketplace entry
wired up.
