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

## How the tooling applies

The marketplace's skills and hooks are path-agnostic, so everything in this
repository works on files here once the relevant plugins are installed
(project-scoped installs are recommended; see the root README):

- The `pbip` plugin's hooks validate PBIR structure, TMDL syntax, and the
  report-to-model binding on every write or edit under a `.Report/` or
  `.SemanticModel/` folder.
- The `pbip`, `semantic-models`, and `reports` plugins carry the authoring
  skills (TMDL, DAX, PBIR, report design).
- The `pbi-desktop` plugin drives a live Power BI Desktop session when the
  project is open there.

You can also run the validators by hand, with no agent involved:

```bash
bash hooks/pbip/validate-tmdl.sh projects/Sales/Sales.SemanticModel/definition/tables/Orders.tmdl
bash hooks/pbip/validate-pbir.sh projects/Sales/Sales.Report/definition/pages/p1/page.json
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
