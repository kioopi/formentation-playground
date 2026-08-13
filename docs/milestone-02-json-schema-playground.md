# Milestone 2 — JSON Schema Playground MVP

## Status

Planned; revisit after Milestone 1.

## Revision note (2026-08-13)

Milestone 1 now includes JSON parsing, the JSON-Schema-sourced default
example, and the complete `apply_sources` loop with tests. This milestone
therefore shrinks to mostly **UI work**: exposing the already-tested
Session model through editable documents on the page.

## Goal

Turn the page from a fixed example into the first complete interactive
authoring workflow.

The user can edit:

- JSON Schema declaration;
- JSON presentation/UI hints;
- initial instance JSON;

then explicitly apply those documents and interact with the resulting
form.

## Target flow

```text
schema textarea
+ presentation textarea
+ instance textarea
        ↓
Apply button → Playground.apply_sources/1   (exists since M1)
        ↓
preview form + diagnostics                  (exists since M1)
        ↓
validate / submit                           (exists since M1)
```

## Intended scope

- plain `<textarea>` controls wired to `edit-declaration`,
  `edit-presentation`, `edit-data`;
- explicit Apply button wired to `apply-sources`;
- display of `apply_errors` (parse and compile failures);
- display of compile diagnostics of the accepted form;
- visible dirty indicator ("preview shows the last applied revision");
- example selector wired to `load-example`;
- reset control wired to `reset-session`;
- display of the submitted decoded instance;
- additional built-in JSON Schema examples;
- at least one intentionally unsupported example that produces
  diagnostics or apply errors.

## UX invariant

Temporarily invalid editor input must not destroy the currently rendered
preview. (The Session already guarantees this; the UI must communicate
it.)

The preview should clearly indicate when it represents the last
successfully applied revision rather than the current editor contents.

## Suggested examples

- Basic scalar fields.
- Talk proposal / grouped richer form (exists since Milestone 1).
- Unsupported array or unsupported JSON Schema feature.

## Non-goals

- Elixir source mode;
- dedicated code editor;
- auto-apply;
- JSON patches;
- Definition inspector;
- structured schema editor.

## Exit criteria

A user can start from an example, edit all three JSON documents, Apply
them, see parser/compiler diagnostics, fill the resulting live form, and
see the decoded submission result.

Before implementation, re-evaluate this document against the actual
Session API created in Milestone 1.
