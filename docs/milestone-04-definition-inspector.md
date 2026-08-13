# Milestone 4 — Definition Inspector

## Status

Planned; revisit after Milestone 3.

## Goal

Make the output of compilation understandable without establishing the physical `%Formentation.Definition{}` struct as a public serialization format.

## Direction

Produce a read-only JSON-safe inspection projection using public `Formentation.Info` / layout queries wherever possible.

Conceptually:

```json
{
  "semantic": {},
  "presentation": {},
  "diagnostics": [],
  "validation": {}
}
```

The exact schema is intentionally not fixed yet.

## Important constraint

Do not implement the inspector as:

```elixir
inspect(definition)
Jason.encode!(definition)
```

The inspector is a diagnostic/read model, not a round-trippable Definition file format.

## Questions this milestone should answer

- Does `Formentation.Info` expose enough semantic information?
- Does the layout query API expose enough presentation information?
- Can provenance/origins be explained cleanly?
- Which validation metadata can be shown without leaking opaque adapter-owned artifacts?
- Is there a useful generic inspection projection that belongs in Formentation itself?

## Exit criteria

A user can understand what Formentation compiled from either source without depending on internal Definition storage.

Re-specify this milestone after the two editable source modes exist.
