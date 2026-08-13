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

  @doc """
  Runs `Formentation.Form.validate/2` on the current preview form.

  Clears a previous submission result: once the user edits the form again,
  the old submitted instance no longer describes the current preview.
  """
  @spec validate_preview(Session.t(), map()) :: Session.t()
  def validate_preview(%Session{form: %Formentation.Form{}} = session, params) do
    %{session | form: Formentation.Form.validate(session.form, params), submitted: nil}
  end

  @doc """
  Runs `Formentation.Form.submit/2` on the current preview form and stores
  the decoded instance when the submission is accepted.
  """
  @spec submit_preview(Session.t(), map()) :: Session.t()
  def submit_preview(%Session{form: %Formentation.Form{}} = session, params) do
    case Formentation.Form.submit(session.form, params) do
      {:ok, instance, submitted_form} ->
        %{session | form: submitted_form, submitted: instance}

      {:error, submitted_form} ->
        %{session | form: submitted_form, submitted: nil}
    end
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
