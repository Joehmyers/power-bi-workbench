# power-bi-workbench

A workbench for agent-driven Power BI Project (PBIP) development: an agent
modifies the PBIP projects in [`projects/`](projects/README.md) according to a
brief, with the skills in context so it makes those changes competently.

Derived from Kurt Buhler's
[power-bi-agentic-development](https://github.com/data-goblin/power-bi-agentic-development)
marketplace, trimmed to the skills, hooks, and agents that service PBIP
editing. Everything removed is recoverable from git history.

## Quickstart

1. Install the plugins, scoped to this repository:

   ```bash
   claude plugin marketplace add joehmyers/power-bi-workbench
   claude plugin install pbip semantic-models reports
   ```

2. Put a PBIP project in `projects/` (one subfolder per project; see
   [`projects/README.md`](projects/README.md)).

3. Give the agent the brief. The skills load on demand; the `pbip` hooks
   validate PBIR structure, TMDL syntax, and the report-to-model binding on
   every write.

## What is here

| Plugin | Serves |
|---|---|
| `pbip` | PBIP project structure, direct TMDL authoring, PBIR format, plus the validation hooks and the `pbip-validator` agent |
| `semantic-models` | Model design and audit, DAX authoring and optimisation, Power Query, naming conventions, refresh, lineage |
| `reports` | Report creation, design and layout, theme JSON, report review agents |

Hook checks are toggleable in `plugins/pbip/hooks/config.yaml`; set any key to
`false` to disable it.

## Repository layout

The content is agent-agnostic. The source of truth is platform-neutral, and
adapters translate it into each platform's native format:

- `marketplace.yaml` -- name, version, shared metadata, and the group list
- `skills/<group>/<skill>/` -- each skill as `skill.yaml` plus `instructions.md` and its resources
- `hooks/` -- validation hooks: a `hook.yaml` event map plus plain shell scripts that run standalone (`bash hooks/pbip/validate-tmdl.sh <file>`)
- `adapters/` -- one directory per target platform: [Claude Code](adapters/claude/README.md), [Databricks Genie](adapters/genie/README.md), and [OpenAI assistants](adapters/openai/README.md)
- `projects/` -- the PBIP projects being developed here; the skills and hooks operate on these files
- `plugins/` and `.claude-plugin/` -- the Claude adapter's generated output, committed so installs work straight from this repository. Edit the neutral sources, run `python3 adapters/claude/build.py`, and commit both; CI fails on drift.

The spec and the decision record behind this layout live in the maintainer's
template-repo docs, at `docs/specs/agent-agnostic-marketplace/spec.md` and
`docs/decisions/D-0002-platform-neutral-skill-format-for-agent-marketplaces.md`.

## Credits and licence

The skills and hooks originate from
[power-bi-agentic-development](https://github.com/data-goblin/power-bi-agentic-development)
by [Kurt Buhler](https://data-goblins.com) (Data Goblins), licensed GPL-3.0.
See [LICENSE](LICENSE) and [ATTRIBUTIONS.md](ATTRIBUTIONS.md).
