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

  @doc "Replaces the current declaration editor text. Nothing is parsed or compiled."
  @spec edit_declaration(Session.t(), String.t()) :: Session.t()
  def edit_declaration(%Session{} = session, text), do: %{session | declaration_text: text}

  @doc "Replaces the current presentation editor text. Nothing is parsed or compiled."
  @spec edit_presentation(Session.t(), String.t()) :: Session.t()
  def edit_presentation(%Session{} = session, text), do: %{session | presentation_text: text}

  @doc "Replaces the current data editor text. Nothing is parsed or compiled."
  @spec edit_data(Session.t(), String.t()) :: Session.t()
  def edit_data(%Session{} = session, text), do: %{session | data_text: text}

  @doc """
  Parses and compiles the current editor texts.

  On success the accepted state, form, and diagnostics are replaced and any
  stale apply errors and submission result are cleared. On failure (parse
  or compile) the errors are recorded in `apply_errors` and the accepted
  state, form, and diagnostics stay untouched — the preview keeps showing
  the last successfully applied revision.
  """
  @spec apply_sources(Session.t()) :: Session.t()
  def apply_sources(%Session{} = session) do
    with {:ok, declaration, presentation, data} <- parse_documents(session),
         {:ok, form, diagnostics} <- compile_form(session.source, declaration, presentation, data) do
      %{
        session
        | accepted_declaration_text: session.declaration_text,
          accepted_presentation_text: session.presentation_text,
          accepted_data_text: session.data_text,
          accepted_declaration: declaration,
          accepted_presentation: presentation,
          accepted_data: data,
          form: form,
          diagnostics: diagnostics,
          apply_errors: [],
          submitted: nil
      }
    else
      {:error, errors} -> %{session | apply_errors: errors}
    end
  end

  defp parse_documents(%Session{source: source} = session) do
    parses = [
      Parser.parse_declaration(source, session.declaration_text),
      Parser.parse_presentation(source, session.presentation_text),
      Parser.parse_data(session.data_text)
    ]

    case for {:error, error} <- parses, do: error do
      [] ->
        [{:ok, declaration}, {:ok, presentation}, {:ok, data}] = parses
        {:ok, declaration, presentation, data}

      errors ->
        {:error, errors}
    end
  end

  defp compile_form(source, declaration, presentation, data) do
    case Formentation.form(declaration,
           adapter: source,
           ui: presentation,
           data: data,
           defaults: :apply
         ) do
      {:ok, form, diagnostics} ->
        {:ok, form, diagnostics}

      {:error, diagnostics} ->
        {:error, Enum.map(diagnostics, &%{document: :compile, message: &1.message})}
    end
  end

  @doc """
  Replaces the whole Session with a freshly initialized one for the given
  example. Dirty edits, apply errors, form interactions, and the submitted
  result are all discarded.

  Raises on an unknown example id — built-in ids are programmer-controlled.
  """
  @spec load_example(Session.t(), String.t()) :: Session.t()
  def load_example(%Session{}, example_id) do
    initialize_from_example!(Examples.get!(example_id))
  end

  @doc "Resets the Session to the baseline of its currently loaded example."
  @spec reset_session(Session.t()) :: Session.t()
  def reset_session(%Session{} = session), do: load_example(session, session.example_id)

  defp initialize_from_example!(%Example{} = example) do
    session =
      apply_sources(%Session{
        source: example.source,
        example_id: example.id,
        declaration_text: example.declaration_text,
        presentation_text: example.presentation_text,
        data_text: example.data_text
      })

    if session.apply_errors != [] do
      raise "built-in example #{example.id} failed to apply: #{inspect(session.apply_errors)}"
    end

    session
  end
end
