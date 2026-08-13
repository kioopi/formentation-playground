# Milestone 1 — Session and Examples

## Status

Planned.

## Revision note (2026-08-13)

This document was revised after review. Two decisions changed its shape:

1. **Ash is deferred.** The Session is a plain Elixir struct with pure
   functions, not an Ash resource. See [Ash decision](#ash-decision).
2. **JSON Schema is the source from the beginning.** The original plan kept
   the Map-source example in Milestone 1 while deferring the restricted
   Elixir literal parser to Milestone 3 — which made the central
   `apply_sources` action untestable on its success path (there was no safe
   way to parse Map declaration text). JSON parsing is cheap (`Jason` is
   already a dependency), so the built-in example is converted to JSON
   Schema and the full apply loop becomes genuinely testable in this
   milestone. The Map source moves entirely to Milestone 3.

Two smaller findings are also pinned here:

- Failed applies must never overwrite the diagnostics of the last good
  compile. See [Diagnostics ownership](#diagnostics-ownership).
- The Session stores both the accepted source *text* and the parsed value
  per document; the earlier draft contained two conflicting field lists and
  now contains one.

## Goal

Introduce the application/domain model that all later playground features
will use, without changing the basic behavior that already works.

At the end of this milestone:

- the current proposal form still renders and submits;
- the LiveView no longer owns the playground's domain behavior;
- a plain-Elixir Playground module exposes named functions for manipulating
  a non-persistent Session;
- built-in examples are represented explicitly, authored as JSON Schema;
- editor state and last successfully applied state are separate concepts;
- the full apply loop (parse → compile → replace accepted state) is
  implemented and tested for JSON documents;
- the model is ready for the authoring UI in Milestone 2.

This milestone is about **state ownership and action boundaries**, not
about adding editors yet.

---

## Why do this before the authoring UI?

The current `ProposalFormLive` is a good vertical proof, but it owns:

- declaration data;
- compilation/form initialization;
- diagnostics;
- current `Formentation.Form`;
- validation;
- submission;
- submitted result;
- rendering.

That is appropriate for a first example, but it will become difficult to
maintain once the page also owns:

- three editor documents;
- parser errors;
- dirty state;
- last successfully accepted documents;
- examples;
- source switching;
- definition/runtime inspectors;
- presentation generation.

The milestone creates the seam first.

---

# Architecture

## Target structure

```text
lib/
├── frmn_play/
│   └── playground/
│       ├── playground.ex      # public API (the only module the web layer calls)
│       ├── session.ex         # Session struct + derived facts
│       ├── example.ex         # Example struct
│       ├── examples.ex        # built-in example registry
│       └── parser.ex          # source-text parsing boundary
└── frmn_play_web/
    └── live/
        └── playground_live.ex
```

Exact filenames may vary, but responsibilities should remain separated.

Conceptually:

```text
Phoenix LiveView
      │
      │ calls public functions
      ▼
FrmnPlay.Playground
      │
      ├── Session transformations
      │
      └── Example lookup
      │
      ▼
Formentation public API
```

---

# Ash decision

## Defer Ash

Model the Session as a plain Elixir struct and the Playground as a module
of pure functions.

Reasoning, recorded so the decision can be revisited honestly:

- The Session is process-local state held in the LiveView socket. Nothing
  is persisted, queried, filtered, or authorized.
- Most of its fields would be opaque `:term` attributes (notably
  `%Formentation.Form{}`, a runtime object owned by another library).
- The "calculations" it needs (`dirty?`, `has_preview?`, …) are trivial
  one-line functions over those fields.
- Ash 3 can model this (data-layer-less resources, update actions on
  unpersisted records), but at this stage the framework would provide
  little beyond ceremony while adding a learning/maintenance surface to
  every later milestone.

A plain functional core delivers the same seam in less code:

```text
socket.assigns.session
        ↓
Playground function
        ↓
updated %Session{}
        ↓
assign back to socket
```

**Reconsider Ash when a resource earns it** — for example, if `Example`
gains a real lifecycle (draft → reviewed → published), if sessions become
shareable/persistent (Milestone 8), or if a future milestone needs Ash's
introspection for its own sake. Record the trigger in the relevant
milestone document before introducing the dependency.

The same reasoning retires the earlier `AshStateMachine` question: the
Session has orthogonal facts (editor validity, dirty state, last good
compile, submission state) that must not be collapsed into one exclusive
state attribute — regardless of framework. Derived facts stay derived:

```text
declaration_dirty?
presentation_dirty?
data_dirty?
dirty?
has_preview?
has_apply_errors?
has_diagnostics?
has_submission?
```

---

# Core domain concepts

## `FrmnPlay.Playground`

The public application API for playground actions. The LiveView calls
these functions and nothing else in the `frmn_play` core.

```elixir
defmodule FrmnPlay.Playground do
  alias FrmnPlay.Playground.Session

  @spec start_session() :: Session.t()
  @spec edit_declaration(Session.t(), String.t()) :: Session.t()
  @spec edit_presentation(Session.t(), String.t()) :: Session.t()
  @spec edit_data(Session.t(), String.t()) :: Session.t()
  @spec apply_sources(Session.t()) :: Session.t()
  @spec validate_preview(Session.t(), map()) :: Session.t()
  @spec submit_preview(Session.t(), map()) :: Session.t()
  @spec load_example(Session.t(), String.t()) :: Session.t()
  @spec reset_session(Session.t()) :: Session.t()
end
```

Every function returns an updated `%Session{}`. User-caused failures
(unparsable text, compile errors) are recorded *inside* the Session
(`apply_errors`), not returned as error tuples — a failed apply is normal
playground state, not an application error. Reserve raising/`{:error, _}`
for programmer errors such as an unknown example id.

Treat names/signatures as illustrative. Prefer clear intent over CRUD
terminology.

---

# Session model

## Principle: current editor text is not accepted source state

This is the most important invariant in the milestone.

While typing, invalid text is ordinary state.

Example:

```json
{
  "type": "object",
  "properties":
```

The playground must be able to store that text without destroying the
currently rendered form.

Therefore the Session has two conceptual layers:

```text
CURRENT EDITOR STATE
    declaration text
    presentation text
    data text
    parse/apply attempt errors

LAST ACCEPTED STATE
    accepted source texts
    parsed declaration / presentation / data
    compile diagnostics
    current Formentation.Form
```

The first layer changes frequently. The second layer changes only after a
successful apply operation.

## Session struct

One field list, used consistently:

```elixir
defmodule FrmnPlay.Playground.Session do
  @enforce_keys [:source, :example_id]

  defstruct [
    :source,                      # :json_schema (the only value in M1)
    :example_id,                  # id of the currently loaded example

    # Current editable source documents
    :declaration_text,
    :presentation_text,
    :data_text,

    # Last accepted revision — text and parsed value per document
    :accepted_declaration_text,
    :accepted_presentation_text,
    :accepted_data_text,
    :accepted_declaration,
    :accepted_presentation,
    :accepted_data,

    # Result of compiling/initializing the accepted revision
    :form,                        # %Formentation.Form{} or nil
    diagnostics: [],              # compile diagnostics of the ACCEPTED form only

    # Result of the most recent apply attempt on current editor contents
    apply_errors: [],

    # Last accepted submission result
    submitted: nil
  ]
end
```

### Why store both accepted text and parsed values?

Because:

```json
{"type":"object"}
```

and:

```json
{
  "type": "object"
}
```

are semantically equivalent documents but not the same editor revision.
Dirty state must reflect editor revisions, not semantic equality:

```elixir
def declaration_dirty?(%Session{} = s),
  do: s.declaration_text != s.accepted_declaration_text
```

The duplication is intentional: comparison stays unambiguous and
formatting-preserving. The same pattern applies to presentation and data.

### `%Formentation.Form{}` stays opaque

Do **not** mirror the internals of `%Formentation.Form{}` into Session
fields. The Session orchestrates the form; Formentation owns its state
model.

## Diagnostics ownership

**Pinned rule:** `diagnostics` always describes the currently rendered
(accepted) form. A failed apply writes only to `apply_errors` and must not
touch `diagnostics`.

If a failed apply overwrote `diagnostics`, the last-good preview would be
displayed alongside diagnostics that do not describe it. This invariant
gets its own test (see below).

## Optional refinement: editor value object

If repeated editor handling becomes awkward, introduce a value struct
later:

```elixir
%EditorState{text: "...", accepted_text: "...", errors: []}
```

Do not normalize preemptively; wait until the implementation demonstrates
a real benefit.

---

# Example model

## Goal

Remove built-in examples from LiveView module attributes and make them
first-class application data.

Examples are static and do not require persistence.

```elixir
defmodule FrmnPlay.Playground.Example do
  @enforce_keys [
    :id,
    :title,
    :source,
    :declaration_text,
    :presentation_text,
    :data_text
  ]

  defstruct [
    :id,
    :title,
    :description,
    :source,
    :declaration_text,
    :presentation_text,
    :data_text
  ]
end
```

With a simple registry:

```elixir
Examples.default()
Examples.get!("talk-proposal")
Examples.all()
```

## Initial example: `talk-proposal`, converted to JSON Schema

The current hard-coded Map declaration is converted into three JSON
documents:

- a **JSON Schema declaration**;
- a **presentation/UI-hints document** (groups, widgets, help text);
- an **initial instance document** (`{"track": "Elixir"}`).

The example should preserve the user-visible behavior already covered by
the existing tests:

- string input;
- string options/select;
- radio widget;
- textarea;
- integer default;
- email role (`format: "email"`);
- date role (`format: "date"`);
- boolean;
- nested object;
- presentation groups;
- successful submit;
- raw invalid numeric input preservation.

### The conversion is itself a design probe

Whether every feature above is expressible through Formentation v0.2.0's
`:json_schema` adapter plus UI hints is exactly the kind of question this
playground exists to answer. If a feature cannot be expressed:

1. record the gap explicitly (a candidate Formentation finding);
2. adapt the example/tests deliberately and visibly — do not silently
   weaken assertions.

Verify the actual `Formentation.form/2` options for the JSON Schema source
(e.g. how presentation hints are passed) against the installed release
before writing the example.

---

# Session actions

## `start_session`

Creates a new Session from the default Example.

Responsibilities:

1. choose the default example;
2. populate editor text from the example documents;
3. parse and compile them (this is `apply_sources` applied to a fresh
   session — reuse the same code path);
4. store accepted texts/values, form, and diagnostics;
5. ensure the returned Session is immediately renderable.

Built-in examples are expected to parse and compile; if one does not, that
is a bug in the example, and raising is acceptable.

---

## `edit_declaration` / `edit_presentation` / `edit_data`

Input: the new text.

Effect: replace the corresponding current editor text. Nothing else.

Must **not**:

- parse;
- compile;
- replace the accepted documents;
- replace the current form;
- clear the current preview.

These functions model editing, not applying.

---

## `apply_sources`

The central action of the Session model.

```text
current editor texts
        ↓
parse each document (JSON)
        ↓
if any parse fails:
    keep accepted state unchanged
    keep current form unchanged
    keep diagnostics unchanged        ← pinned rule
    record apply_errors
        ↓
Formentation.form(declaration, adapter: :json_schema, ...)
        ↓
if compilation fails:
    keep accepted state unchanged
    keep current form unchanged
    keep diagnostics unchanged        ← pinned rule
    record apply_errors (containing the compile errors)

if compilation succeeds:
    replace accepted texts and parsed values
    replace current form
    replace diagnostics
    clear apply_errors
    clear stale submitted result
```

### A failed apply is normal Session state

For an interactive playground this is a normal outcome:

```text
"Your current text cannot be applied.
The preview still shows the last successful version."
```

The function returns an updated Session containing `apply_errors`; it does
not return an error tuple.

---

## `validate_preview`

Input: form params.

Precondition: a current `%Formentation.Form{}` exists.

```elixir
new_form = Formentation.Form.validate(session.form, params)
```

Return a Session with `form` replaced and — per the pinned policy below —
`submitted` cleared.

### Submission-result policy

**Pinned:** any preview validation after a successful submission clears
`submitted`. Once the user edits the form again, the old submitted
instance no longer describes the current preview. Pin this behavior in a
test.

---

## `submit_preview`

Input: form params.

```elixir
case Formentation.Form.submit(session.form, params) do
  {:ok, instance, submitted_form} ->
    %{session | form: submitted_form, submitted: instance}

  {:error, submitted_form} ->
    %{session | form: submitted_form, submitted: nil}
end
```

Do not derive success independently from candidate/issues. Use the public
Formentation submission decision.

---

## `load_example`

Input: example id.

Semantics:

- immediately replace editor text with the selected example;
- immediately parse/compile it (same code path as `start_session`);
- replace accepted state, form, and diagnostics;
- clear apply errors and submitted result.

Do not preserve dirty edits when switching examples in the first
implementation. Later the UI may warn about unsaved editor contents if
that becomes useful.

---

## `reset_session`

Reset the current Session to the currently selected example's baseline.
Equivalent to `load_example(session, session.example_id)`.

If "reset editor" and "reset preview form" later need separate meanings,
split the functions then.

---

# Parsing boundary

Milestone 1 implements the JSON parser; Milestone 3 adds the restricted
Elixir parser behind the same boundary.

```elixir
defmodule FrmnPlay.Playground.Parser do
  def parse_declaration(:json_schema, text), do: ...   # Jason.decode
  def parse_presentation(:json_schema, text), do: ...  # Jason.decode
  def parse_data(text), do: ...                        # Jason.decode
end
```

`parse_data/1` deliberately takes no source argument: instance data is
always JSON, in every source mode.

Parse errors should carry enough structure for later UI needs (document
name, message; line/column when Jason provides position information).
Avoid prematurely choosing a schema that cannot represent both parser
errors and Formentation compile errors — both end up in `apply_errors`.

Do not make this a protocol unless multiple independently extensible
implementations actually emerge.

---

# Formentation boundary

The playground relies on the high-level external API.

For source application:

```elixir
Formentation.form(declaration, adapter: :json_schema, data: data, ...)
```

For runtime interaction:

```elixir
Formentation.Form.validate(form, params)
Formentation.Form.submit(form, params)
```

Do not depend on renderer-internal modules or raw Definition struct layout
during this milestone. If the public API cannot express something the
playground needs, record that as a Formentation finding rather than
reaching into internals.

---

# Phoenix LiveView target

The LiveView becomes mostly event translation.

```elixir
def mount(_params, _session, socket) do
  {:ok, assign_session(socket, Playground.start_session())}
end

def handle_event("validate-preview", %{"proposal" => params}, socket) do
  {:noreply,
   assign_session(socket, Playground.validate_preview(socket.assigns.session, params))}
end

def handle_event("submit-preview", %{"proposal" => params}, socket) do
  {:noreply,
   assign_session(socket, Playground.submit_preview(socket.assigns.session, params))}
end
```

## `assign_session/2`

Keep Phoenix-specific projection in the web layer:

```elixir
defp assign_session(socket, session) do
  socket
  |> assign(:session, session)
  |> assign(:preview_form, to_form(session.form, as: "proposal"))
end
```

Do not store `%Phoenix.HTML.Form{}` inside the Session:

```text
Session owns application/domain state.
Phoenix projection belongs to the web layer.
```

This preserves the separation already established by Formentation.

---

# Naming cleanup

As this milestone lands, rename the conceptual page from
`ProposalFormLive` to `PlaygroundLive`. The proposal becomes an Example,
not the application itself.

Recommended event names:

```text
edit-declaration
edit-presentation
edit-data
apply-sources
validate-preview
submit-preview
load-example
reset-session
```

Avoid generic `validate` / `save` once the page will contain both editor
controls and a generated form.

---

# Tests

## Domain tests first

Add direct tests around Playground/Session functions without LiveView.
These are the most important tests in the milestone.

### Start session

Assert:

- default example is loaded;
- accepted texts equal editor texts;
- parsed accepted values exist;
- form exists;
- diagnostics match expected compile output;
- submitted is nil;
- dirty facts are false.

### Edit does not recompile

Given a valid initialized session:

1. edit declaration text to invalid text;
2. assert editor text changed;
3. assert accepted declaration (text and parsed) unchanged;
4. assert current form unchanged;
5. assert preview still available;
6. assert dirty is true.

### Failed apply preserves last good preview

Given a valid session:

1. edit declaration text to unparsable JSON;
2. call `apply_sources`;
3. assert apply_errors exist;
4. assert accepted text/parsed values unchanged;
5. assert current form unchanged;
6. assert **diagnostics unchanged** (pinned rule);
7. assert dirty remains true.

This test pins the most important interaction invariant.

### Failed compile preserves last good preview and diagnostics

Given a valid session:

1. edit declaration text to valid JSON that Formentation rejects or
   cannot compile;
2. call `apply_sources`;
3. assert apply_errors contain the compile failure;
4. assert accepted state, form, and diagnostics all unchanged.

This is distinct from the parse-failure test: it proves failed compiles
land in `apply_errors`, never in `diagnostics`.

### Successful apply replaces accepted state

Given dirty but valid editor text (e.g. a changed field title):

1. apply;
2. assert accepted texts updated;
3. assert parsed accepted values updated;
4. assert form rebuilt from the new declaration;
5. assert apply_errors empty;
6. assert dirty facts false;
7. assert stale submitted result cleared.

This test is only possible because Milestone 1 includes JSON parsing —
it is the reason JSON Schema was pulled forward.

### Validate preview delegates to Formentation

Use the existing invalid-integer scenario.

Assert:

- new form is stored;
- raw input survives;
- submitted is cleared if previously set (pinned policy).

### Submit preview

Success branch: returned form stored; submitted decoded instance stored.

Failure branch: returned submitted-form stored; submitted is nil.

### Load example

Assert loading an example replaces editor text, accepted state, form, and
diagnostics; and clears apply errors, submitted result, and dirty state.

### Reset

Assert interactions/edits are discarded and the selected example baseline
is restored.

---

## LiveView tests

Keep the existing user-facing tests, adapting selectors/names as
necessary.

Milestone acceptance should still prove:

- rendered widgets exist;
- failed submit shows errors and keeps raw input;
- valid submit shows decoded instance.

Add one integration test proving the LiveView obtains its initial state
through the Playground module rather than a hard-coded declaration.

Avoid retesting every Session rule through LiveView.

---

## Browser tests

Keep the current Playwright tests passing. No new browser-only behavior is
required for this milestone.

The browser tests are particularly valuable because they continue to
exercise the real external Formentation integration after both the
application structure **and the declaration source** change.

---

# Implementation order

## Step 1 — Convert the example to JSON Schema

Before touching application structure, express the current proposal form
as JSON Schema + presentation hints + instance JSON, compiled through
`adapter: :json_schema`, and make the existing LiveView tests pass against
it (adapting deliberately where the JSON Schema source legitimately
differs).

Doing this first isolates "does the JSON Schema source support our
example?" from the refactor. Any gaps discovered are recorded as
Formentation findings.

## Step 2 — Introduce `Example` and `Examples`

Extract the three documents from the LiveView into the example registry.
Do not change the UI yet. Run tests.

## Step 3 — Create the Session struct and `start_session`

Add the struct, the parser boundary (JSON), and `start_session/0` with
direct domain tests. Do not wire the LiveView yet.

## Step 4 — Add preview actions

Implement `validate_preview/2` and `submit_preview/2` with direct tests,
using only the public Formentation API.

## Step 5 — Add editor/apply actions

Implement `edit_declaration/2`, `edit_presentation/2`, `edit_data/2`, and
`apply_sources/1`, including the full test set above (parse failure,
compile failure, success).

Even before the UI exposes textareas, these functions establish the
invariant needed by Milestone 2.

## Step 6 — Add example/reset actions

Implement `load_example/2` and `reset_session/1`. Add dirty/derived fact
functions as needed.

## Step 7 — Replace LiveView-owned state

Refactor the LiveView to mount and update a Session through Playground
functions. Rename to `PlaygroundLive`. Keep Phoenix projection
(`to_form`) in the web layer. At the end of this step, the hard-coded
declaration no longer exists in the LiveView.

## Step 8 — Preserve test coverage

Update LiveView tests, Playwright tests, router references, and
page names/selectors. Do not weaken assertions merely to make the
refactor pass.

## Step 9 — Small documentation update

Update the repository README to mark Milestone 1 complete and record the
actual module/function names. Update Milestone 2 before beginning its
implementation if the Session design changed materially during the work.

---

# Acceptance criteria

Milestone 1 is complete when all of the following are true:

- [ ] The Playground core is plain Elixir (struct + pure functions); no
      Ash, no database, no persistent store, no process registry.
- [ ] The built-in `talk-proposal` example is authored as JSON Schema +
      presentation + instance documents and compiled through
      `adapter: :json_schema`.
- [ ] Any behavior the JSON Schema source could not express is recorded as
      a Formentation finding, not silently dropped.
- [ ] The proposal is represented as an Example rather than a LiveView
      module attribute.
- [ ] A Session can be created from an Example through the Playground API.
- [ ] The Session explicitly separates current editor text from last
      accepted source state (text and parsed value per document).
- [ ] Editing text does not implicitly parse/compile.
- [ ] A failed apply (parse or compile) preserves the last valid compiled
      preview **and its diagnostics**; failures land in `apply_errors`.
- [ ] A successful apply atomically replaces accepted source state, the
      current Formentation form, and diagnostics, and clears stale
      apply errors and submission results.
- [ ] Preview validation delegates to `Formentation.Form.validate/2` and
      clears a stale submitted result.
- [ ] Preview submission delegates to `Formentation.Form.submit/2`.
- [ ] The Session does not duplicate internal Formentation form state.
- [ ] `%Phoenix.HTML.Form{}` remains a web-layer projection and is not
      stored in the Session.
- [ ] Loading/resetting examples has explicit tested semantics.
- [ ] The LiveView communicates only through Playground functions.
- [ ] Existing LiveView behavior remains covered.
- [ ] Existing real-browser tests remain green.

---

# Non-goals

Do not add these in Milestone 1:

- authoring UI (textareas, Apply button, example selector) — Milestone 2;
- Elixir literal parsing or the `:map` source — Milestone 3;
- Ash (deferred until a resource earns it — see the Ash decision);
- CodeMirror/Monaco;
- definition inspection;
- runtime-state inspector UI;
- generated presentation skeletons;
- JSON Patch/diff;
- URL sharing;
- persistent sessions;
- collaborative editing;
- visual schema editing;
- Livebook integration;
- Popcorn;
- a new Formentation API unless the refactor demonstrates an unavoidable
  public-boundary problem.

---

# Questions to record during implementation

Do not block implementation on these unless they become concrete problems.

## What exactly can the `:json_schema` adapter express in v0.2.0?

The example conversion in Step 1 answers this empirically. Record every
gap (widget hints, roles/formats, groups, help text) as a candidate
Formentation finding.

## Should apply failures be stored as one structured value or a list?

The JSON editor milestone may need:

```text
document
line/column
message
category
```

Keep the shape able to represent both parser errors and Formentation
compile errors.

## Does any genuine exclusive lifecycle appear?

If implementation reveals one, document it before considering Ash or
`AshStateMachine`. Do not add either merely because they exist.
