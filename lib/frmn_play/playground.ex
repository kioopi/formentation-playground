defmodule FrmnPlay.Playground do
  @moduledoc """
  Public API of the playground core.

  The web layer calls only this module; `FrmnPlay.Playground.*` submodules
  are implementation detail, except `FrmnPlay.Playground.Example`, the
  public value type returned by `default_example/0` and `examples/0`.
  `FrmnPlay.Playground.Session` structs are returned as values and their
  fields may be read directly, but their query functions are reached
  through the delegates below — templates never name the Session module.
  """

  alias FrmnPlay.Playground.{Example, Examples, Parser, Session}

  @spec default_example() :: Example.t()
  defdelegate default_example, to: Examples, as: :default

  @doc "All built-in playground examples."
  @spec examples() :: [Example.t()]
  defdelegate examples, to: Examples, as: :all

  @doc "True when the declaration editor text differs from the last accepted one."
  @spec declaration_dirty?(Session.t()) :: boolean()
  defdelegate declaration_dirty?(session), to: Session

  @doc "True when the presentation editor text differs from the last accepted one."
  @spec presentation_dirty?(Session.t()) :: boolean()
  defdelegate presentation_dirty?(session), to: Session

  @doc "True when the data editor text differs from the last accepted one."
  @spec data_dirty?(Session.t()) :: boolean()
  defdelegate data_dirty?(session), to: Session

  @doc "True when any editor text differs from the last accepted revision."
  @spec dirty?(Session.t()) :: boolean()
  defdelegate dirty?(session), to: Session

  @doc "True when the most recent apply attempt failed with parse errors."
  @spec has_apply_errors?(Session.t()) :: boolean()
  defdelegate has_apply_errors?(session), to: Session

  @doc "True when the most recent apply attempt failed with compile diagnostics."
  @spec has_apply_diagnostics?(Session.t()) :: boolean()
  defdelegate has_apply_diagnostics?(session), to: Session

  @doc "True when the accepted form compiled with warnings."
  @spec has_diagnostics?(Session.t()) :: boolean()
  defdelegate has_diagnostics?(session), to: Session

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

  @doc """
  Replaces the current presentation editor text. Nothing is parsed or
  compiled. A no-op on `:map` Sessions, which declare presentation inline.
  """
  @spec edit_presentation(Session.t(), String.t()) :: Session.t()
  def edit_presentation(%Session{source: :map} = session, _text), do: session
  def edit_presentation(%Session{} = session, text), do: %{session | presentation_text: text}

  @doc "Replaces the current data editor text. Nothing is parsed or compiled."
  @spec edit_data(Session.t(), String.t()) :: Session.t()
  def edit_data(%Session{} = session, text), do: %{session | data_text: text}

  @doc """
  Parses and compiles the current editor texts.

  On success the accepted state, form, and diagnostics are replaced and any
  stale apply errors, apply diagnostics, and submission result are cleared.

  On failure the accepted state, form, and diagnostics stay untouched — the
  preview keeps showing the last successfully applied revision — and the
  problem is recorded in exactly one of two fields:

  * a parse failure sets `apply_errors`;
  * a compile failure sets `apply_diagnostics` to the compiler's own
    `Formentation.Diagnostic.t()` list, unflattened, since the playground's
    purpose includes inspecting Formentation's diagnostics, not just
    displaying a message.
  """
  @spec apply_sources(Session.t()) :: Session.t()
  def apply_sources(%Session{} = session) do
    case parse_documents(session) do
      {:error, errors} ->
        %{session | apply_errors: errors, apply_diagnostics: []}

      {:ok, declaration, presentation, data} ->
        apply_compiled(session, declaration, presentation, data)
    end
  end

  defp apply_compiled(session, declaration, presentation, data) do
    case Formentation.form(declaration, compile_opts(session.source, presentation, data)) do
      {:ok, form, diagnostics} ->
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
            apply_diagnostics: [],
            submitted: nil
        }

      {:error, diagnostics} ->
        %{session | apply_errors: [], apply_diagnostics: diagnostics}
    end
  end

  defp parse_documents(%Session{source: :map} = session) do
    collect_parses([
      Parser.parse_declaration(:map, session.declaration_text),
      {:ok, nil},
      Parser.parse_data(session.data_text)
    ])
  end

  defp parse_documents(%Session{source: :json_schema} = session) do
    collect_parses([
      Parser.parse_declaration(:json_schema, session.declaration_text),
      Parser.parse_presentation(:json_schema, session.presentation_text),
      Parser.parse_data(session.data_text)
    ])
  end

  defp collect_parses(parses) do
    case for {:error, error} <- parses, do: error do
      [] ->
        [{:ok, declaration}, {:ok, presentation}, {:ok, data}] = parses
        {:ok, declaration, presentation, data}

      errors ->
        {:error, errors}
    end
  end

  defp compile_opts(:json_schema, presentation, data),
    do: [adapter: :json_schema, ui: presentation, data: data, defaults: :apply]

  defp compile_opts(:map, _presentation, data),
    do: [adapter: :map, data: data, defaults: :apply]

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

    if session.apply_errors != [] or session.apply_diagnostics != [] do
      raise "built-in example #{example.id} failed to apply: " <>
              inspect(session.apply_errors ++ session.apply_diagnostics)
    end

    session
  end
end
