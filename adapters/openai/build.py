#!/usr/bin/env python3
"""OpenAI adapter: assemble skills into an OpenAI assistant configuration.

Reads an assistant config (see examples/assistant-config.yaml) that names the
skills to include, and writes to dist/openai/<config-name>/:

  instructions.md         the assembled system instructions
  assistant.json          request body for POST /v1/assistants (Assistants
                          API v2; deprecated, sunset 2026-08-26)
  responses-request.json  the equivalent Responses API request skeleton
                          (the current, supported target)
  files-manifest.txt      skill resource files to upload for file_search,
                          one repo-relative path per line

Skill descriptions and instruction bodies go into the instructions text.
Resource files (references/, examples/) go into a vector store for
file_search, mirroring how file-native agents read them on demand. Only file
types file_search accepts are listed (.md .json .txt and common code files);
anything else is skipped with a note.

Usage: python3 adapters/openai/build.py <config.yaml>   (from the repo root)
"""

import json
import pathlib
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

# POST /v1/assistants caps instructions at 256,000 characters.
INSTRUCTIONS_LIMIT = 256000

# File extensions file_search accepts (from the OpenAI file-search docs).
FILE_SEARCH_EXTS = {
    ".c", ".cs", ".cpp", ".css", ".doc", ".docx", ".html", ".java", ".js",
    ".json", ".md", ".pdf", ".php", ".pptx", ".py", ".rb", ".sh", ".tex",
    ".ts", ".txt",
}


def load_skill(ref: str):
    """ref is '<group>/<skill>', e.g. 'semantic-models/dax'."""
    sdir = ROOT / "skills" / ref
    if not (sdir / "skill.yaml").exists():
        sys.exit(f"unknown skill '{ref}' (no skills/{ref}/skill.yaml)")
    spec = yaml.safe_load((sdir / "skill.yaml").read_text(encoding="utf-8"))
    body = (sdir / spec.get("instructions", "instructions.md")).read_text(encoding="utf-8")
    return sdir, spec, body


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    config_path = pathlib.Path(sys.argv[1])
    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    out_dir = ROOT / "dist" / "openai" / config_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    sections = [
        config.get("preamble", "You are a Power BI development assistant. Follow the skill guidance below."),
        "",
    ]
    if config.get("include_resources", True):
        sections += [
            "Relative links in the skill sections point at resource files; the same",
            "files are in your file_search store, so search for them by name.",
            "",
        ]
    resources, skipped = [], []
    for ref in config["skills"]:
        sdir, spec, body = load_skill(ref)
        sections += [f"## Skill: {spec['name']}", "", spec["description"], "", body.rstrip(), ""]
        if config.get("include_resources", True):
            for item in sorted(sdir.rglob("*")):
                if not item.is_file() or item.name in ("skill.yaml",):
                    continue
                rel = item.relative_to(ROOT)
                if item.suffix.lower() in FILE_SEARCH_EXTS:
                    resources.append(str(rel))
                else:
                    skipped.append(str(rel))
    text = "\n".join(sections)

    (out_dir / "instructions.md").write_text(text, encoding="utf-8")
    if len(text) > INSTRUCTIONS_LIMIT:
        print(
            f"WARNING: instructions are {len(text)} characters; the API caps them at "
            f"{INSTRUCTIONS_LIMIT}. Trim the skill list."
        )

    manifest = "\n".join(resources) + "\n" if resources else ""
    (out_dir / "files-manifest.txt").write_text(manifest, encoding="utf-8")
    if skipped:
        print(f"Skipped {len(skipped)} resource files with types file_search rejects, e.g.:")
        for s in skipped[:5]:
            print(f"  {s}")

    tools = [{"type": "file_search"}] if resources else []
    assistant = {
        "model": config.get("model", "gpt-4.1"),
        "name": config["name"],
        "description": config.get("description", ""),
        "instructions": text,
        "tools": tools,
    }
    if resources:
        assistant["tool_resources"] = {"file_search": {"vector_store_ids": ["<your-vector-store-id>"]}}
    (out_dir / "assistant.json").write_text(
        json.dumps(assistant, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    responses = {
        "model": config.get("model", "gpt-4.1"),
        "instructions": text,
        "input": "<user message>",
    }
    if resources:
        responses["tools"] = [{"type": "file_search", "vector_store_ids": ["<your-vector-store-id>"]}]
    (out_dir / "responses-request.json").write_text(
        json.dumps(responses, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    print(
        f"Wrote {out_dir}/: instructions.md ({len(text)} chars), assistant.json, "
        f"responses-request.json, files-manifest.txt ({len(resources)} files)"
    )


if __name__ == "__main__":
    main()
