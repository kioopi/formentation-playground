# Milestone 3 — Elixir Map Mode

## Status

Implemented (see `docs/superpowers/plans/2026-08-14-milestone-03-elixir-map-mode.md`).

## Revision note (2026-08-14)

This document was rewritten after a design discussion, replacing the
earlier direction sketch. The load-bearing decisions, each verified
against the M1/M2 code and the pinned Formentation v0.2.0 dependency
(noted inline), are:

1. **There is no separate presentation document in Map mode.** The
   earlier draft said "presentation derived/read-only"; that is replaced
   by the stronger and more accurate statement that the Map source
   declares presentation inline and the playground does not invent a
   derived document. See [Source-document asymmetry](#source-document-asymmetry).
2. **Source switching is example-driven only.** No standalone source
   selector, no conversion between sources. An example owns its source.
3. **The parser is an acceptance whitelist, not a blacklist.** Only
   explicitly recognized literal AST shapes are accepted; everything
   else — including future Elixir syntax — fails closed.
4. **The atom vocabulary is a flat, version-pinned playground set**,
   deliberately narrower than what the (partly open-ended) Map adapter
   accepts. Recorded as a Formentation finding.
5. **Parser limits are decoupled from Formentation's compile budgets.**
   The literal parser's limits are a resource-safety envelope
   (64 KiB / depth 64 / 10,000 nodes); Formentation's `max_depth: 16` /
   `max_nodes: 1000` are a declaration-complexity envelope measuring
   different things. Do not reuse 16/1000 at the parser layer.
6. **The source byte cap applies to every editable document**, JSON
   included — an M2 hardening finding folded into this milestone's
   parser work.

## Goal

Allow the playground to exercise Formentation's second built-in
declaration source — `adapter: :map` — from editable text.

Since Milestones 1–2 are JSON Schema only, this milestone introduces the
`:map` source into the playground entirely: the widened Session model,
the restricted Elixir literal parser, source-conditional compilation,
Map examples, and the source-aware UI all first appear here.

The architectural payoff is not "an Elixir textarea." It is proving that
one Session can host sources with **different document shapes**: JSON
Schema has declaration + presentation + data, while Map has
declaration + data with presentation embedded in the declaration. The
web layer must reflect that asymmetry without inventing a source-neutral
presentation document.

---

## Primary problem and threat model

A public playground must not evaluate arbitrary submitted Elixir code.
Do not use, under any flag or wrapper:

```elixir
Code.eval_string(...)
Code.eval_quoted(...)
```

**No submitted Elixir is ever evaluated.** The parser goes
AST → validate → recursively reconstruct a plain term. No execution
step exists anywhere in the pipeline.

Given that, the significant parser risks are:

- **atom-table growth** — prevented at tokenization
  (`existing_atoms_only: true` makes the tokenizer refuse atoms that do
  not already exist), with the playground vocabulary allowlist as a
  second, independent gate for existing-but-unapproved atoms;
- **resource exhaustion from adversarial source** — bounded primarily by
  the pre-tokenization byte cap. A post-parse depth/node check cannot
  protect `Code.string_to_quoted/2` itself from pathological input,
  because tokenization and parsing have already happened by then; the
  byte cap is therefore the primary parser-resource boundary, and the
  AST depth/node limits are defense in depth after parsing.

`String.to_atom/1` is not used anywhere, including inside any encoder.

---

## Source-document asymmetry

### There is no presentation document in Map mode

Formentation's Map source combines structure and presentation in one
declaration: `:title`, `:help`, `:groups`, `:role`, `:widget`,
`:hidden`, `:read_only` all live inline. Verified against v0.2.0: the
Map adapter's `compile/2` takes only `:max_depth`/`:max_nodes` budget
options — there is **no `:ui` option**; only the JSON Schema adapter
accepts UI hints. And while `Formentation.Info` exposes the compiled
presentation (`presentation_root/1`, `presentation_at/2`, origins),
there is no reverse serialization API that turns a compiled presentation
back into a user-facing source document.

Therefore the playground does **not** invent a derived presentation
representation — no generated text, no disabled fake editor. A derived
document would immediately raise unanswerable questions (lossless?
source-like? editable someday? stable?) that this milestone has no
business answering.

### Session invariant

```text
source == :map  implies

  presentation_text          == nil
  accepted_presentation_text == nil
  accepted_presentation      == nil
  presentation_dirty?        == false   (always)
```

The core enforces this invariant; it does not merely rely on the UI
never sending a presentation parameter:

- `edit_presentation/2` is a **no-op** on a Map Session;
- `parse_documents/1` does not call `parse_presentation/2` at all for
  `:map`;
- compilation omits `ui:` entirely:

```elixir
Formentation.form(declaration,
  adapter: :map,
  data: data,
  defaults: :apply
)
```

The current `apply_compiled/4` passes `ui: presentation`
unconditionally; it becomes source-conditional. The asymmetry is genuine
all the way down, not cosmetic.

### Model widening

`Session.t()` currently types `source: :json_schema` and
`Example` enforces `presentation_text`. Both widen:

- `source :: :json_schema | :map` in `Session.t()` and `Example.t()`;
- presentation fields become nullable; a Map `Example` carries
  `presentation_text: nil`.

### Instance data stays JSON

`Parser.parse_data/1` deliberately takes no source argument: instance
data is always JSON, in every source mode. This genuinely works for Map
declarations because Map property names are **strings** (properties are
an ordered list of `{"name", spec}` tuples — verified against the
v0.2.0 fixture), so JSON data keys line up without conversion.

---

## Source switching: example-driven only

**No standalone source selector. No conversion. An example owns its
source.** Selecting a Map example loads a fresh Map Session; selecting a
JSON Schema example loads a fresh JSON Schema Session. This is exactly
`load_example/2`'s existing semantics plus M2's immediate destructive
switching — no new mechanism.

Make the source distinction discoverable in the example selector,
grouped by source (optgroups):

```text
Example

JSON Schema
  Talk proposal
  Basic fields
  Unsupported array

Elixir Map
  Talk proposal
  Pump inspection
  Unsupported kind
```

The page header currently hardcodes "Declared with the JSON Schema
source"; it becomes source-aware.

A standalone source toggle can arrive only once there is a meaningful
answer to "Switch to Map — *with what contents?*". Until
conversion/default-per-source semantics exist, the example selector
already answers that question cleanly.

---

## The restricted literal parser

### Whitelist grammar

The decoder accepts **only explicitly recognized literal AST shapes.
Every other AST node is rejected.** This is a stronger contract than
blacklisting executable constructs: new Elixir syntax automatically
fails closed.

| Syntax | Policy |
| --- | --- |
| `%{...}` literal maps | accept |
| lists | accept |
| keyword-list sugar `[kind: :string]` | accept (as a list of 2-tuples) |
| `{a, b}` two-element tuples | accept |
| tuples with 3+ elements | **reject** |
| strings / heredoc strings | accept if non-interpolated |
| integers / floats | accept |
| `-5`, `+5`, `-1.5` | accept as unary numeric literals |
| `1 + 2`, `-foo`, other operators | reject |
| `true`, `false`, `nil` | accept |
| approved atoms | accept |
| unapproved existing atoms | reject (`atom_not_allowed`) |
| charlists `'abc'` | **reject** — not part of the Map format; silent `[97, 98, 99]` is a teaching-tool trap, and single-quoted charlists are deprecated syntax anyway. Rejected at tokenization via the charlist gate below, because a charlist is indistinguishable from a plain integer list once it reaches the AST |
| `%{map \| key: value}` update syntax | reject |
| `%SomeStruct{}` | reject |
| string interpolation | reject |
| sigils | reject |
| `foo` / `foo()` (variables, local calls) | reject |
| aliases / remote calls / captures | reject |
| `fn`, `case`, `if`, `with`, `for`, `receive`, … | reject |
| multiple expressions / blocks | reject |

Restricting tuples to pairs is deliberate: two-element tuples are the
only tuples the Map declaration format requires (`properties` is a list
of `{name, spec}` pairs).

After validating the AST, the parser **reconstructs the term
recursively** — never validate-then-`Code.eval_quoted/3`:

```text
AST
 ↓
pattern match accepted literal shape
 ↓
recursively construct map/list/pair/scalar
 ↓
plain Elixir term
```

### Parsing mechanism

```elixir
Code.string_to_quoted(text,
  existing_atoms_only: true,
  columns: true,
  token_metadata: true,
  emit_warnings: false,
  literal_encoder: &charlist_gate/2
)
```

then the decoder independently enforces the playground vocabulary while
walking the AST. Two protections:

```text
new atom                  → tokenizer refuses it
existing but unapproved   → literal decoder refuses it
```

`charlist_gate/2` is a minimal `literal_encoder` used **only** to reject
single-quoted charlists: it returns `{:error, message}` when the
literal's metadata carries `delimiter: "'"` (an ordinary charlist) or
`delimiter: "'''"` (a charlist heredoc), and `{:ok, literal}` — leaving
the AST completely unchanged — for everything else. Both delimiters have
to be listed: Elixir accepts `'''…'''` as a heredoc charlist, and the
metadata reports the opening delimiter as written. This is
necessary because `'abc'` parses to the plain list `[97, 98, 99]`, which
is indistinguishable from a typed integer list at the AST layer
(verified); only the tokenizer sees the delimiter. `emit_warnings:
false` suppresses the charlist deprecation warning that would otherwise
land in the server log on user input.

Do **not** use `literal_encoder` for anything beyond this gate — in
particular not for preserving literal positions (see the position caveat
below).

The security-sensitive AST decoding lives in its own internal module
(e.g. `FrmnPlay.Playground.Parser.MapLiteral`) rather than inline in
`Parser`, so the whole trusted surface is auditable in one place.

### The atom vocabulary

One **flat, version-pinned set** — split here into key and value atoms
for legibility but enforced as a single set. This is *the playground's
permitted atom vocabulary for Formentation v0.2.0*, not an authoritative
Formentation vocabulary (see the Formentation finding below).

Verified against the v0.2.0 Map adapter source:

```text
Key atoms
  kind  properties  required  title  help  groups
  id  fields
  role  widget  one_of  default  examples  hidden  read_only
  min_length  max_length  min  max

Kind values
  object  string  integer  number  boolean
  array          # solely so the unsupported-kind example can exist

Widget values   (the hints the reference renderer honors)
  text  textarea  select  radio  checkbox

Role values     (the roles the reference renderer recognizes)
  date  email  uri
```

Notes pinned from verification:

- The label key is `:title`; there is no `:label` declaration key
  (`label` exists only as an origin key).
- `role` accepts any non-nil atom and `widget` any atom at the adapter
  boundary; incompatible widget hints degrade at render time with a
  `:widget_fallback` warning. `kind` likewise accepts arbitrary atoms,
  compiling unknown kinds to preserve-only unsupported nodes with an
  `:unsupported_kind` warning.
- Position-aware validation (only kind-atoms after `kind:`, etc.) is
  deliberately **not** done — it would duplicate Formentation's own
  validation while buying nothing. After the whitelist grammar and
  reconstruction, an atom in the decoded term is inert data; the
  allowlist is a legibility/conservatism measure, not the security
  boundary (that is `existing_atoms_only` plus never evaluating).

**Accepted cost, stated honestly:** because `role`, `widget`, and
`kind` are open-ended at the adapter boundary, the playground *narrows
Formentation's actual acceptance*. A user cannot type
`role: :phone_number` to watch inference fall back, even though
Formentation would handle it gracefully. The `atom_not_allowed` error
message lists the permitted atoms so the restriction is self-explaining.

### Limits: resource-safety envelope, not 16/1000

Formentation's `max_depth: 16` measures **declaration nesting depth**;
its `max_nodes: 1000` measures **declaration nodes consumed during
compilation** (both defaults verified in v0.2.0). The literal decoder's
AST node count includes every map, list, property pair, key atom, and
string — a valid ~201-node Formentation declaration with 200 fields
consumes many times that in AST nodes. Reusing 16/1000 at the parser
layer would not make the limits agree; it would make the parser
accidentally much stricter. The two layers deliberately measure
different things:

```text
Playground parser (resource safety)
  source size, per document:   64 KiB    checked BEFORE tokenization
  literal/container depth:     64
  decoded/AST nodes:           10,000

Formentation compile (declaration complexity)
  semantic depth:              16
  declaration nodes:           1,000
```

The parser numbers are a generous envelope, not sacred; what is pinned
is the separation of concerns and that the byte cap runs before the
tokenizer.

### Shared byte cap for all documents (M2 hardening)

M2 shipped JSON parsing with no input-size bound; `Parser.decode/2`
calls `Jason.decode/1` (recursive descent, no input or depth limit of
its own) on unbounded text, and the playground must not rely on
transport-level frame limits it doesn't control. Since this milestone
introduces the Parser's security envelope and its threat model claims
"source byte size is checked before parsing," that claim must hold for
**every** editable document, not just Elixir declarations.

The 64 KiB cap therefore becomes a shared Parser policy: per document
(not summed), checked before any tokenizer or decoder runs, reported as
`:input_too_large` with the standard `document:` field, with its own
regression test for the JSON path alongside the Elixir ones.

---

## Error shape: one family, expanded codes

Keep the M2 parser-error map; do not invent a second shape. Extend the
`code` type:

```text
JSON
  invalid_json        Jason syntax failure
  expected_object     valid JSON, wrong top-level shape

Elixir
  invalid_elixir      tokenizer/parser syntax failure
  expected_map        valid literal, wrong top-level shape
  forbidden_syntax    valid Elixir syntax outside the literal grammar
  atom_not_allowed    existing atom not in the playground vocabulary

Shared
  input_too_large     source exceeds the per-document byte cap
  ast_too_deep        decoder depth limit exceeded
  ast_too_large       decoder node limit exceeded
```

The three limit errors get distinct codes because they are useful
security/debugging information and straightforward to test.

Example:

```elixir
%{
  document: :declaration,
  code: :forbidden_syntax,
  message: "function calls are not allowed",
  position: nil,
  line: 4,
  column: 12
}
```

Position conventions per family — no forcing Elixir into Jason's
byte-offset model:

```text
Jason:   position = byte offset; line/column derived, byte-based (M2 rule)
Elixir:  position = nil; line/column from native parser/AST metadata
         where available
```

**Position caveat, pinned:** not every literal AST node carries
metadata — Elixir's own docs note that strings, lists, and two-element
tuples normally contain none. Decoder errors may therefore have
`line`/`column` of `nil`. A `literal_encoder` could preserve positions;
that complexity is deliberately out of scope for M3.

The existing `parse_error_list` component renders **both** families —
same shape, same ownership (attempted editor contents, Sources side).
The M2 distinction between playground parse errors and Formentation
diagnostics is unchanged.

---

## Built-in Map examples: exactly three

**`talk-proposal-map` — "Talk proposal."** The essential example: the
M2 talk-proposal rewritten in the Map source, producing substantially
the same visible form, enabling direct side-by-side source comparison.
Its description notes that the Map source declares semantic and
presentation facts inline.

"Substantially the same visible form" is an enforced invariant, not an
aspiration: `examples_test.exs` compares the two examples' observable
presentation — layout tree, labels, help, widgets, roles, value types,
requiredness, options, defaults and constraints — and fails on drift.
Provenance and validation are deliberately excluded: origins name JSON
pointers on one side, and only the JSON Schema source carries a
validation plan. One consequence is worth knowing before editing the
pair: a JSON Schema `properties` object is decoded into a map, so nested
field order is not the authored order (`contact` renders city before
street). The Map twin's ordered `properties:` list has to match what the
JSON twin actually renders, not what its source text reads.

**`pump-inspection` — "Pump inspection."** Demonstrates Map syntax on
its own terms rather than as "the JSON example rewritten": ordered
`{name, spec}` pairs, `one_of`, `widget: :radio`/`:textarea`,
`role: :date`, constraints, groups. This is the idiomatic example from
Formentation's own Map documentation/fixtures.

**`unsupported-kind` — "Unsupported kind."** A declaration containing
something like:

```elixir
{"tags", %{kind: :array}}
```

with initial JSON data containing the preserved value. Verified against
v0.2.0: an unknown kind is **non-fatal** — a successful compile with a
`severity: :warning`, `code: :unsupported_kind` diagnostic and a
preserve-only unsupported semantic node. This example is why `:array`
is in the atom vocabulary, and it gives Map mode the same
warning-diagnostics demonstration `unsupported-array` gives JSON Schema
mode. Its data round-trip through submit is pinned by test.

The built-in invariant is unchanged and already implemented by
`initialize_from_example!/1`: **every registered example must
initialize successfully; accepted warning diagnostics do not count as
failure.**

(Footnote from verification, for possible later use: `default: nil`
also compiles successfully with an `:unsupported_keyword` warning —
another warning-producing example candidate if one is ever wanted.)

---

## UI shape

Map mode's Sources column:

```text
Elixir Map
────────────────────────────────────

Declaration                         ●
┌──────────────────────────────────┐
│ %{                               │
│   kind: :object,                 │
│   ...                            │
│ }                                │
└──────────────────────────────────┘

Presentation
┌──────────────────────────────────┐
│ Defined inline                   │
│                                  │
│ Map declarations contain their   │
│ groups, roles and widget hints.  │
└──────────────────────────────────┘

Initial instance                    ●
┌──────────────────────────────────┐
│ { ... JSON ... }                 │
└──────────────────────────────────┘

                     [Apply sources]
```

The presentation panel is a small informational panel, **not** a
disabled editor: no textarea, no editor ID, no input name, no dirty
dot, no `phx-change` behavior, no accepted text. In JSON Schema mode
the M2 three-editor layout is unchanged.

The single `sources-form` design still works: Map mode simply submits
two controls instead of three. The LiveView's `edit_sources` helper
already defaults a missing presentation parameter to the Session value
(verified), so the web layer is naturally compatible once the core
invariant makes that value `nil` — and the core-level
`edit_presentation` no-op backs it up regardless.

### M2 contracts unchanged

These are established page behavior, not source-specific behavior, and
M3 must not disturb them:

```text
successful Apply / load / reset → DOM revision bump
failed Apply                    → no bump
dirty indicator                 → whole right pane is stale
parse errors                    → Sources side
compile warnings                → Preview side
textarea value                  → no injected whitespace
example switch                  → destructive, no confirmation
preview namespace               → "preview"
```

---

## Implementation order

1. **Restricted literal decoder, pure and isolated.** Its own internal
   module (all security-sensitive AST handling in one auditable place),
   TDD'd against the grammar table, atom vocabulary, and limits.
2. **`Parser.parse_declaration(:map, text)` integration** — common
   error shape, extended codes, the shared per-document byte cap
   (including the JSON paths).
3. **Session/Example source asymmetry** — widen `source` types, permit
   `nil` presentation, enforce always-clean/no-edit presentation on Map
   Sessions.
4. **Source-conditional parsing/compilation** — Map skips presentation
   parsing and omits `ui:`.
5. **Map examples and registry tests.**
6. **Source-aware LiveView UI** — grouped example selector, dynamic
   source header, inline-presentation panel.
7. **LiveView regressions, then the Playwright exit scenario.**

Do not start any UI work until the Session can truthfully represent
"this source has no presentation document."

---

## Test split

For the security tests, emphasize **grammar coverage rather than
enumerating every dangerous Elixir feature**: a whitelist decoder plus
representative rejection tests is more robust than claiming an
exhaustive blacklist.

| Layer | Important M3 coverage |
| --- | --- |
| Literal decoder | each accepted literal class; unary negative/positive numerics; pair tuples; keyword sugar; charlist rejection; map-update rejection; 3+-tuple rejection; calls, aliases, variables, captures, sigils, interpolation, structs, blocks, special forms all rejected; atom allowlist; **randomized unknown atom is not interned** (regression); byte/depth/node limits each with their distinct code |
| `Parser` | `:map` dispatch; structured `invalid_elixir`; forbidden-node line/column where metadata exists and `nil` where it doesn't; `expected_map`; `input_too_large` on JSON documents too; existing JSON behavior unchanged |
| Playground core | Map Session invariant (`presentation_* == nil`, never dirty); `edit_presentation` no-op on Map; successful/failed Map Apply; failed Apply preserves last good preview (M1 pinned rule, now for `:map`); Map compile omits `ui:`; all Map examples initialize; `unsupported-kind` data round-trips through submit |
| Examples | Map declarations stay formatter-clean so they are editable in the textarea; the `talk-proposal`/`talk-proposal-map` pair presents the same observable form (source-equivalence fixture) |
| LiveViewTest | selecting a Map example changes source; declaration/data editors present; presentation panel shows the inline explanation with no input and no `<label>`; source-aware header; switching back to JSON Schema restores the third editor; textarea round-trip, dirty, revision and destructive switching pinned in Map mode too; diagnostics placement unchanged |
| Playwright | JSON → Map example → edit Elixir declaration → Apply → interact → Submit → decoded instance → switch back to JSON Schema → actual browser textarea/form state is reset |

---

## Acceptance criteria

Milestone 3 is complete when all of the following are true:

- [x] No code path evaluates submitted text (`Code.eval_string/`
      `Code.eval_quoted` absent from the parser pipeline); the decoder
      reconstructs terms from validated AST.
- [x] The decoder is an acceptance whitelist: every AST node outside
      the documented literal grammar is rejected with a structured
      error.
- [x] `Code.string_to_quoted/2` runs with `existing_atoms_only: true`;
      a test proves parsing an unknown atom does not intern it.
- [x] The playground atom vocabulary is the documented flat set; an
      existing-but-unapproved atom yields `atom_not_allowed` listing
      the permitted atoms.
- [x] Per-document byte cap (64 KiB) is enforced before
      tokenization/decoding for **all** documents, JSON included, with
      code `input_too_large`.
- [x] Decoder depth/node limits (64 / 10,000) are enforced with
      distinct codes; Formentation's 16/1000 compile budgets are left
      untouched.
- [x] Parse errors for both families render through the one
      `parse_error_list` component with the shared error shape.
- [x] A Map Session holds no presentation document: `presentation_text`
      and both accepted presentation fields are `nil`,
      `presentation_dirty?` is always false, `edit_presentation/2` is a
      no-op, and compilation passes no `ui:`.
- [x] `Session.t()`/`Example.t()` are widened to
      `:json_schema | :map`; instance data remains JSON in both modes.
- [x] Source switching is example-driven only; the selector groups
      examples by source and the header reflects the loaded source.
- [x] The three Map examples (`talk-proposal-map`, `pump-inspection`,
      `unsupported-kind`) are registered; every registered example
      initializes successfully; `unsupported-kind` compiles with the
      expected accepted warning and its data round-trips on submit.
- [x] Map mode renders declaration and data editors plus the
      informational presentation panel (no input semantics); JSON
      Schema mode is visually unchanged.
- [x] All M2 contracts (DOM revision, dirty indicator, diagnostics
      placement, textarea whitespace, destructive switching, `preview`
      namespace) hold in both modes.
- [x] The Playwright exit scenario passes.

---

## Non-goals

- source conversion (JSON Schema ↔ Map);
- a standalone source toggle;
- a separate or editable Map presentation document, derived or
  otherwise;
- Elixir syntax for instance data;
- `Code.eval_*` under any flag;
- atom creation (`String.to_atom/1` anywhere, including encoders);
- formatting/rewriting the accepted term back into editor text;
- preserving comments;
- a general-purpose safe-Elixir parser (only this Map-declaration
  literal grammar);
- a `literal_encoder` for grapheme-perfect literal positions;
- a Formentation vocabulary API (recorded as a finding instead).

---

## Formentation findings (recorded, not blocking)

1. **No public vocabulary API.** There is no API exposing the Map
   source's declaration vocabulary, and parts of the source (`role`,
   `widget`, unsupported `kind`) are intentionally open-ended atoms.
   The playground therefore maintains a deliberately narrower,
   version-pinned vocabulary, hardcoded for v0.2.0 rather than adding a
   Formentation API prematurely (the dependency is pinned anyway).
2. **No presentation serialization.** `Formentation.Info` exposes the
   compiled presentation, but nothing turns a compiled presentation
   back into a user-facing source document. This is why Map mode shows
   an informational panel rather than a derived read-only document — and
   it is exactly the kind of asymmetry evidence to weigh before ever
   considering a source-neutral presentation overlay in Formentation.

---

## Exit criteria

The user can switch between JSON Schema and Map examples through the
example selector and edit both safely through the same Session model —
proven end-to-end by the Playwright scenario.

M3 proves that one Session can host sources with different document
shapes: JSON Schema has declaration + presentation + data, while Map
has declaration + data with presentation embedded in the declaration.
The web layer reflects that asymmetry without inventing a
source-neutral presentation document.
