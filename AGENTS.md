# AGENTS.md

Agent context for this repository, read at the start of a session. GitHub
Copilot in VS Code attaches it to every chat when the repo root is the
workspace (setting `chat.useAgentsMdFile`, on by default).

## What this repository is

A workbench for brief-driven Power BI Project (PBIP) development. The PBIP
projects live in `projects/`, one subfolder per project. Your job on a brief:
change the project's semantic model (TMDL) and report (PBIR) files so the
brief is met, and say what you could not verify.

`projects/Brewline/` is a demo project with dummy data. Read its `README.md`
before working on it.

## A PBIP project

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

The validators in `hooks/pbip/` run standalone (bash; Git Bash on Windows):

```bash
bash hooks/pbip/validate-tmdl.sh <file.tmdl>
bash hooks/pbip/validate-pbir.sh <file.json>     # skips silently without jq
python3 skills/pbip/pbip/scripts/validate_pbip.py projects/<Name>/<Name>.pbip
```

They check structure only, and nothing runs them automatically yet.

## Not set up yet

- Agent plugins: `marketplace.yaml`, `plugins/` and `CLAUDE.md` were removed,
  so `adapters/claude/build.py` fails, and no agent loads the skills or runs
  the hooks automatically.
- CI: there are no workflows.
- `LICENSE` and `ATTRIBUTIONS.md` were removed; restore them before
  distributing the repo.

## Repository rules

- Do not commit `.pbi/localSettings.json` or `.pbi/cache.abf` (gitignored);
  everything else in a PBIP project is source.
- External toolchains (Tabular Editor, the pbir CLI, the Fabric CLI) are
  optional extras when installed, never a dependency.
- The skills and hooks originate from Kurt Buhler's power-bi-agentic-development
  marketplace (GPL-3.0); keep that credit.
