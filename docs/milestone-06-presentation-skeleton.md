# Milestone 6 — Presentation Skeleton Generation

## Status

Planned; revisit after Milestone 5.

## Goal

Generate a useful starting UI-hints document for JSON Schema declarations.

## Initial direction

Support at least two modes:

### Minimal

Generate only what is needed to preserve meaningful non-default presentation intent.

### Expanded

Expose resolved presentation decisions for easier exploration/editing.

A simple initial skeleton may look like:

```json
{
  "order": ["name", "email", "notes"],
  "groups": [],
  "fields": {}
}
```

## Design role

This milestone is a test of Formentation's presentation introspection surface.

If the playground cannot generate a useful skeleton through public APIs, document the missing information before considering changes to Formentation.

## Non-goal

Do not invent a source-neutral presentation file format for the Map adapter in this milestone unless previous usage has established a concrete need.

## Exit criteria

A JSON Schema example can generate a valid, editable presentation starting point from its compiled/default layout.

Re-specify the algorithm and ownership before implementation.
