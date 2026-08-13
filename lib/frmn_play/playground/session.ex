defmodule FrmnPlay.Playground.Session do
  @moduledoc """
  Non-persistent playground state, held in the LiveView socket and
  transformed exclusively through `FrmnPlay.Playground` functions.

  The struct separates two layers:

  * **current editor state** — the source texts as the user typed them,
    plus the errors of the most recent apply attempt;
  * **last accepted state** — the texts and parsed documents of the last
    successful apply, the `%Formentation.Form{}` compiled from them, and
    that compile's diagnostics.

  `diagnostics` always describes the accepted form; failed applies record
  their errors in `apply_errors` and never touch `diagnostics`.
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

    # Result of the most recent apply attempt on current editor contents
    apply_errors: [],

    # Last accepted submission result
    submitted: nil
  ]

  @type apply_error :: %{
          document: :declaration | :presentation | :data | :compile,
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

  @spec has_diagnostics?(t()) :: boolean()
  def has_diagnostics?(%__MODULE__{} = s), do: s.diagnostics != []

  @spec has_submission?(t()) :: boolean()
  def has_submission?(%__MODULE__{} = s), do: s.submitted != nil
end
