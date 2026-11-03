# AGENTS.md

Agent context for this repository, read at the start of a session. GitHub
Copilot in VS Code attaches it to every chat when the repo root is the
workspace (setting `chat.useAgentsMdFile`, on by default).

## What this repository is

This repo is a PBIP workbench for editing Power BI Project files directly in
`projects/`. The core workflow is: open or create a project, read the relevant
TMDL/PBIR files, make the required semantic-model or report edits, and report
what could not be verified in Desktop.

`projects/Brewline/` is the demo project with dummy data. Read its `README.md`
before working on it.

Checks are already in place under `checks/pbip/` and are the current repo
validation layer. Hooks, plugins, and marketplace metadata are optional future
layers for automation and packaging; they are not the baseline editing workflow
of this repo.

## PBIP project conventions

```
projects/<Name>/
  <Name>.pbip                       the file Power BI Desktop opens
  <Name>.SemanticModel/definition/  TMDL: model.tmdl, relationships.tmdl, tables/*.tmdl
  <Name>.Report/definition/         PBIR: pages/pages.json, pages/<page>/page.json,
                                    pages/<page>/visuals/<visual>/visual.json
```

## Working a brief

1. Read the project's README, then the TMDL and PBIR files the brief touches.
   Match what is already there: the measure home table, display folders,
   naming, and the `$schema` versions in existing files.
2. TMDL: indentation is semantic, one tab per level, never spaces. Quote names
   that contain spaces or special characters (`'Gross Margin %'`). `///` sets
   a description and must sit directly above its object. Give new objects a
   new GUID `lineageTag`; never change existing ones.
3. PBIR: each page and visual is a folder whose name equals its `name` field.
   Use only letters, digits, `_` and `-`, or Desktop silently drops it. Add new
   pages to `pages/pages.json` `pageOrder`. Field references use the table as
   `Entity` and the column or measure as `Property`, and must exist in the
   model.
4. Avoid editing `definition.pbir` and `report.json` while Desktop has the
   project open: its reload preview doesn't support external changes to them.
   Never change a `.platform` file's `logicalId`.
5. Power BI Desktop may have the project open. It offers to reload saved file
   changes ("Apply external changes"); new tables, Power Query edits and new
   data also need a Refresh. Say which results can only be confirmed in
   Desktop: DAX values and how visuals render.

## Reference material

Detailed guidance lives in `skills/`. Read the relevant file when a brief
needs it:

- TMDL: `skills/pbip/tmdl/instructions.md`, with a full example model in
  `skills/pbip/tmdl/examples/`
- PBIR: `skills/pbip/pbir-format/instructions.md` and its `references/`
- DAX, Power Query and report design: `skills/semantic-models/` and
  `skills/reports/`

## Checks you can run

The validators in `checks/pbip/` are the repo's current validation checks and run
standalone (bash; Git Bash on Windows):

```bash
bash checks/pbip/validate-tmdl.sh <file.tmdl>
bash checks/pbip/validate-pbir.sh <file.json>     # skips silently without jq
python3 skills/pbip/pbip/scripts/validate_pbip.py projects/<Name>/<Name>.pbip
```

They check structure only, and nothing runs them automatically yet. This repo
already includes these checks; hook automation is the next step, not the current
baseline. After a batch of edits, tell the agent to run the relevant check
script to flag any errors it introduced and to confirm the project still passes
the repo's local validation gates.

## Future next step

- Agent plugins, generated vendor artifacts, and marketplace packaging are not
  required for direct PBIP editing.
- They are follow-on tasks when you want to wire the repo into a vendor-specific
  workflow or a packaged install flow.
- CI: there are no workflows.
- If this repo is later packaged for distribution, restore project metadata and
  license files as part of that release step.

## Repository rules

- Do not commit `.pbi/localSettings.json` or `.pbi/cache.abf` (gitignored);
  everything else in a PBIP project is source.
- External toolchains (Tabular Editor, the pbir CLI, the Fabric CLI) are
  optional extras when installed, never a dependency.
- The skills and hooks originate from Kurt Buhler's power-bi-agentic-development
  marketplace (GPL-3.0); keep that credit.
