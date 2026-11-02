# Running the live demo

The demo: Claude Code edits the Brewline project while Power BI Desktop has it
open, and Desktop applies each change without a restart. Everything runs on one
Windows PC. Allow 15 minutes to set up, and do a full dry run first: the project
has passed every structural check but had not been opened in Desktop when it
was written.

## Before the session

### Install

| Tool | Why | How |
|---|---|---|
| Power BI Desktop, August 2026 or later | Detects file edits and offers to apply them | Microsoft Store or download |
| Git for Windows | Git, plus the Git Bash shell the validators need | `winget install Git.Git` |
| jq | The PBIR validator skips silently without it | `winget install jqlang.jq` |
| Python 3 | Extends the dummy data | `winget install Python.Python.3.13` |
| Claude Code | The agent | Claude desktop app (Code tab), or the CLI |

### Prepare Desktop

1. Clone the repo, or `git pull` if you already have it.
2. In Desktop: File > Options and settings > Options > Preview features, tick
   **Detect and reload external PBIP changes**, then restart Desktop.
3. Open `projects\Brewline\Brewline.pbip` and select **Refresh**. When asked
   how to connect to `raw.githubusercontent.com`, choose **Anonymous**.
4. Recommended: Transform data > Edit parameters, set **DataSource** to your
   local data folder with a trailing backslash, for example
   `C:\src\power-bi-workbench\projects\Brewline\data\`, then apply. Refreshes
   then skip the network and GitHub's few-minute cache. Don't commit this
   change.
5. Save (Ctrl+S). Desktop rewrites some files in its own format on the first
   save; that is expected, and `git diff` shows what it changed.

### Prepare Claude Code

Open Claude Code in the repo folder. The workbench plugins aren't installed
(the plugin build is currently missing), so give it the context directly:

> Read AGENTS.md, then skills/pbip/tmdl/instructions.md and
> skills/pbip/pbir-format/instructions.md. We're working on
> projects/Brewline, which is open in Power BI Desktop. After every TMDL edit,
> run `bash hooks/pbip/validate-tmdl.sh <file>`; after every PBIR edit, run
> `bash hooks/pbip/validate-pbir.sh <file>`. Fix anything that fails before
> moving on.

## On stage

1. **Show the source.** Open `Brewline.SemanticModel/definition/tables/_Measures.tmdl`
   next to the report: measures are just text.
2. **Report-only brief.** "Add a Channels page: orders by channel by month, and
   mobile order share by shop." When the agent finishes, click **Apply external
   changes** in Desktop. The new page appears.
3. **Model and report brief.** "Add a Like-for-like Revenue YoY % measure that
   only counts shops open for all of both periods, and add it to the Shops
   table." Apply again. If the new column shows blanks, select Refresh.
4. **New data.** "Extend the Brewline data to 30 November 2026." The agent runs
   `python projects/Brewline/data/generate_data.py --end 2026-11-30`. Select
   Refresh: "Data through" changes to 30 Nov 2026 and November appears in the
   trend.
5. **The diff.** `git diff --stat` shows every change as reviewable text: the
   start of the outer loop.

Rules while presenting:

- Save in Desktop before asking the agent for anything. Applying external
  changes discards unsaved Desktop edits.
- Apply resets filters and slicer selections.
- New tables or Power Query changes need a Refresh after Apply. Renamed page or
  visual folders need a Desktop restart.

## Afterwards

Keep or discard the demo changes. To discard them:

```bash
git restore projects/Brewline
git clean -fd projects/Brewline
```

## If something goes wrong

- **No banner after an edit:** check the preview setting is on and Desktop was
  restarted; otherwise close and reopen the `.pbip`.
- **Desktop won't open the project:** copy the full error text into Claude
  Code; it names the file at fault.
- **Refresh fails on a web error:** set DataSource to the local folder (step 4
  of Prepare Desktop).
