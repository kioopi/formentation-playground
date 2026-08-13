# Milestone 2 — JSON Schema Playground MVP

## Status

Planned; revisit after Milestone 1.

## Goal

Turn the application from a fixed example into the first complete interactive authoring workflow.

The user can edit:

- JSON Schema declaration;
- JSON presentation/UI hints;
- initial instance JSON;

then explicitly apply those documents and interact with the resulting form.

## Target flow

```text
schema text
+ presentation text
+ instance text
        ↓
Apply
        ↓
Jason decode
        ↓
Formentation.form(
  schema,
  adapter: :json_schema,
  ui: presentation,
  data: instance
)
        ↓
preview form + diagnostics
        ↓
validate / submit
```

## Intended scope

- plain `<textarea>` controls;
- explicit Apply button;
- JSON parsing errors;
- Formentation diagnostics;
- last-good-preview behavior from Milestone 1;
- submitted decoded instance;
- example selector;
- at least one intentionally unsupported example.

## UX invariant

Temporarily invalid editor input must not destroy the currently rendered preview.

The preview should clearly indicate when it represents the last successfully applied revision.

## Suggested examples

- Basic scalar fields.
- Talk proposal / grouped richer form.
- Unsupported array or unsupported JSON Schema feature.

## Non-goals

- Elixir source mode;
- dedicated code editor;
- auto-apply;
- JSON patches;
- Definition inspector;
- structured schema editor.

## Exit criteria

A user can start from an example, edit all three JSON documents, Apply them, see parser/compiler diagnostics, fill the resulting live form, and see the decoded submission result.

Before implementation, re-evaluate this document against the actual Session API created in Milestone 1.
