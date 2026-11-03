# Projects

Working folder for Power BI Project (PBIP) files. Put the PBIP projects you
are actively developing here, one subfolder per project:

```
projects/
  Sales/
    Sales.pbip
    Sales.SemanticModel/
      definition/            # TMDL: model.tmdl, tables/, relationships.tmdl, ...
    Sales.Report/
      definition/            # PBIR: report.json, pages/, ...
```

Save from Power BI Desktop with the PBIP format enabled (File > Options >
Preview features > Power BI Project files), or copy an existing project in.
PBIP is a text format built for git, so projects here are versioned like any
other source.

## Default workflow

The default repo workflow is direct editing in the PBIP project itself:

- update the semantic model in `.SemanticModel/definition/`
- update the report in `.Report/definition/`
- keep the project in sync with the brief and with the model/report structures
- validate with Desktop and the repo's check scripts when helpful
- after each edit batch, tell the agent to run the relevant check script so it can
  flag errors it introduced

## Validation checks

- `checks/pbip/` provides standalone validation checks for TMDL and PBIR.
- `skills/` provides the authoring guidance and conventions the repo expects.
- vendor integration with hook wiring is the next step if you want this repo to run
  as a packaged, vendor-specific workflow.

You can run the validators by hand, with no agent involved:

```bash
bash checks/pbip/validate-tmdl.sh projects/Sales/Sales.SemanticModel/definition/tables/Orders.tmdl
bash checks/pbip/validate-pbir.sh projects/Sales/Sales.Report/definition/pages/p1/page.json
```

## What stays out of git

Power BI Desktop writes per-machine state into each project's `.pbi/`
folders. The repository `.gitignore` excludes the two files that must not be
committed (`localSettings.json` and `cache.abf`); everything else in a
project is source and belongs in git.

For a ready-made model to experiment on, copy the SpaceParts example that
ships with the `tmdl` skill:

```bash
mkdir -p projects/SpaceParts
cp -r skills/pbip/tmdl/examples/SpaceParts.SemanticModel projects/SpaceParts/
```
