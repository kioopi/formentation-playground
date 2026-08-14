# Milestone 2 — JSON Schema Playground MVP

## Status

Implemented (see `docs/superpowers/plans/2026-08-14-milestone-02-json-schema-playground.md`).

## Revision notes

- **2026-08-13** — Milestone 1 now includes JSON parsing, the
  JSON-Schema-sourced default example, and the complete `apply_sources`
  loop with tests. This milestone therefore shrinks to mostly **UI
  work**: exposing the already-tested Session model through editable
  documents on the page.
- **2026-08-14** — Design discussion resolved. This document now pins
  the playground's interaction model: page layout, the `preview` form
  namespace, the browser DOM-revision contract, diagnostic placement by
  ownership, structured parse errors, the three built-in examples, and
  the destructive-switching policy. All load-bearing assumptions were
  verified against the M1 code and the Formentation v0.2.0 dependency
  (noted inline below).
- **2026-08-14 (post-implementation)** — Three refinements from review
  and a field bug, now part of the contract:
  - **Facade enforcement.** Where this document shows templates calling
    `Session.dirty?/1` and friends, the implementation routes those
    query predicates through `defdelegate`s on `FrmnPlay.Playground` —
    the web layer never names the Session module (`Session` structs are
    still read as plain values). Enforced by the `FrmnPlay.Playground.*`
    internal boundary in `.reach.exs` for `.ex` sources, plus a guard
    test in `playground_live_test.exs` for HEEx templates, which reach
    cannot see (it only ingests `.ex` files).
  - **Textarea whitespace contract.** Source-editor values must render
    with no surrounding template whitespace: the browser keeps injected
    indentation as part of the textarea value, and every `phx-change`
    echoes all three values back, compounding one layer per edit. The
    `source_editor` component therefore renders its slot inline with
    `phx-no-format` and `Phoenix.HTML.Form.normalize_value/2`; a
    round-trip regression test simulates the browser echo. Milestone 7
    must preserve this property when replacing the textareas with code
    editors.
  - **Plan deviation.** The first Playwright DOM-reset regression
    landed with the Apply loop (implementation-order step 4) rather
    than step 3 — before Apply exists there is no revision-bumping
    trigger to test against.

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

## UX invariant

Temporarily invalid editor input must not destroy the currently rendered
preview. (The Session already guarantees this; the UI must communicate
it.)

The preview should clearly indicate when it represents the last
successfully applied revision rather than the current editor contents.

The layout must make the fundamental invariant visually obvious:

> The sources on the left currently have a problem. The preview on the
> right is still the last successfully applied revision.

---

## 1. Page layout

A two-column developer-tool UI on desktop, collapsing vertically on
smaller screens:

```text
┌───────────────────────────────────────────────────────────────┐
│ Formentation Playground                         JSON Schema   │
│ Example: [ Talk proposal ▼ ]              [ Reset example ]   │
└───────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐ ┌───────────────────────────────┐
│ Sources                     │ │ Preview                       │
│                             │ │ [Changes not applied]         │
│ Schema               ●      │ │                               │
│ ┌─────────────────────────┐ │ │ accepted compile diagnostics  │
│ │                         │ │ │                               │
│ │ textarea                │ │ │ rendered form                 │
│ │                         │ │ │                               │
│ └─────────────────────────┘ │ │                               │
│                             │ │                [Submit]       │
│ Presentation          ●     │ │                               │
│ ┌─────────────────────────┐ │ ├───────────────────────────────┤
│ │ textarea                │ │ │ Decoded instance              │
│ └─────────────────────────┘ │ │ { ... }                       │
│                             │ │                               │
│ Initial instance      ●     │ └───────────────────────────────┘
│ ┌─────────────────────────┐ │
│ │ textarea                │ │
│ └─────────────────────────┘ │
│                             │
│ apply errors/diagnostics    │
│                             │
│             [Apply sources] │
└─────────────────────────────┘
```

**No tabs for the three editors.** Seeing schema, presentation, and
initial data simultaneously reinforces the three-document model, and
diagnostics can be visually associated with the appropriate document.
Dedicated editors/tabs can come later (Milestone 7) when those
documents become large.

**Web code split.** `PlaygroundLive` gains several handlers plus
substantially more markup, so split now:

```text
playground_live.ex
playground_live.html.heex

components/
  playground_components.ex
```

No LiveComponents. Ordinary function components (`source_editor`,
`parse_error_list`, `diagnostic_list`, …) are enough. Session ownership
stays entirely in the one LiveView.

**Sources form wiring.** `phx-change` is a form binding, so the three
editors are wired as **one Sources form**, not three independently
bound textareas:

```heex
<form phx-change="edit-sources" phx-submit="apply-sources">
  <!-- declaration, presentation, data textareas -->
</form>
```

The handler reads the params (dispatching on `_target`, or simply
applying all three through the idempotent
`edit_declaration/edit_presentation/edit_data`). This gives Apply a
semantically correct home as the form's submit button and one
`phx-debounce` policy for free. Three separate event names per textarea
would require three wrapper forms for no benefit.

---

## 2. The `preview` form namespace (remove the `proposal` legacy)

`"proposal"` is residue from the first hard-coded example. The stable
namespace becomes:

```elixir
to_form(session.form, as: "preview")
```

giving `preview[title]`, `preview[duration_minutes]`, … and handlers:

```elixir
def handle_event("validate-preview", %{"preview" => params}, socket)
def handle_event("submit-preview", %{"preview" => params}, socket)
```

The namespace describes the **role on the playground page**, not the
example being displayed, so it remains stable while examples switch. Do
not derive it from the selected example.

Likewise:

```text
proposal-form      → preview-<dom_revision>   (see §3)
Submit proposal    → Submit
```

---

## 3. DOM reset: an explicit browser-revision contract

The most important technical decision in M2.

LiveView treats the browser as authoritative for current input state
and protects user input against ordinary server patches. Rerendering a
textarea or form with a new `value` is **not** a reset mechanism, and
`phx-update="replace"` is not the answer either — replace is already
LiveView's normal patch behavior. What we need is intentionally **new
DOM identity**.

Introduce a monotonic **browser DOM revision in the LiveView** (not in
`Session`):

```elixir
socket.assigns.dom_revision
```

Increment it after:

```text
successful apply_sources
load_example
reset_session
```

Do **not** increment it after:

```text
edit-sources
validate-preview
submit-preview
failed apply_sources
```

Use the revision to change the identities of editable DOM nodes:

```elixir
to_form(session.form, as: "preview", id: "preview-#{dom_revision}")
```

`Formentation.Phoenix`'s FormData implementation pops `:as` and `:id`
independently (verified in v0.2.0), and derives child input IDs from
the Phoenix form ID — so this gives the new form an entirely new set of
DOM identities while submitted names remain `preview[...]`.

Do the equivalent for editor textarea IDs:

```text
declaration-editor-17
presentation-editor-17
data-editor-17
```

while preserving stable names/data attributes for tests.

**Do not derive the revision from accepted document contents.**
Applying unchanged sources, or resetting an already-selected example,
must still reconstruct browser state despite identical source
documents. A monotonic UI revision expresses exactly that.

**This is purely a web-layer concern.** No `Session.revision` — the
Session's model does not care how Phoenix reconciles browser nodes.

**Known, accepted footnote:** re-keying the editors on successful Apply
is safe — to click Apply the user has already blurred the textarea, so
LiveView flushes any debounced `phx-change` before the click and focus
loss is moot. The only cost is textarea scroll position resetting on
Apply. Acceptable for M2; a consequence of the uniform "bump on all
success events" rule, not a bug.

---

## 4. Diagnostics: three channels, placed by ownership

The current `inspect(@session.diagnostics)` disappears. There are three
diagnostic channels, deliberately encoded in the M1 Session:

```text
apply_errors        parser/input-document errors    describes attempted editor contents
apply_diagnostics   compilation failure             describes attempted editor contents
diagnostics         successful-compile warnings     describes accepted/rendered preview
```

A failed Apply leaves the accepted `form` and `diagnostics` untouched,
so the layout reinforces that:

- `apply_errors` and `apply_diagnostics` render on the **Sources
  side**, under the editors and above Apply, effectively headed "Could
  not apply sources."
- Accepted `diagnostics` render on the **Preview side**, because they
  describe the form the user is currently looking at.

**Two shapes, two components.** `apply_errors` are plain parser maps
(§5), while `apply_diagnostics` and `diagnostics` are
`Formentation.Diagnostic` structs. Keep two function components —
`parse_error_list` and `diagnostic_list` — rather than normalizing
parser errors into pseudo-Diagnostics. The `document:` field and the
`origin:` tuple mean different things and deserve different rendering.

**Formentation diagnostics render structured, never `inspect/1`.**
`Formentation.Diagnostic` contains `severity`, `code`, `message`,
`origin`, `template_path`, with origins like
`{:json_schema, "/properties/tags/type"}`. Display roughly as:

```text
WARNING   unsupported_type

Unsupported type "array" for property "tags"

Schema: /properties/tags/type
Field:  tags
```

No rendering knowledge leaks into the Session.

---

## 5. Structured parse errors

The M1 parser throws away Jason's structured position. For an authoring
UI that is too weak. The playground's parser error shape becomes:

```elixir
%{
  document: :declaration,
  code: :invalid_json,
  message: "...",
  position: 123,
  line: 7,
  column: 14
}
```

For valid JSON of the wrong top-level shape:

```elixir
%{
  document: :data,
  code: :expected_object,
  message: "must be a JSON object, got: []",
  position: nil,
  line: nil,
  column: nil
}
```

Line/column are calculated in `Parser`, which owns the parsing boundary
and has both the source string and the parser offset
(`%Jason.DecodeError{position: ...}`). The LiveView must not know how
Jason positions work.

**Byte-offset caveat:** Jason's `position` is a byte offset. Compute
line/column naively by counting newlines; column is therefore in bytes,
not graphemes, on lines with multi-byte characters. Fine for M2 — note
the caveat in `Parser`'s moduledoc rather than doing grapheme-correct
counting.

No clickable source navigation yet. Plain
`Schema — line 7, column 14` plus the message is plenty for M2.

---

## 6. Built-in examples: exactly three

**`basic-fields` — "Basic fields."** A deliberately boring JSON Schema
with essentially empty presentation `{}`:

```text
name        string
age         integer
rating      number
active      boolean
category    string enum
date        string/date
```

Demonstrates what Formentation derives from JSON Schema **without
presentation customization**. Must compile cleanly with zero
diagnostics.

**`talk-proposal` — "Talk proposal."** The current rich example,
essentially unchanged: nested objects, groups, ordering,
radio/textarea overrides, constraints, defaults. **Remains the
default** so M2 doesn't disturb the existing baseline tests.

**`unsupported-array` — "Unsupported array."**

```json
{
  "type": "object",
  "title": "Unsupported feature",
  "properties": {
    "title": {
      "type": "string",
      "title": "Title"
    },
    "tags": {
      "type": "array",
      "title": "Tags",
      "items": {"type": "string"}
    }
  }
}
```

with initial data such as:

```json
{
  "title": "Existing record",
  "tags": ["elixir", "phoenix"]
}
```

Verified against Formentation v0.2.0: an **array property is
unsupported but non-fatal** — it produces a `severity: :warning`,
`code: :unsupported_type` diagnostic and compiles as a preserve-only
`Semantic.Unsupported` node. (A non-object root, by contrast, is a
fatal error.) And `initialize_from_example!/1` raises only on
`apply_errors`/`apply_diagnostics`, never on accepted warning
`diagnostics`. So `unsupported-array` is a valid built-in example:

```text
load example → successful apply → accepted preview + accepted warning diagnostic
```

No `expected_failure` flag, no weakening of the built-in-example
invariant. It also gives the diagnostics UI a real built-in
demonstration.

**Strengthen example tests:** prove every registered example loads
successfully; `basic-fields` has zero diagnostics; `unsupported-array`
succeeds with the expected accepted warning. **Explicitly test** that
`unsupported-array`'s initial `tags` array round-trips through the
preserve-only unsupported field on submit — the compile path is
verified, the data-ingestion-and-submit path for an array value is
pinned by test, not assumption.

---

## 7. Dirty switching policy: immediate, no confirmation

Carry M1's choice into the UI contract: **loading another example
immediately discards dirty edits.** No "Discard changes?" dialog — this
is a playground, not a persistent editor, and a modal would introduce
cancel/keyboard/browser-interaction state at exactly the milestone
establishing the basic editing loop. A small hint near the selector is
sufficient if needed:

```text
Selecting an example replaces the current sources.
```

The Reset button follows the same policy: immediate, no confirmation.

Revisit once sessions can be saved/shared.

---

## 8. Staleness: one indicator, no new state

After `Apply → fill form → Submit → edit schema`, the decoded instance
describes the accepted preview revision, not the current editor
sources — but that is **the same staleness as the preview itself**.

Do **not** introduce `submitted_dirty?` or another Session field.
`Session.dirty?/1` already means "the entire right-hand side represents
the last applied revision." One visible status at the top of the right
pane scopes both preview and decoded result:

```text
● Changes not applied
Preview and decoded result show the last applied revision.
```

The complementary M1 behavior already covers the other stale case: when
the user changes the preview form after a successful submission,
`validate_preview/2` clears `submitted`. The only remaining stale case
is source editing — exactly what the global dirty indicator covers.

---

## Test split

`LiveViewTest` does most M2 testing; the DOM-reset contract belongs in
Playwright. `LiveViewTest` can prove the server rendered a different
value; it cannot prove the running LiveView JS client actually replaced
the user's browser value. Keep browser tests focused on what **cannot
be established below the browser boundary**.

| Level | Important M2 assertions |
| --- | --- |
| Core/Parser | JSON error contains document, position and line/column; object-shape errors remain structured |
| Core/Examples | every example loads successfully; `basic-fields` has no diagnostics; `unsupported-array` has the expected warning; its array data round-trips through submit |
| LiveView | editors render initial texts; edits mark dirty; failed Apply preserves preview; successful Apply clears dirty; errors/diagnostics render structurally; selector/reset invoke the right actions; generic `preview[...]` namespace |
| Playwright | successful Apply really resets modified preview controls; switching examples really replaces dirty textarea values and preview values; Reset really restores editor + preview browser state |
| Playwright exit flow | edit source → Apply → new preview → interact → Submit → decoded instance |

---

## Implementation order

1. **Pin the interaction contracts first** (this document): generic
   `preview` namespace; immediate destructive example switching/reset;
   structured parse position; accepted-vs-attempted diagnostic
   placement; browser DOM-revision semantics.

2. **Add parser diagnostic structure and examples.** Small core changes
   with straightforward unit tests. Add `basic-fields` and
   `unsupported-array`; prove every registered example loads;
   specifically assert `unsupported-array` succeeds with the expected
   accepted warning and its array data round-trips.

3. **Remove `proposal` and introduce `dom_revision`** — before building
   the editor UI. Change the form projection to stable `as: "preview"`
   plus revisioned DOM IDs. Add the first Playwright regression proving
   an authoritative reset really resets modified browser controls.

4. **Build the Sources panel and Apply loop.** One Sources form wiring
   the three textareas to the existing `Playground.edit_*` functions,
   render `Session.dirty?/1`, wire Apply to
   `Playground.apply_sources/1`. Successful Apply increments
   `dom_revision`; failed Apply does not. The central M2 workflow now
   works end-to-end.

5. **Build structured diagnostic presentation.** First parse errors
   (`parse_error_list`), then failed compile diagnostics, then accepted
   preview diagnostics (`diagnostic_list`). The `unsupported-array`
   example becomes the manual/demo fixture here.

6. **Add example selector and Reset.** Both replace the Session and
   increment `dom_revision`. Playwright coverage specifically for dirty
   source text and modified preview fields being genuinely replaced in
   the browser.

7. **Finish the right-hand side.** Stale/applied status header,
   preview, Submit, decoded result with its inherited stale state. Then
   responsive layout/polish.

8. **One complete browser scenario as the executable exit criterion:**
   choose an example → edit schema/presentation/data → Apply → see
   changed preview → fill → Submit → see typed decoded result.

Do not start by laying out three textareas. The DOM-revision contract
and the attempted-vs-accepted diagnostic distinction are the two pieces
that determine whether the UI actually reflects the Session model
correctly. Once those are pinned, the rest of M2 is pleasantly
mechanical.

## Non-goals

- Elixir source mode;
- dedicated code editor (CodeMirror etc.);
- auto-apply;
- JSON patches;
- Definition inspector;
- structured schema editor;
- confirmation dialogs for destructive switching (revisit with
  saved/shared sessions);
- clickable source navigation from parse errors;
- grapheme-correct column numbers.

## Exit criteria

A user can start from an example, edit all three JSON documents, Apply
them, see parser/compiler diagnostics, fill the resulting live form,
and see the decoded submission result — proven end-to-end by the
Playwright scenario in step 8.
