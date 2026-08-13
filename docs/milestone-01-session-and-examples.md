# Milestone 1 — Session and Examples

## Status

Planned.

## Goal

Introduce the application/domain model that all later playground features will use, without changing the basic behavior that already works.

At the end of this milestone:

- the current hard-coded proposal form still renders and submits;
- the LiveView no longer owns the playground's domain behavior;
- an Ash domain exposes named actions for manipulating a non-persistent Session;
- built-in examples are represented explicitly;
- editor state and last successfully applied state are separate concepts;
- the model is ready for the JSON Schema authoring UI in Milestone 2.

This milestone is intentionally about **state ownership and action boundaries**, not about adding editors yet.

---

## Why do this before the JSON Schema UI?

The current `ProposalFormLive` is a good vertical proof, but it owns:

- declaration data;
- compilation/form initialization;
- diagnostics;
- current `Formentation.Form`;
- validation;
- submission;
- submitted result;
- rendering.

That is appropriate for a first example, but it will become difficult to maintain once the page also owns:

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
│       ├── playground.ex
│       ├── session.ex
│       ├── example.ex
│       └── examples.ex
└── frmn_play_web/
    └── live/
        └── playground_live.ex
```

Exact filenames may vary, but responsibilities should remain separated.

Conceptually:

```text
Phoenix LiveView
      │
      │ calls code interface
      ▼
FrmnPlay.Playground
      │
      ├── Session actions
      │
      └── Example lookup
      │
      ▼
Formentation public API
```

---

# Ash decision

## Use Ash

Add an Ash domain and model the Session as an Ash resource.

The resource does **not** need a database.

Use Ash's non-persistent/simple data-layer behavior and keep the returned Session record in the LiveView socket.

The lifecycle remains:

```text
socket.assigns.session
        ↓
Playground action
        ↓
updated %Session{}
        ↓
assign back to socket
```

There is no process registry or global state involved.

## Do not use AshStateMachine yet

Do not model the Session with one finite `state` attribute at this point.

The Session has orthogonal facts that can coexist:

```text
declaration editor     dirty + syntactically invalid
presentation editor    clean + valid
last compile           successful
preview                available
preview form           currently undecodable
previous submission    available
```

These are not mutually exclusive lifecycle states.

Avoid artificial states such as:

```text
:editing
:dirty
:invalid
:compiled
:submitted
```

because they collapse independent dimensions into one value.

Where useful, derive UI-facing facts through calculations/helpers:

```text
dirty?
declaration_dirty?
presentation_dirty?
data_dirty?
has_preview?
has_submission?
last_apply_failed?
```

Reconsider `AshStateMachine` later if a genuinely exclusive workflow appears, for example a future persisted example lifecycle:

```text
draft → reviewed → published → deprecated
```

---

# Core domain concepts

## `FrmnPlay.Playground`

An Ash domain exposing the public application API for playground actions.

The LiveView should prefer the generated code interface rather than constructing Ash changesets directly.

Conceptually:

```elixir
defmodule FrmnPlay.Playground do
  use Ash.Domain

  resources do
    resource FrmnPlay.Playground.Session do
      define :start_session, action: :start
      define :edit_declaration, action: :edit_declaration
      define :edit_presentation, action: :edit_presentation
      define :edit_data, action: :edit_data
      define :apply_sources, action: :apply_sources
      define :validate_preview, action: :validate_preview
      define :submit_preview, action: :submit_preview
      define :load_example, action: :load_example
      define :reset_session, action: :reset
    end
  end
end
```

Treat names/signatures as illustrative. Prefer clear intent over CRUD terminology.

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

The playground must be able to store that text without destroying the currently rendered form.

Therefore the Session needs two conceptual layers:

```text
CURRENT EDITOR STATE
    declaration text
    presentation text
    data text
    parse/apply attempt errors

LAST ACCEPTED STATE
    parsed declaration
    parsed presentation
    parsed data
    compile diagnostics
    current Formentation.Form
```

The first layer changes frequently.

The second layer changes only after a successful apply operation.

---

## Suggested initial attributes

Do not over-optimize the exact type layout yet.

A reasonable first model is:

```elixir
defmodule FrmnPlay.Playground.Session do
  use Ash.Resource,
    domain: FrmnPlay.Playground

  attributes do
    uuid_primary_key :id

    attribute :source, :atom do
      allow_nil? false
      constraints one_of: [:map, :json_schema]
    end

    # Current editable source documents
    attribute :declaration_text, :string do
      allow_nil? false
    end

    attribute :presentation_text, :string do
      allow_nil? false
    end

    attribute :data_text, :string do
      allow_nil? false
    end

    # Last accepted/parsed source documents
    attribute :accepted_declaration, :term
    attribute :accepted_presentation, :term
    attribute :accepted_data, :term

    # Result of compiling/initializing the accepted source
    attribute :form, :term

    # Formentation compile warnings
    attribute :diagnostics, {:array, :term} do
      default []
      allow_nil? false
    end

    # Errors from the most recent attempt to apply current editor contents
    attribute :apply_errors, {:array, :term} do
      default []
      allow_nil? false
    end

    # Last accepted submission result
    attribute :submitted, :term
  end
end
```

### Important note about `:term`

Using `:term` here is acceptable for the first non-persistent model because values such as `%Formentation.Form{}` are runtime objects owned by another library.

Do **not** mirror the internals of `%Formentation.Form{}` into Ash attributes merely to make the Session appear more Ash-native.

Later milestones can introduce structured custom types or dedicated value structs where that improves introspection.

---

## Optional refinement: editor value object

If repeated editor handling becomes awkward, introduce a value type/embedded structure later:

```elixir
%EditorState{
  text: "...",
  errors: [],
  dirty?: true
}
```

Do not create three separate Ash resources purely for aesthetic normalization unless the implementation demonstrates a real benefit.

---

# Example model

## Goal

Remove built-in examples from LiveView module attributes and make them first-class application data.

Examples are initially static and do not require persistence.

Suggested shape:

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

It is acceptable to make `Example` an Ash resource immediately if that makes the domain API cleaner.

Do not add ETS/database storage merely to justify the resource.

## Initial example

Move the current proposal form behind an example named something like:

```text
talk-proposal
```

The example should preserve the behavior already covered by the existing tests:

- string input;
- string options/select;
- radio widget;
- textarea;
- integer default;
- email role;
- date role;
- boolean;
- nested object;
- presentation groups;
- successful submit;
- raw invalid numeric input preservation.

For Milestone 1 it is fine for this example to remain a Map-source declaration.

Milestone 2 will add JSON Schema examples.

---

# Session actions

## `start`

Creates a new Session from a default Example.

Responsibilities:

1. choose the default example;
2. populate editor text;
3. populate accepted source values;
4. compile/initialize the initial form;
5. store diagnostics;
6. ensure the returned Session is immediately renderable.

Illustrative action:

```elixir
create :start do
  accept []

  change fn changeset, _context ->
    example = Examples.default()

    Ash.Changeset.change_attributes(changeset, %{
      source: example.source,
      declaration_text: example.declaration_text,
      presentation_text: example.presentation_text,
      data_text: example.data_text
    })
  end

  change FrmnPlay.Playground.Changes.InitializeFromExample
end
```

Whether initialization is implemented in an inline change or custom change module is an implementation choice.

Prefer a custom module once logic becomes non-trivial.

---

## `edit_declaration`

Inputs:

```text
declaration_text
```

Effect:

- replace current editor text.

Must **not**:

- parse;
- compile;
- replace the accepted declaration;
- replace the current form;
- clear the current preview.

The same rule applies to `edit_presentation` and `edit_data`.

These actions model editing, not applying.

---

## `apply_sources`

This is the central action of the Session model.

In Milestone 1 it may initially operate on the existing Map-source example only, but its contract should be suitable for Milestone 2.

Conceptual algorithm:

```text
current editor texts
        ↓
parse according to source mode
        ↓
if parse fails:
    keep accepted state unchanged
    keep current form unchanged
    record apply errors

if parse succeeds:
        ↓
Formentation.form(...)
        ↓
if compilation fails:
    keep accepted state unchanged
    keep current form unchanged
    record diagnostics/errors

if compilation succeeds:
    replace accepted documents
    replace current form
    replace diagnostics
    clear apply errors
    clear stale submission result
```

### A failed apply is normal Session state

Do not automatically treat user-authored invalid source as an Ash action failure.

For an interactive playground this is a normal outcome:

```text
"Your current text cannot be applied.
The preview still shows the last successful version."
```

Prefer returning an updated Session containing `apply_errors`.

Reserve Ash action errors for failures where the application itself could not perform the requested operation.

This distinction will keep LiveView event handling simple.

---

## `validate_preview`

Input:

```text
params
```

Precondition:

- a current `%Formentation.Form{}` exists.

Operation:

```elixir
new_form =
  Formentation.Form.validate(session.form, params)
```

Then return a Session with:

- `form` replaced with `new_form`;
- `submitted` unchanged or cleared according to the policy chosen below.

### Submission-result policy

Recommended first policy:

- any preview validation after a successful submission clears `submitted`.

Reason: once the user edits the form again, the old submitted instance no longer describes the current preview.

Pin this behavior in a test.

---

## `submit_preview`

Input:

```text
params
```

Operation:

```elixir
case Formentation.Form.submit(session.form, params) do
  {:ok, instance, submitted_form} ->
    session
    |> replace_form(submitted_form)
    |> set_submitted(instance)

  {:error, submitted_form} ->
    session
    |> replace_form(submitted_form)
    |> clear_submitted()
end
```

Do not derive success independently from candidate/issues. Use the public Formentation submission decision.

---

## `load_example`

Input:

```text
example_id
```

Recommended semantics:

- immediately replace editor text with the selected example;
- immediately compile/initialize it;
- replace accepted state;
- replace the current form;
- replace diagnostics;
- clear apply errors;
- clear submitted result.

Do not preserve dirty edits when switching examples in the first implementation.

Later the UI may warn about unsaved/dirty editor contents if that becomes useful.

---

## `reset`

Reset the current Session to the currently selected/baseline example.

Suggested semantics:

- restore example editor text;
- restore accepted state;
- rebuild the form from initial data;
- clear current runtime interaction state;
- clear apply errors;
- clear submitted result.

If "reset editor" and "reset preview form" later need separate meanings, split the actions then.

---

# Derived facts / calculations

Do not add an exclusive state machine. Derive user-facing status.

Potential helpers/calculations:

```elixir
declaration_dirty?
presentation_dirty?
data_dirty?
dirty?
has_preview?
has_apply_errors?
has_diagnostics?
has_submission?
```

Example dirty calculation:

```elixir
calculate :declaration_dirty?, :boolean do
  calculation expr(declaration_text != accepted_declaration_text)
end
```

If accepted values are stored only in parsed form, consider also storing the accepted text revision.

That may actually be clearer:

```text
declaration_text
accepted_declaration_text
accepted_declaration
```

This duplicates text intentionally so dirty-state comparison is unambiguous and formatting-preserving.

The same pattern can be used for presentation and instance data.

---

# Recommended text/state representation

For Milestone 1, prefer explicitness:

```elixir
attribute :declaration_text, :string
attribute :accepted_declaration_text, :string
attribute :accepted_declaration, :term

attribute :presentation_text, :string
attribute :accepted_presentation_text, :string
attribute :accepted_presentation, :term

attribute :data_text, :string
attribute :accepted_data_text, :string
attribute :accepted_data, :term
```

Why retain both text and parsed values?

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

The playground needs to know whether the user has unapplied text changes.

---

# Parsing boundary

Milestone 1 should create a parser boundary even if the only active source remains the current static Map example.

Suggested module shape:

```elixir
defmodule FrmnPlay.Playground.Parser do
  def parse_declaration(:json_schema, text), do: ...
  def parse_declaration(:map, text), do: ...
  def parse_presentation(:json_schema, text), do: ...
  def parse_data(text), do: ...
end
```

Milestone 2 supplies JSON implementations.

Milestone 3 supplies the restricted Elixir parser.

Do not make this a protocol unless multiple independently extensible implementations actually emerge.

---

# Formentation boundary

The playground should rely on the high-level external API.

For source application:

```elixir
Formentation.form(
  declaration,
  adapter: source,
  data: data,
  ...
)
```

For runtime interaction:

```elixir
Formentation.Form.validate(form, params)
Formentation.Form.submit(form, params)
```

Do not depend on renderer-internal modules or raw Definition struct layout during this milestone.

---

# Phoenix LiveView target

The LiveView should become mostly event translation.

Conceptually:

```elixir
def mount(_params, _session, socket) do
  {:ok, session} = Playground.start_session()

  {:ok, assign_session(socket, session)}
end
```

```elixir
def handle_event("validate-preview", %{"proposal" => params}, socket) do
  {:ok, session} =
    Playground.validate_preview(socket.assigns.session, %{params: params})

  {:noreply, assign_session(socket, session)}
end
```

```elixir
def handle_event("submit-preview", %{"proposal" => params}, socket) do
  {:ok, session} =
    Playground.submit_preview(socket.assigns.session, %{params: params})

  {:noreply, assign_session(socket, session)}
end
```

Exact code-interface signatures depend on the Ash action definitions.

## `assign_session/2`

Keep Phoenix-specific projection in the web layer.

For example:

```elixir
defp assign_session(socket, session) do
  socket
  |> assign(:session, session)
  |> assign(:preview_form, to_form(session.form, as: "proposal"))
end
```

Do not store `%Phoenix.HTML.Form{}` inside the Ash Session.

Reason:

```text
Session owns application/domain state.
Phoenix projection belongs to the web layer.
```

This also preserves the separation already established by Formentation.

---

# Naming cleanup

As this milestone lands, rename the conceptual page from `ProposalFormLive` to `PlaygroundLive`.

The proposal becomes an Example, not the application itself.

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

Avoid generic `validate` / `save` once the page will contain both editor controls and a generated form.

---

# Tests

## Domain tests first

Add direct tests around Session actions without LiveView.

These are the most important tests in the milestone.

### Start session

Assert:

- default example is loaded;
- accepted/editor texts match;
- form exists;
- diagnostics match expected compile output;
- submitted is nil;
- dirty calculations are false.

### Edit action does not recompile

Given a valid initialized session:

1. edit declaration text to invalid text;
2. assert editor text changes;
3. assert accepted declaration remains unchanged;
4. assert current form remains unchanged;
5. assert preview is still available.

### Failed apply preserves last good preview

Given a valid session:

1. modify editor text to something that cannot be applied;
2. call `apply_sources`;
3. assert apply errors exist;
4. assert accepted text/document is unchanged;
5. assert current form is unchanged;
6. assert dirty status remains true.

This test pins the most important interaction invariant.

### Successful apply replaces accepted state

Given dirty but valid editor text:

1. apply;
2. assert accepted text is updated;
3. assert parsed accepted value is updated;
4. assert form is rebuilt;
5. assert apply errors are empty;
6. assert dirty state is false;
7. assert stale submitted result is cleared.

### Validate preview delegates to Formentation

Use the existing invalid integer scenario.

Assert:

- new form is stored;
- raw input survives;
- submission result is cleared if previously set.

### Submit preview

Success branch:

- returned form is stored;
- submitted decoded instance is stored.

Failure branch:

- returned submitted-form is stored;
- submitted result is nil.

### Load example

Assert loading an example replaces:

- editor text;
- accepted state;
- form;
- diagnostics;

and clears:

- apply errors;
- submitted result;
- dirty state.

### Reset

Assert interactions/edits are discarded and the selected example baseline is restored.

---

## LiveView tests

Keep the existing user-facing tests, adapting selectors/names as necessary.

Milestone acceptance should still prove:

- rendered widgets exist;
- failed submit shows errors and keeps raw input;
- valid submit shows decoded instance.

Add one integration test proving the LiveView obtains its initial state through the Playground domain rather than a hard-coded declaration.

Avoid retesting every Session rule through LiveView.

---

## Browser tests

Keep the current Playwright tests passing.

No new browser-only behavior is required for this milestone.

The browser tests are particularly valuable because they continue to exercise the real external Formentation integration after the application structure changes.

---

# Implementation order

## Step 1 — Add Ash

Add Ash to dependencies and create:

```text
FrmnPlay.Playground
```

Do not add `ash_state_machine`.

Make sure the application compiles and the existing tests remain green before moving behavior.

---

## Step 2 — Introduce `Example`

Extract the current proposal declaration and initial data from the LiveView.

Provide an API such as:

```elixir
Examples.default()
Examples.get!("talk-proposal")
Examples.all()
```

Initially this may be a simple module returning `%Example{}` values.

Do not change the UI yet.

Run tests.

---

## Step 3 — Create the Session resource

Add the initial attributes for:

- source;
- editor text;
- accepted text;
- accepted parsed values;
- diagnostics;
- apply errors;
- Formentation form;
- submitted result;
- selected example id if useful.

Implement `:start`.

Add direct Session/domain tests.

Do not wire the LiveView yet.

---

## Step 4 — Add preview actions

Implement:

```text
validate_preview
submit_preview
```

with direct tests.

Use only the public Formentation API.

This step proves that Ash can cleanly orchestrate `%Formentation.Form{}` without duplicating its internals.

---

## Step 5 — Add editor/apply actions

Implement:

```text
edit_declaration
edit_presentation
edit_data
apply_sources
```

Even before the UI exposes textareas, these actions establish the invariant needed by Milestone 2.

Most important test:

> invalid/unapplicable current editor text must not destroy the last successfully applied preview.

---

## Step 6 — Add example/reset actions

Implement:

```text
load_example
reset
```

Add dirty/derived status calculations/helpers as needed.

---

## Step 7 — Replace LiveView-owned state

Refactor the current LiveView to mount and update a Session through Playground actions.

Rename to `PlaygroundLive` if practical in this step.

Keep Phoenix projection (`to_form`) in the web layer.

At the end of this step, the hard-coded declaration should no longer exist in the LiveView.

---

## Step 8 — Preserve test coverage

Update:

- LiveView tests;
- Playwright tests;
- router references;
- page names/selectors.

Do not weaken assertions merely to make the refactor pass.

---

## Step 9 — Small documentation update

Update the repository README to mark Milestone 1 complete and record the actual module/action names.

Update Milestone 2 before beginning its implementation if the Session design changed materially during the work.

---

# Acceptance criteria

Milestone 1 is complete when all of the following are true:

- [ ] Ash is used for the Playground application/domain model.
- [ ] No database or persistent store is required.
- [ ] `AshStateMachine` is not used without a newly discovered exclusive lifecycle.
- [ ] The current proposal is represented as an Example rather than a LiveView module attribute.
- [ ] A Session can be created from an Example through the Playground API.
- [ ] The Session explicitly separates current editor text from last accepted source state.
- [ ] Editing text does not implicitly parse/compile.
- [ ] A failed apply preserves the last valid compiled preview.
- [ ] A successful apply atomically replaces accepted source state and the current Formentation form.
- [ ] Preview validation delegates to `Formentation.Form.validate/2`.
- [ ] Preview submission delegates to `Formentation.Form.submit/2`.
- [ ] The Session does not duplicate internal Formentation form state.
- [ ] `%Phoenix.HTML.Form{}` remains a web-layer projection and is not stored in the Session.
- [ ] Loading/resetting examples has explicit tested semantics.
- [ ] The LiveView communicates through Playground actions/code interfaces.
- [ ] Existing LiveView behavior remains covered.
- [ ] Existing real-browser tests remain green.

---

# Non-goals

Do not add these in Milestone 1:

- JSON Schema textareas;
- Elixir literal parsing;
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
- a new Formentation API unless the Session refactor demonstrates an unavoidable public-boundary problem.

---

# Questions to record during implementation

Do not block implementation on these unless they become concrete problems.

## Should `Example` be an Ash resource?

Start with the simplest representation that works.

Promote it if Ash code interfaces/relationships provide clear value.

## Should apply failures be stored as one structured value or a list?

The JSON editor milestone may need:

```text
document
line/column
message
category
```

Avoid prematurely choosing a schema that cannot represent both parser errors and Formentation diagnostics.

## Should accepted source text be stored separately from parsed values?

Recommendation: yes, because dirty state should reflect editor revisions, not semantic equality.

Validate that this remains useful in implementation.

## Should `submitted` clear on any preview validation?

Recommendation: yes.

Pin the chosen behavior.

## Does any genuine exclusive lifecycle appear?

If implementation reveals one, document it before adding `AshStateMachine`.

Do not add the state machine merely because the dependency exists.
