defmodule FrmnPlay.Playground do
  @moduledoc """
  Public API of the playground core.

  The web layer calls only this module; `FrmnPlay.Playground.*` submodules
  are implementation detail.
  """

  alias FrmnPlay.Playground.{Example, Examples, Parser, Session}

  @spec default_example() :: Example.t()
  defdelegate default_example, to: Examples, as: :default

  @doc """
  Creates a Session from the default example, parsed and compiled so the
  returned Session is immediately renderable.

  Built-in examples are expected to parse and compile; a failure here is a
  bug in the example and raises.
  """
  @spec start_session() :: Session.t()
  def start_session do
    initialize_from_example!(Examples.default())
  end

  defp initialize_from_example!(%Example{} = example) do
    {:ok, declaration} = Parser.parse_declaration(example.source, example.declaration_text)
    {:ok, presentation} = Parser.parse_presentation(example.source, example.presentation_text)
    {:ok, data} = Parser.parse_data(example.data_text)

    {:ok, form, diagnostics} =
      Formentation.form(declaration,
        adapter: example.source,
        ui: presentation,
        data: data,
        defaults: :apply
      )

    %Session{
      source: example.source,
      example_id: example.id,
      declaration_text: example.declaration_text,
      presentation_text: example.presentation_text,
      data_text: example.data_text,
      accepted_declaration_text: example.declaration_text,
      accepted_presentation_text: example.presentation_text,
      accepted_data_text: example.data_text,
      accepted_declaration: declaration,
      accepted_presentation: presentation,
      accepted_data: data,
      form: form,
      diagnostics: diagnostics
    }
  end
end
