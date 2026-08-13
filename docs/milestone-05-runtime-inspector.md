# Milestone 5 — Runtime Inspector

## Status

Planned; revisit after Milestone 4.

## Goal

Make `Formentation.Form` behavior observable while keeping Formentation authoritative for runtime semantics.

## Candidate views

- Original instance
- Current candidate
- Raw/display values
- Issues
- Usage state
- Submission status/blockers
- Current action
- Last submitted instance

## Key demonstration

An input such as:

```text
duration_minutes = "45x"
```

should visibly demonstrate:

```text
raw browser value exists
candidate cannot contain a decoded integer
decode issue exists
rendered form preserves the raw text
```

## Constraint

Do not copy Form internals into Session fields merely to display them.

Build the inspector as a projection of the current `%Formentation.Form{}` through public APIs.

## Exit criteria

The playground can explain why a form is or is not submittable and how raw input, candidate data, issues, and submission decisions relate.

Revisit against current Formentation runtime APIs before implementation.
