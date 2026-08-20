# DAX

Skills and references for writing, debugging, and optimizing DAX in semantic models.

## Optimization

For systematic DAX query performance optimization, read the workflow reference first:

**[`references/dax-performance-optimization.md`](./references/dax-performance-optimization.md)** — Tiered framework (4 tiers), phased workflow, decision guide, and error handling.

Detailed reference files (progressive disclosure — consult as directed by the workflow):

- **[`references/engine-internals.md`](./references/engine-internals.md)** — FE/SE architecture, xmSQL, compression/segments, SE fusion, trace diagnostics
- **[`references/dax-patterns.md`](./references/dax-patterns.md)** — Tier 1 DAX patterns (DAX001–DAX021) + Tier 2 query structure (QRY001–QRY004)
- **[`references/model-optimization.md`](./references/model-optimization.md)** — Tier 3 model patterns (MDL001–MDL009) + Tier 4 Direct Lake (DL001–DL002)

Trace capture and performance profiling:

Trace capture needs an external tool; none is bundled with this repository.
When one is installed, use it: the Tabular Editor CLI (`te query`, locally or
with `-s <workspace> -d <model>` against a workspace XMLA endpoint), DAX
Studio, or a model MCP server. Without one, work from the pattern references
above: they identify the anti-patterns from the DAX text alone, and Power BI
Desktop's Performance Analyzer gives coarse timings for verification.

## Related Skills

- [`semantic-model`](../semantic-model/) — Model design, build, and auditing including DAX anti-patterns and best practices
- [`lineage-analysis`](../lineage-analysis/) — Impact analysis before model changes
