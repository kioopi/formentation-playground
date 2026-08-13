# Milestone 3 — Elixir Map Mode

## Status

Planned; revisit after Milestone 2.

## Goal

Allow the playground to exercise Formentation's second built-in declaration source from editable text.

Note: since Milestones 1–2 are JSON Schema only, this milestone introduces the `:map` source into the playground entirely — Session `source` switching, parser, and examples all first appear here.

## Primary problem

A public playground must not evaluate arbitrary submitted Elixir code.

Do not use unrestricted:

```elixir
Code.eval_string(...)
Code.eval_quoted(...)
```

## Intended direction

Build a restricted literal parser around `Code.string_to_quoted/2`.

Allow only values required by Formentation Map declarations:

- maps;
- lists;
- literal tuples;
- strings;
- integers/floats;
- booleans;
- nil;
- a fixed allowlist of existing atoms.

Reject executable AST:

- local/remote calls;
- variables;
- aliases;
- captures;
- interpolation;
- sigils;
- comprehensions;
- arbitrary operators;
- struct construction;
- multiple-expression blocks.

Enforce input size, AST depth, and node-count limits.

## Presentation asymmetry

Do not force JSON Schema's `ui:` model onto the Map source.

Initial UI:

```text
JSON Schema:
  declaration     editable
  presentation    editable
  data            editable

Elixir Map:
  declaration     editable
  presentation    derived/read-only
  data            editable
```

Use this asymmetry as architectural evidence before considering a source-neutral presentation overlay in Formentation.

## Exit criteria

The user can switch between JSON Schema and Map examples and edit both safely through the same Session model.

Revisit the exact parser design, security limits, and presentation UI before implementation.
