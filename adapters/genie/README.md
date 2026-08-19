# Databricks Genie adapter

Turns platform-neutral skills from `skills/` into a Databricks AI/BI Genie
space configuration: an assembled instruction text plus a ready-to-send
request body for the Genie spaces REST API.

## What Genie can and cannot take

A Genie space answers questions about Unity Catalog data on a SQL warehouse.
Its configurable surface is: title, description, one general text-instruction
block, example SQL queries, trusted SQL functions, and table metadata. There
is no file store and no tool execution, so from each skill only the
`skill.yaml` description and the `instructions.md` body travel. The
`references/` and `examples/` directories, hooks, and MCP tools stay behind.

Limits to respect (from the Genie API docs):

- One text instruction per space; this adapter emits exactly one.
- 25,000 characters per string element; multi-line text travels as an array
  of line strings, which this adapter produces.
- The whole space shares a token budget; the UI warns as you approach it.
  The adapter warns beyond `max_chars` (default 20,000 characters) as a
  rough proxy. Keep the skill list short and prefer skills whose bodies are
  guidance rather than link indexes.

## Build

```bash
python3 adapters/genie/build.py adapters/genie/examples/space-config.yaml
```

Writes to `dist/genie/space-config/`:

- `instructions.md`: the assembled text. For the UI path, paste it into
  Configure > Instructions in your Genie space.
- `space.json`: a request body for the spaces API.

## Apply via the REST API

```bash
databricks api post /api/2.0/genie/spaces --json @dist/genie/space-config/space.json
```

To update an existing space, PATCH it (fetch the `etag` from a GET first if
you want optimistic locking):

```bash
databricks api patch /api/2.0/genie/spaces/<space-id> \
  --json @dist/genie/space-config/space.json
```

## Caveats

- The `serialized_space` payload targets schema version 2 as documented for
  the Genie API. Databricks documents the top-level request fields, but not
  every nested field; if a create call is rejected, fetch a known-good space
  with `GET /api/2.0/genie/spaces/<space-id>?include_serialized_space=true`
  and compare shapes.
- `space.json` sets only the text instruction. Add tables
  (`data_sources.tables`), example SQL, and trusted functions in the UI or by
  extending the payload; those need knowledge of your catalog and have no
  counterpart in this repository's skills.
- Databricks recommends text instructions as a last resort, with example SQL
  and SQL functions preferred. These skills are prose-first by nature; expect
  to complement them with example queries for your own data.
