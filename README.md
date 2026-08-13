# Formentation Playground

An interactive Phoenix LiveView playground for [Formentation](https://github.com/kioopi/formentation).

The playground is intended to be more than a demo. It is the first real downstream application of Formentation and should serve four purposes at once:

1. **Exercise the public API from outside the Formentation repository.**
2. **Make declarations, presentation, compiled definitions, runtime state, diagnostics, and submission behavior inspectable.**
3. **Provide executable examples of supported and unsupported behavior.**
4. **Act as a design probe for future Formentation APIs.**

The application deliberately has **no database**. Interactive playground state lives in the LiveView process and is modeled as a plain Elixir struct (`Session`) transformed by pure functions in a `FrmnPlay.Playground` core module. Ash was considered and deliberately deferred: nothing is persisted or queried, most Session fields are opaque runtime values owned by Formentation, and a functional core provides the same seam with less machinery. Ash will be reconsidered when a resource earns it (e.g. a persisted example lifecycle or shared sessions).

## Current state

The repository already contains a working Phoenix application with Formentation installed as a real git dependency.

A basic form is compiled and initialized through the public Formentation API, rendered with the Phoenix integration, and exercised through the ordinary LiveView lifecycle:

```elixir
{:ok, form_state, diagnostics} =
  Formentation.form(declaration,
    adapter: :map,
    data: initial_data,
    defaults: :apply
  )
```

```elixir
form_state = Formentation.Form.validate(form_state, params)
```

```elixir
case Formentation.Form.submit(form_state, params) do
  {:ok, instance, submitted_form} ->
    # accepted submission

  {:error, submitted_form} ->
    # redisplay with errors/raw input
end
```

The repository also has LiveView tests and real-browser Playwright coverage.

## Planned playground model

The target user-facing pipeline is:

```text
Declaration
    +
Presentation
    +
Initial instance
    ↓
parse
    ↓
Formentation compile / form initialization
    ↓
Definition + diagnostics
    ↓
Formentation.Form
    ↓
Phoenix rendering
    ↓
validate / submit
    ↓
runtime state + candidate/submitted instance
```

**JSON Schema is the declaration source from the beginning** — including the built-in Milestone 1 example — because declaration, presentation hints, and initial data are all JSON documents and can be parsed safely without evaluating Elixir code. This also means the full parse → compile → apply loop is implemented and testable from the first milestone.

Elixir Map declarations will follow after the basic playground interaction model is stable (Milestone 3, via a restricted literal parser).

## Architecture

The playground core is plain Elixir; no persistence is required.

```text
FrmnPlay.Playground        public module — the only API the web layer calls
│
├── Session                plain struct + pure transformation functions
│   ├── current editor text (declaration / presentation / data)
│   ├── last accepted source documents (text + parsed)
│   ├── current Formentation.Form
│   ├── diagnostics (of the accepted form only)
│   ├── apply errors (of the latest apply attempt)
│   └── submission result
│
├── Example
│   └── built-in examples initially
│
├── Parser
│   ├── JSON
│   └── later restricted Elixir literals
│
└── Phoenix LiveView
    └── thin UI over Playground functions
```

`Formentation.Form` remains owned by Formentation. The playground orchestrates it; it does not duplicate its state model.

The Session has **no exclusive state attribute** (and no state machine). Playground state has several orthogonal dimensions — editor validity, dirty state, last successful compile, current preview runtime state, and submission state — so one lifecycle value would be misleading. These facts are represented directly and exposed through small derived-fact functions (`dirty?`, `has_preview?`, …).

Two invariants anchor the model:

1. **Editor text is not accepted state.** Invalid text in an editor is ordinary state and never destroys the last successfully compiled preview.
2. **Diagnostics always describe the rendered form.** A failed apply records its errors in `apply_errors` and never overwrites the accepted form's diagnostics.

## Documentation

- [Roadmap](docs/roadmap.md)
- [Milestone 1 — Session and Examples](docs/milestone-01-session-and-examples.md)
- [Milestone 2 — JSON Schema Playground MVP](docs/milestone-02-json-schema-playground.md)
- [Milestone 3 — Elixir Map Mode](docs/milestone-03-elixir-map-mode.md)
- [Milestone 4 — Definition Inspector](docs/milestone-04-definition-inspector.md)
- [Milestone 5 — Runtime Inspector](docs/milestone-05-runtime-inspector.md)
- [Milestone 6 — Presentation Skeleton Generation](docs/milestone-06-presentation-skeleton.md)
- [Milestone 7 — Dedicated Code Editors](docs/milestone-07-code-editors.md)
- [Milestone 8 — Sharing, Structured Editing, and Livebook](docs/milestone-08-sharing-and-livebook.md)

## Development principle

Prefer a sequence of small vertical slices.

Each milestone should exercise Formentation through its public API first. If the playground needs information or behavior that the public API cannot express cleanly, treat that as evidence for a possible Formentation change rather than reaching directly into internal structs.

The roadmap is intentionally revisited milestone by milestone. Only the next milestone is specified in implementation detail; later milestone documents are placeholders for direction and exit criteria.
