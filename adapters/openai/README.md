# OpenAI adapter

Turns platform-neutral skills from `skills/` into an OpenAI assistant: system
instructions assembled from skill bodies, plus the skills' reference files as
a `file_search` knowledge store.

**Deprecation note.** The Assistants API is deprecated and shuts down on
August 26, 2026; OpenAI's replacement is the Responses API with the same
vector stores and `file_search` tool. This adapter emits both request shapes
so you can use whichever your stack is on, but target the Responses one for
anything new.

## What travels where

- `skill.yaml` description + `instructions.md` body: into the `instructions`
  text (capped at 256,000 characters by the API; the adapter warns beyond it).
- `references/`, `examples/`, and other skill resources: into a vector store
  the assistant searches at answer time, mirroring how file-native agents read
  them on demand. Only file types `file_search` accepts travel (`.md`,
  `.json`, `.txt`, code files); the adapter lists what it skipped.
- Hooks and MCP tools do not translate: an OpenAI assistant cannot run shell
  scripts or MCP servers from this repository. Wire equivalent checks into
  your own function tools if you need them.

## Build

```bash
python3 adapters/openai/build.py adapters/openai/examples/assistant-config.yaml
```

Writes to `dist/openai/assistant-config/`:

- `instructions.md`: the assembled instructions
- `assistant.json`: request body for `POST /v1/assistants` (legacy)
- `responses-request.json`: the equivalent Responses API skeleton
- `files-manifest.txt`: repo-relative resource files to upload

## Upload flow

1. Upload each file in the manifest:

   ```bash
   while read -r f; do
     curl -s https://api.openai.com/v1/files \
       -H "Authorization: Bearer $OPENAI_API_KEY" \
       -F purpose="assistants" -F file="@$f"
   done < dist/openai/assistant-config/files-manifest.txt
   ```

2. Create a vector store with the returned file ids:

   ```bash
   curl -s https://api.openai.com/v1/vector_stores \
     -H "Authorization: Bearer $OPENAI_API_KEY" -H "Content-Type: application/json" \
     -d '{"name": "power-bi-skills", "file_ids": ["file-...", "file-..."]}'
   ```

3. Put the vector store id into the generated request (replace
   `<your-vector-store-id>`), then either:

   - Responses API (current): send `responses-request.json` to
     `POST /v1/responses` with your user message in `input`; or
   - Assistants API (until 2026-08-26): send `assistant.json` to
     `POST /v1/assistants` with header `OpenAI-Beta: assistants=v2`.

## Caveats

- One vector store per assistant (`vector_store_ids` takes one id).
- Relative links inside skill bodies (`./references/...`) will not resolve as
  links for the model; the generated preamble tells it to find those files by
  name via `file_search` instead.
- Skills whose value is running local tools (the Tabular Editor CLI, TOM via
  PowerShell) read as documentation here; the assistant cannot execute them.
