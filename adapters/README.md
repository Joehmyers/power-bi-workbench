# Adapters

The platform-neutral sources in this repository know nothing about any
particular agent. An adapter reads them and emits one platform's native
format. Each adapter is a self-contained script with its own README and
example config; copy one to add a platform.

## The neutral sources an adapter reads

| Source | Contents |
|---|---|
| `marketplace.yaml` | Name, version, shared metadata, and the ordered `groups` list |
| `skills/<group>/group.yaml` | Group name, description, keywords, plus which `tools` and `hooks` the group bundles |
| `skills/<group>/<skill>/skill.yaml` | Skill name and description |
| `skills/<group>/<skill>/instructions.md` | The skill's instruction body (plain Markdown) |
| `skills/<group>/<skill>/*` | Skill resources (`references/`, `examples/`, `scripts/`), shipped verbatim |
| `skills/<group>/{agents,commands}/` | Group-level prompt files, currently consumed by the Claude adapter only |
| `tools/<name>.yaml` | Tool definition (today: MCP servers over stdio or HTTP) |
| `hooks/<name>/hook.yaml` | Hook events: which script runs on which file change or shell command |
| `hooks/<name>/*.sh` | The hook scripts themselves: plain executables taking their input as arguments |

A skill directory is any directory under a group that contains `skill.yaml`.
The names `agents`, `commands`, and `scripts` are reserved for group-level
extras.

## Hook events

`hook.yaml` uses three event kinds:

- `file-change`: run the script after the agent writes or edits a file
  matching `paths`; the script receives file paths as arguments.
  `extensions` lists the file extensions to extract when a platform only
  exposes a raw shell command.
- `command-pre` / `command-post`: run the script before or after a shell
  command matching the `command_matches` glob; the script receives its
  `args` plus the command text as the final argument.

Scripts exit 0 for OK or not applicable and 2 for a blocking error, with the
message on stderr. They must degrade gracefully: missing dependencies mean
exit 0, never a spurious failure.

## Available adapters

| Adapter | Emits | Run |
|---|---|---|
| [`claude/`](claude/README.md) | The Claude Code plugin marketplace: `plugins/` and `.claude-plugin/` (generated, committed; CI fails on drift) | `python3 adapters/claude/build.py` |
| [`genie/`](genie/README.md) | A Databricks AI/BI Genie space: instruction text plus a spaces-API request body | `python3 adapters/genie/build.py <config.yaml>` |
| [`openai/`](openai/README.md) | An OpenAI assistant: instructions plus a `file_search` knowledge manifest, in both Assistants and Responses API shapes | `python3 adapters/openai/build.py <config.yaml>` |

The Claude adapter regenerates the whole marketplace and its output is
committed, because Claude Code installs plugins straight from this
repository. The Genie and OpenAI adapters build to `dist/` (gitignored) from
a config that picks skills, because those platforms hold configuration
server-side and have no equivalent of installing the full marketplace.

All adapters need Python 3 and PyYAML (`pip install pyyaml`).

## What does not translate

Not every capability exists everywhere. Hooks and MCP tools have no
counterpart in Genie or OpenAI assistants; group-level agents and commands
are Claude-specific prompt formats today. Each adapter's README states what
travels and what stays behind. The rule: an adapter translates what the
platform can express and documents the rest, rather than pretending.
