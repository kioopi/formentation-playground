defmodule FrmnPlay.Playground.Example do
  @moduledoc """
  A built-in playground example: three source documents (declaration,
  presentation hints, initial instance data) plus display metadata.

  The documents are stored as text in the syntax of `source`, exactly as
  they will appear in the playground editors.
  """

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

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t() | nil,
          source: :json_schema,
          declaration_text: String.t(),
          presentation_text: String.t(),
          data_text: String.t()
        }
end
