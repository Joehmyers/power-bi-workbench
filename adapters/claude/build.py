#!/usr/bin/env python3
"""Claude adapter: generate the Claude Code plugin marketplace from the neutral tree.

Reads the platform-neutral sources (marketplace.yaml, skills/, tools/, hooks/)
and writes the Claude Code format the marketplace serves:

  .claude-plugin/marketplace.json
  plugins/<group>/.claude-plugin/plugin.json
  plugins/<group>/skills/<skill>/SKILL.md   (frontmatter + instructions.md)
  plugins/<group>/skills/<skill>/<resources> (copied verbatim)
  plugins/<group>/{agents,commands,scripts}/ (copied verbatim)
  plugins/<group>/.mcp.json                 (from tools/<name>.yaml)
  plugins/<group>/hooks/hooks.json          (from hooks/<name>/hook.yaml)
  plugins/<group>/hooks/*                   (scripts and assets, plus the
                                             claude-hook-adapter.sh shim)

plugins/ and .claude-plugin/ are generated output. Do not edit them by hand;
edit the neutral sources and rerun this script. CI fails if they drift.

Usage: python3 adapters/claude/build.py   (from the repo root; needs PyYAML)
"""

import json
import pathlib
import re
import shutil
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ADAPTER_DIR = pathlib.Path(__file__).resolve().parent
EXCLUDE_NAMES = {".DS_Store", "__pycache__"}

# Files in a skill directory that describe the skill rather than ship with it.
SKILL_META = {"skill.yaml", "instructions.md"}

# Files in a hook directory that describe the hooks rather than ship with them.
HOOK_META = {"hook.yaml"}


def load_yaml(path: pathlib.Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def write_json(path: pathlib.Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def copy_item(src: pathlib.Path, dst: pathlib.Path):
    """Copy a file or directory tree, skipping OS litter and caches."""
    if src.is_dir():
        for item in sorted(src.rglob("*")):
            rel = item.relative_to(src)
            if any(p in EXCLUDE_NAMES or p.endswith(".pyc") for p in rel.parts):
                continue
            target = dst / rel
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(item, target)
    else:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def build_skill(skill_dir: pathlib.Path, out_dir: pathlib.Path):
    spec = load_yaml(skill_dir / "skill.yaml")
    body = (skill_dir / spec.get("instructions", "instructions.md")).read_text(encoding="utf-8")
    frontmatter = f"---\nname: {spec['name']}\ndescription: {spec['description']}\n---\n\n"
    # The name and description are written into the frontmatter unquoted, so a
    # value YAML cannot read back verbatim (a leading '[', a ': ' sequence, a
    # newline) would corrupt the generated SKILL.md. Fail loudly instead.
    parsed = yaml.safe_load(f"name: {spec['name']}\ndescription: {spec['description']}")
    if parsed != {"name": spec["name"], "description": spec["description"]}:
        sys.exit(
            f"{skill_dir}/skill.yaml: name or description does not survive plain "
            "YAML frontmatter; rephrase it (avoid leading punctuation and ': ' sequences)"
        )
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "SKILL.md").write_text(frontmatter + body, encoding="utf-8")
    for item in sorted(skill_dir.iterdir()):
        if item.name in SKILL_META or item.name in EXCLUDE_NAMES:
            continue
        copy_item(item, out_dir / item.name)


def hook_command(event: dict) -> str:
    """Command string wired into hooks.json for one neutral event."""
    shim = '${CLAUDE_PLUGIN_ROOT}/hooks/claude-hook-adapter.sh'
    if event["event"] == "file-change":
        exts = ",".join(event.get("extensions", []))
        if not exts:
            # Without extensions the shim gets misaligned arguments and the
            # generated hook would be wired but never run.
            sys.exit(f"hook event running {event['run']}: file-change needs a non-empty 'extensions' list")
        return f'bash "{shim}" files {exts} {event["run"]}'
    args = " ".join(event.get("args", []))
    return f'bash "{shim}" command {event["run"]} {args}'.rstrip()


def build_hooks(hook_dir: pathlib.Path, out_dir: pathlib.Path):
    spec = load_yaml(hook_dir / "hook.yaml")

    pre, post = [], []
    edit_hooks, write_hooks = [], []
    for event in spec.get("events", []):
        entry = {"type": "command", "command": hook_command(event), "timeout": event["timeout"]}
        kind = event["event"]
        if kind == "file-change":
            edit_hooks.append({**entry, "if": f'Edit({event["paths"]})'})
            write_hooks.append({**entry, "if": f'Write({event["paths"]})'})
        elif kind == "command-pre":
            pre.append({**entry, "if": f'Bash({event["command_matches"]})'})
        elif kind == "command-post":
            post.append({**entry, "if": f'Bash({event["command_matches"]})'})
        else:
            sys.exit(f"{hook_dir}/hook.yaml: unknown event kind '{kind}'")

    hooks = {}
    if pre:
        hooks["PreToolUse"] = [{"matcher": "Bash", "hooks": pre}]
    post_matchers = []
    if edit_hooks:
        post_matchers.append({"matcher": "Edit", "hooks": edit_hooks})
        post_matchers.append({"matcher": "Write", "hooks": write_hooks})
    if post:
        post_matchers.append({"matcher": "Bash", "hooks": post})
    if post_matchers:
        hooks["PostToolUse"] = post_matchers

    write_json(out_dir / "hooks.json", {"description": spec["description"], "hooks": hooks})

    for item in sorted(hook_dir.iterdir()):
        if item.name in HOOK_META or item.name in EXCLUDE_NAMES:
            continue
        copy_item(item, out_dir / item.name)
    copy_item(ADAPTER_DIR / "claude-hook-adapter.sh", out_dir / "claude-hook-adapter.sh")


def build_mcp(tool_names: list, out_path: pathlib.Path):
    servers = {}
    for name in tool_names:
        tool = load_yaml(ROOT / "tools" / f"{name}.yaml")
        if tool.get("type") != "mcp":
            sys.exit(f"tools/{name}.yaml: the Claude adapter only knows type: mcp")
        if tool["transport"] == "http":
            server = {"type": "http", "url": tool["url"]}
            if "headers" in tool:
                server["headers"] = tool["headers"]
        elif tool["transport"] == "stdio":
            server = {"command": tool["command"], "args": tool["args"]}
        else:
            sys.exit(f"tools/{name}.yaml: unknown transport '{tool['transport']}'")
        servers[name] = server
    # json.dumps(indent=2) expands every array; the hand-written .mcp.json files
    # kept short string arrays like "args" on one line. Collapse them back so
    # the generated file stays byte-identical to the original format.
    text = json.dumps({"mcpServers": servers}, indent=2, ensure_ascii=False)
    text = re.sub(
        r'\[\n\s+("(?:[^"\\]|\\.)*"(?:,\n\s+"(?:[^"\\]|\\.)*")*)\n\s+\]',
        lambda m: "[" + ", ".join(s.strip() for s in m.group(1).split(",\n")) + "]",
        text,
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text + "\n", encoding="utf-8")


def main():
    mp = load_yaml(ROOT / "marketplace.yaml")
    plugins_dir = ROOT / "plugins"
    if plugins_dir.exists():
        shutil.rmtree(plugins_dir)

    marketplace_entries = []
    for gname in mp["groups"]:
        gdir = ROOT / "skills" / gname
        group = load_yaml(gdir / "group.yaml")
        out = plugins_dir / gname

        write_json(
            out / ".claude-plugin" / "plugin.json",
            {
                "name": group["name"],
                "version": mp["version"],
                "description": group["description"],
                "author": mp["author"],
                "homepage": mp["homepage"],
                "repository": mp["repository"],
                "license": mp["license"],
                "keywords": group["keywords"],
            },
        )
        marketplace_entries.append(
            {"name": group["name"], "description": group["description"], "source": f"./plugins/{gname}"}
        )

        for skill_dir in sorted(gdir.iterdir()):
            if skill_dir.is_dir() and (skill_dir / "skill.yaml").exists():
                build_skill(skill_dir, out / "skills" / skill_dir.name)

        for extra in ("agents", "commands", "scripts"):
            if (gdir / extra).exists():
                copy_item(gdir / extra, out / extra)

        if group.get("tools"):
            build_mcp(group["tools"], out / ".mcp.json")

        if group.get("hooks"):
            build_hooks(ROOT / "hooks" / group["hooks"], out / "hooks")

    write_json(
        ROOT / ".claude-plugin" / "marketplace.json",
        {
            "name": mp["name"],
            "owner": mp["owner"],
            "metadata": {"description": mp["description"], "version": mp["version"]},
            "plugins": marketplace_entries,
        },
    )
    print(f"Generated {len(mp['groups'])} plugins under plugins/ and .claude-plugin/marketplace.json")


if __name__ == "__main__":
    main()
