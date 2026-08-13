# Milestone 7 — Dedicated Code Editors

## Status

Planned; revisit after Milestone 6.

## Goal

Replace plain textareas with dedicated editor components after editing/apply semantics are already proven.

## Preferred direction

Evaluate CodeMirror 6 first.

Desired capabilities:

- JSON syntax highlighting;
- Elixir syntax highlighting;
- formatting commands;
- server-side parser/compiler diagnostics rendered as editor markers;
- keyboard shortcuts;
- controlled replace semantics;
- optional debounced auto-apply.

## Principle

The editor is a UI adapter over the existing Session model.

It must not become the owner of accepted source state or compilation behavior.

## Defer

Do not introduce JSON Patch or diff synchronization unless full-text updates demonstrably become a problem.

## Exit criteria

The dedicated editor improves authoring ergonomics without changing the Session's established state semantics.

Re-evaluate editor library choice immediately before implementation.
