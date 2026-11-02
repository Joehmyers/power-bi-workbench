# Running the live demo

The demo: an AI agent in VS Code reads the repo for context and edits the
Brewline project while Power BI Desktop has it open, and Desktop applies each
change without a restart. Everything runs on one Windows PC. Allow 15 minutes
to set up, and do a full dry run first: the project passed every structural
check but had not been opened in Desktop when it was written.

## Before the session

### Install

| Tool | Why |
|---|---|
| Power BI Desktop, August 2026 release or later | Detects file edits and offers to apply them |
| Git for Windows | To clone and pull the repo |
| VS Code with GitHub Copilot (or the Claude Code extension) | The agent |
| Python 3 | Extends the dummy data in the last step |

Clone to a short path such as `C:\src\power-bi-workbench`: Desktop needs every
project file path under 260 characters.

### Turn on reloading in Desktop

This is an application setting, not part of the project:

1. **File > Options and settings > Options > Preview features**.
2. Tick **Detect and reload external PBIP changes**.
3. Restart Power BI Desktop.

### Open the project

1. Open `projects\Brewline\Brewline.pbip` and select **Refresh**. When asked
   how to connect to `raw.githubusercontent.com`, choose **Anonymous**.
2. Recommended: Transform data > Edit parameters, set **DataSource** to the
   local data folder with a trailing backslash, e.g.
   `C:\src\power-bi-workbench\projects\Brewline\data\`, then apply. Refreshes
   then skip the network and GitHub's few-minute cache. Don't commit this
   change.
3. **Save**. Desktop rewrites some files in its own format on the first save;
   that is expected, and `git diff` shows what it changed.

### Open VS Code

Open the **repo root** in VS Code (File > Open Folder > `power-bi-workbench`).
Copilot attaches the root `AGENTS.md` to every chat (setting
`chat.useAgentsMdFile`, on by default). Desktop's own "open in Visual Studio
Code" shortcut opens only the project folder, which misses `AGENTS.md`.

Use Copilot Chat in **Agent** mode so it can edit files.

## On stage

Arrange VS Code and Desktop side by side. Save in Desktop before each ask.

1. **Context.** "What does the Brewline model contain, and where should a new
   measure go?" The agent reads `AGENTS.md`, the project README and the TMDL,
   and explains the model.
2. **Report change** (the prompt on the "Writing the prompt" slide). "In
   projects/Brewline, add a Channels page showing orders by channel by month
   and mobile order share by shop. Use the existing measures and follow
   AGENTS.md. Tell me what to check in Power BI Desktop." In Desktop, select
   **Apply external changes** in the banner. The new page appears.
3. **Model and report change.** "Add a Like-for-like Revenue YoY % measure
   that only counts shops open for all of both periods, and add it to the
   Shops table." Apply again. If the new column shows blanks, select Refresh.
4. **New data.** "Extend the Brewline data to 30 November 2026." The agent
   runs `python projects/Brewline/data/generate_data.py --end 2026-11-30`.
   Select Refresh: "Data through" changes to 30 Nov 2026 and November appears.
5. **The diff.** `git diff --stat` shows every change as reviewable text.

What reloading does and doesn't do (Microsoft's preview limitations):

- Apply reloads the whole report and model and resets filters and slicers.
- Apply discards unsaved Desktop edits, so save first.
- It doesn't reload data: new tables or Power Query changes need Refresh.
- Don't edit `definition.pbir` or `report.json` from outside Desktop during
  the preview. Pages, visuals and TMDL files are fine.

## Afterwards

Keep or discard the demo changes. To discard them:

```bash
git restore projects/Brewline
git clean -fd projects/Brewline
```

## If something goes wrong

- **No banner after an edit:** check the preview setting is ticked and Desktop
  was restarted; otherwise close and reopen the `.pbip`.
- **Desktop won't open the project:** paste the full error text into the
  agent; it names the file at fault.
- **Refresh fails on a web error:** set DataSource to the local folder.

## Not in this demo yet

The repo also has validation hooks and domain skills (`hooks/`, `skills/`).
Wiring them into the agent is still to do, so today the agent works from the
repo's own context.
