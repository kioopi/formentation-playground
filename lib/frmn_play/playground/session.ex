defmodule FrmnPlay.Playground.Session do
  @moduledoc """
  Non-persistent playground state, held in the LiveView socket and
  transformed exclusively through `FrmnPlay.Playground` functions.

  The struct separates two layers:

  * **current editor state** — the source texts as the user typed them,
    plus the outcome of the most recent apply attempt;
  * **last accepted state** — the texts and parsed documents of the last
    successful apply, the `%Formentation.Form{}` compiled from them, and
    that compile's diagnostics.

  `diagnostics` always describes the accepted form; failed applies never
  touch it. A failed apply records its problem in exactly one of two
  places, depending on where it failed:

  * a parse failure (invalid JSON, wrong shape) sets `apply_errors` to the
    offending documents' messages;
  * a compile failure sets `apply_diagnostics` to the full
    `Formentation.Diagnostic.t()` list the compiler produced, unflattened,
    so the playground can inspect diagnostic code, severity, and origin
    rather than just a rendered message.

  The other field is always `[]` in each case.
  """

  @enforce_keys [:source, :example_id]

  defstruct [
    :source,
    :example_id,

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
    :form,
    diagnostics: [],

    # Result of the most recent apply attempt on current editor contents:
    # a parse failure populates apply_errors, a compile failure populates
    # apply_diagnostics, a success clears both.
    apply_errors: [],
    apply_diagnostics: [],

    # Last accepted submission result
    submitted: nil
  ]

  @type apply_error :: %{
          document: :declaration | :presentation | :data,
          message: String.t()
        }

  @type t :: %__MODULE__{
          source: :json_schema,
          example_id: String.t(),
          declaration_text: String.t() | nil,
          presentation_text: String.t() | nil,
          data_text: String.t() | nil,
          accepted_declaration_text: String.t() | nil,
          accepted_presentation_text: String.t() | nil,
          accepted_data_text: String.t() | nil,
          accepted_declaration: map() | nil,
          accepted_presentation: map() | nil,
          accepted_data: map() | nil,
          form: Formentation.Form.t() | nil,
          diagnostics: [Formentation.Diagnostic.t()],
          apply_errors: [apply_error()],
          apply_diagnostics: [Formentation.Diagnostic.t()],
          submitted: map() | nil
        }

  @spec declaration_dirty?(t()) :: boolean()
  def declaration_dirty?(%__MODULE__{} = s), do: s.declaration_text != s.accepted_declaration_text

  @spec presentation_dirty?(t()) :: boolean()
  def presentation_dirty?(%__MODULE__{} = s),
    do: s.presentation_text != s.accepted_presentation_text

  @spec data_dirty?(t()) :: boolean()
  def data_dirty?(%__MODULE__{} = s), do: s.data_text != s.accepted_data_text

  @spec dirty?(t()) :: boolean()
  def dirty?(%__MODULE__{} = s),
    do: declaration_dirty?(s) or presentation_dirty?(s) or data_dirty?(s)

  @spec has_preview?(t()) :: boolean()
  def has_preview?(%__MODULE__{} = s), do: s.form != nil

  @spec has_apply_errors?(t()) :: boolean()
  def has_apply_errors?(%__MODULE__{} = s), do: s.apply_errors != []

  @spec has_apply_diagnostics?(t()) :: boolean()
  def has_apply_diagnostics?(%__MODULE__{} = s), do: s.apply_diagnostics != []

  @spec has_diagnostics?(t()) :: boolean()
  def has_diagnostics?(%__MODULE__{} = s), do: s.diagnostics != []

  @spec has_submission?(t()) :: boolean()
  def has_submission?(%__MODULE__{} = s), do: s.submitted != nil
end
