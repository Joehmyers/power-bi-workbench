# power-bi-workbench

A workbench for brief-driven Power BI Project (PBIP) development. The default
workflow is direct editing in [`projects/`](projects/README.md): update the
semantic model and report files to satisfy the brief, then validate in Power BI
Desktop and the repo tools where useful.

This repo is derived from Kurt Buhler's
[power-bi-agentic-development](https://github.com/data-goblin/power-bi-agentic-development)
marketplace, with the relevant PBIP, semantic-model, and report skills kept in
context for repo work.

## Workflow

1. Put a PBIP project in `projects/` (one subfolder per project; see
   [`projects/README.md`](projects/README.md)).
2. Read the project README and the specific TMDL/PBIR files the brief touches.
3. Make the semantic-model and report changes directly in the project files.
4. Validate with Desktop refreshes and run the repo check scripts when useful.
5. Tell the agent to run the relevant check script after each batch of edits to
   flag structural errors it may have introduced.
6. Current state: the repo already has validation checks in place; vendor hook
   wiring and packaging are the next step, not the current repo workflow.

## Repository layout

- `projects/` -- the PBIP projects being developed here; this is the main working area
- `skills/` -- repo guidance for PBIP authoring, DAX, Power Query, and report design
- `checks/` -- standalone validation check scripts; useful but optional
- `AGENTS.md` -- repo-specific operating instructions for agents
- `docs/` -- overview and presentation material, including the deck and repo architecture diagram

## Future next step

The repo is currently a PBIP workbench with validation checks already in place.
Vendor integration via generated hook wiring and platform-specific packaging is a
next-step extension, not part of the current baseline workflow.

- `checks/` can validate TMDL and PBIR structure when you want extra checks.
- vendor-specific hook wiring and packaging is a future task for integration work.
- `marketplace.yaml`, `plugins/`, and generated vendor artifacts are follow-on setup
  tasks for packaging or installation, not the core repo workflow.

## Credits and licence

The skills and hooks originate from
[power-bi-agentic-development](https://github.com/data-goblin/power-bi-agentic-development)
by [Kurt Buhler](https://data-goblins.com) (Data Goblins), licensed GPL-3.0.
If this repo is packaged for release, add the appropriate license metadata and
attribution files as part of that release step.
