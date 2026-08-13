# Roadmap

## Purpose

The playground should evolve from the current hard-coded form example into an interactive environment that exposes the complete Formentation lifecycle.

The roadmap is intentionally incremental. Later milestones describe direction rather than frozen designs and should be re-evaluated against the state of both repositories before implementation starts.

## Guiding principles

- Exercise Formentation as a real external dependency.
- Prefer public APIs over internal struct inspection.
- Keep Phoenix LiveViews thin.
- Keep the core plain Elixir; defer frameworks (including Ash) until a
  resource demonstrably earns them.
- Keep `Formentation.Form` authoritative for form runtime behavior.
- Keep editor text distinct from last successfully accepted/compiled state.
- Preserve the last good preview when editor input is temporarily invalid.
- Do not introduce persistence before a concrete use case needs it.
- Do not introduce client-side diff/patch protocols before whole-document replacement becomes a demonstrated problem.
- Let the playground expose architectural gaps rather than papering over them.

## Milestone overview

### Milestone 1 — Session and Examples

Introduce the application model that all later playground behavior will use.

Key outcomes:

- `FrmnPlay.Playground` public module (plain Elixir; Ash deliberately deferred).
- non-persistent `Session` struct with pure transformation functions.
- `Example` model and built-in example registry.
- the current proposal example converted to JSON Schema source and moved behind this model.
- JSON parsing and the full `apply_sources` loop (parse → compile → replace accepted state), tested directly.
- intent-named functions for editing, applying, preview validation/submission, loading examples, and reset.
- explicit distinction between editor state and accepted/compiled state.
- failed applies never overwrite the accepted form or its diagnostics.
- LiveView reduced to UI/event orchestration.

This milestone is specified in detail in [milestone-01-session-and-examples.md](milestone-01-session-and-examples.md).

---

### Milestone 2 — JSON Schema Playground MVP

Expose the Session model (built and tested in Milestone 1) through the
first complete authoring UI:

```text
JSON Schema
+ UI hints
+ instance JSON
→ Apply
→ compile/init
→ preview
→ validate/submit
→ diagnostics/result
```

Plain textareas are sufficient.

See [milestone-02-json-schema-playground.md](milestone-02-json-schema-playground.md).

---

### Milestone 3 — Elixir Map Mode

Add a second declaration source without evaluating arbitrary code.

Main addition:

- restricted Elixir literal parser;
- the `:map` source itself (Milestones 1–2 are JSON Schema only);
- source switch between `:json_schema` and `:map`;
- map presentation exposed honestly as inline/derived rather than forcing JSON-style UI hints onto the adapter.

See [milestone-03-elixir-map-mode.md](milestone-03-elixir-map-mode.md).

---

### Milestone 4 — Definition Inspector

Expose a stable, JSON-safe, read-only view of the compiled definition through public `Formentation.Info` queries.

The playground should not present raw `%Formentation.Definition{}` storage as a public serialization format.

See [milestone-04-definition-inspector.md](milestone-04-definition-inspector.md).

---

### Milestone 5 — Runtime Inspector

Make live form behavior observable:

- candidate;
- original data;
- raw/display values;
- issues;
- usage state;
- submission status;
- submitted instance.

See [milestone-05-runtime-inspector.md](milestone-05-runtime-inspector.md).

---

### Milestone 6 — Presentation Skeleton Generation

Generate useful JSON Schema UI-hints starting points from the compiled/default presentation.

Use this milestone to test whether current Formentation presentation/introspection APIs expose enough information.

See [milestone-06-presentation-skeleton.md](milestone-06-presentation-skeleton.md).

---

### Milestone 7 — Dedicated Code Editors

Replace textareas with editor components once interaction semantics are stable.

Expected direction:

- CodeMirror 6 first;
- syntax highlighting;
- formatting;
- server diagnostics mapped into editor markers;
- optional auto-apply with debounce.

See [milestone-07-code-editors.md](milestone-07-code-editors.md).

---

### Milestone 8 — Sharing, Structured Editing, and Livebook

Explore larger usability improvements only after the core model has been exercised.

Possible work:

- import/export bundles;
- shareable URLs or temporary shared sessions;
- structured JSON Schema/presentation editors;
- Livebook integration / Smart Cell;
- source comparison tooling;
- possibly client-side/offline experiments.

See [milestone-08-sharing-and-livebook.md](milestone-08-sharing-and-livebook.md).

## Dependency graph

```text
M1 Session + Examples
        ↓
M2 JSON Schema MVP
        ↓
M3 Elixir Map Mode
        ↓
M4 Definition Inspector
        ↓
M5 Runtime Inspector
        ↓
M6 Presentation Skeleton
        ↓
M7 Dedicated Editors
        ↓
M8 Sharing / Structured UI / Livebook
```

This is an ordering recommendation, not a strict prohibition on small independent experiments.

One known candidate for reordering: the Runtime Inspector (M5) needs no new
Formentation API and delivers immediate user value, while the Definition
Inspector (M4) is primarily a probe for public `Formentation.Info` API gaps.
Swapping M4 and M5 is a legitimate outcome of the re-evaluation rule.

## What is deliberately not on the critical path

The following may become useful later, but should not shape the first milestones:

- JSON Patch / diff synchronization;
- browser-local Elixir execution;
- a visual JSON Schema editor;
- persistent user accounts or database storage;
- collaboration;
- a general-purpose Formentation definition serialization format;
- theme/plugin systems;
- Ash (or any framework layer) for the playground core — deferred until a
  resource earns it, e.g. a persisted example lifecycle or shared sessions;
- reimplementation of `Formentation.Form` state inside the Session.

## Re-evaluation rule

Before starting each milestone after Milestone 1:

1. inspect the current playground;
2. inspect the current Formentation release/main branch;
3. review what the previous milestone taught us;
4. update the milestone document before implementing it.
