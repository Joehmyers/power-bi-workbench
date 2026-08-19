#!/usr/bin/env python3
"""Databricks Genie adapter: assemble skills into a Genie space configuration.

Reads a space config (see examples/space-config.yaml) that names the skills to
include, and writes to dist/genie/<config-name>/:

  instructions.md   the assembled instruction text, ready to paste into the
                    Genie space UI (Configure > Instructions)
  space.json        a request body for POST /api/2.0/genie/spaces, with the
                    same text embedded as the space's single text instruction

Genie has no file store, so only skill.yaml descriptions and instructions.md
bodies travel; references/ and examples/ directories do not. Pick a small set
of skills. Genie converts instructions to tokens against a space-wide budget
and warns in the UI as you approach it; this script warns beyond
`max_chars` (default 20000) as a rough proxy for that budget.

Usage: python3 adapters/genie/build.py <config.yaml>   (from the repo root)
"""

import hashlib
import json
import pathlib
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

# Per the Genie API docs, individual string elements are capped at 25,000
# characters; multi-line text travels as an array of line strings.
GENIE_STRING_LIMIT = 25000


def load_skill(ref: str):
    """ref is '<group>/<skill>', e.g. 'semantic-models/dax'."""
    sdir = ROOT / "skills" / ref
    if not (sdir / "skill.yaml").exists():
        sys.exit(f"unknown skill '{ref}' (no skills/{ref}/skill.yaml)")
    spec = yaml.safe_load((sdir / "skill.yaml").read_text(encoding="utf-8"))
    body = (sdir / spec.get("instructions", "instructions.md")).read_text(encoding="utf-8")
    return spec, body


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    config_path = pathlib.Path(sys.argv[1])
    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    out_dir = ROOT / "dist" / "genie" / config_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    sections = [
        f"# {config['title']}",
        "",
        config.get("preamble", "You are a Power BI development assistant. Follow the skill guidance below."),
        "",
    ]
    for ref in config["skills"]:
        spec, body = load_skill(ref)
        sections += [f"## Skill: {spec['name']}", "", spec["description"], "", body.rstrip(), ""]
    text = "\n".join(sections)

    (out_dir / "instructions.md").write_text(text, encoding="utf-8")

    max_chars = config.get("max_chars", 20000)
    if len(text) > max_chars:
        print(
            f"WARNING: instructions are {len(text)} characters (over max_chars={max_chars}). "
            "Genie budgets tokens per space; trim the skill list or the bodies."
        )
    for line in text.split("\n"):
        if len(line) > GENIE_STRING_LIMIT:
            print(f"WARNING: one line exceeds Genie's {GENIE_STRING_LIMIT}-character string limit.")
            break

    # Deterministic 32-hex id, derived from the title so reruns are stable.
    instruction_id = hashlib.md5(config["title"].encode("utf-8")).hexdigest()
    serialized_space = {
        "version": 2,
        "instructions": {
            "text_instructions": [{"id": instruction_id, "content": text.split("\n")}]
        },
    }
    space = {
        "warehouse_id": config.get("warehouse_id", "<your-warehouse-id>"),
        "title": config["title"],
        "description": config.get("description", ""),
        "serialized_space": json.dumps(serialized_space, ensure_ascii=False),
    }
    (out_dir / "space.json").write_text(
        json.dumps(space, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Wrote {out_dir}/instructions.md ({len(text)} chars) and {out_dir}/space.json")


if __name__ == "__main__":
    main()
