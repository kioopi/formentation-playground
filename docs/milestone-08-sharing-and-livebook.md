# Milestone 8 — Sharing, Structured Editing, and Livebook

## Status

Future direction; revisit much later.

## Goal

Explore larger usability features once the core playground is stable and useful.

## Candidate work

### Import/export bundles

A portable playground document containing:

- source mode;
- declaration;
- presentation;
- initial data;
- possibly metadata such as example/title.

Do not include opaque runtime Form/Definition artifacts.

### Shareable sessions

Possible implementations:

- URL-encoded small bundles;
- temporary ETS-backed shared sessions;
- persistent storage only if a concrete requirement emerges.

### Structured editors

Potential visual editors for:

- JSON Schema;
- presentation/UI hints;
- initial data.

Any schema editor should distinguish:

```text
valid JSON Schema
≠
currently editable/renderable by Formentation
```

### Source comparison

Show equivalent JSON Schema and Map declarations side by side and compare:

- semantic meaning;
- presentation;
- origins;
- diagnostics;
- runtime behavior.

This can become a strong demonstration of Formentation's source-neutral architecture.

### Livebook

Build a tutorial/debugging companion rather than replacing the Phoenix playground.

Potential direction:

- Kino Smart Cell;
- declaration/presentation/data editing;
- compile/inspect workflow;
- generated ordinary Elixir code for reproducible examples.

### Browser-local experiments

Popcorn or similar technology may be explored separately for offline/client-side Elixir execution.

Do not make this a dependency of the primary playground without a strong use case.

## Exit criteria

Undefined until the milestone is revisited.

This document intentionally records possibilities rather than a committed implementation plan.
