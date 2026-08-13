defmodule FrmnPlay.PlaygroundTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground
  alias FrmnPlay.Playground.Session

  describe "start_session/0" do
    test "loads the default example" do
      session = Playground.start_session()

      assert %Session{source: :json_schema, example_id: "talk-proposal"} = session
    end

    test "editor texts and accepted texts are in sync" do
      session = Playground.start_session()

      assert session.declaration_text == session.accepted_declaration_text
      assert session.presentation_text == session.accepted_presentation_text
      assert session.data_text == session.accepted_data_text
      refute Session.dirty?(session)
    end

    test "accepted documents are parsed" do
      session = Playground.start_session()

      assert %{"type" => "object"} = session.accepted_declaration
      assert %{"groups" => _groups} = session.accepted_presentation
      assert %{"track" => "Elixir"} = session.accepted_data
    end

    test "a form is compiled without diagnostics" do
      session = Playground.start_session()

      assert %Formentation.Form{} = session.form
      assert session.diagnostics == []
      assert Session.has_preview?(session)
    end

    test "there is no submission or apply-error state" do
      session = Playground.start_session()

      assert session.apply_errors == []
      assert session.submitted == nil
      refute Session.has_submission?(session)
      refute Session.has_apply_errors?(session)
    end
  end

  describe "validate_preview/2" do
    test "stores the validated form and preserves raw input" do
      session = Playground.start_session()

      validated = Playground.validate_preview(session, %{"duration_minutes" => "abc"})

      assert validated.form != session.form
      assert Formentation.Form.field(validated.form, ["duration_minutes"]).display_value == "abc"
    end

    test "clears a previous submission result" do
      submitted_session =
        Playground.start_session()
        |> Playground.submit_preview(valid_params())

      assert Session.has_submission?(submitted_session)

      validated = Playground.validate_preview(submitted_session, %{"title" => "Changed"})

      refute Session.has_submission?(validated)
    end
  end

  describe "submit_preview/2" do
    test "an accepted submission stores the submitted form and decoded instance" do
      session = Playground.start_session()

      submitted = Playground.submit_preview(session, valid_params())

      assert submitted.form != session.form
      assert %{"duration_minutes" => 45, "first_time" => true} = submitted.submitted
      assert %{"contact" => %{"city" => "Berlin"}} = submitted.submitted
    end

    test "a rejected submission stores the submitted form and no instance" do
      session = Playground.start_session()

      submitted = Playground.submit_preview(session, %{"duration_minutes" => "abc"})

      assert submitted.form != session.form
      assert submitted.submitted == nil
      assert Formentation.Form.field(submitted.form, ["duration_minutes"]).display_value == "abc"
    end
  end

  describe "edit actions" do
    test "editing text does not parse, compile, or touch the preview" do
      session = Playground.start_session()

      edited = Playground.edit_declaration(session, "{ not even json")

      assert edited.declaration_text == "{ not even json"
      assert edited.accepted_declaration_text == session.accepted_declaration_text
      assert edited.accepted_declaration == session.accepted_declaration
      assert edited.form == session.form
      assert Session.has_preview?(edited)
      assert Session.declaration_dirty?(edited)
      assert Session.dirty?(edited)
    end

    test "presentation and data edits behave the same way" do
      session = Playground.start_session()

      edited =
        session
        |> Playground.edit_presentation("{ nope")
        |> Playground.edit_data("{ nope")

      assert Session.presentation_dirty?(edited)
      assert Session.data_dirty?(edited)
      assert edited.form == session.form
    end
  end

  describe "apply_sources/1" do
    test "a failed parse preserves the last good preview and its diagnostics" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_declaration("{ not even json")
        |> Playground.apply_sources()

      assert [%{document: :declaration, message: _message}] = applied.apply_errors
      assert applied.accepted_declaration_text == session.accepted_declaration_text
      assert applied.accepted_declaration == session.accepted_declaration
      assert applied.form == session.form
      assert applied.diagnostics == session.diagnostics
      assert Session.declaration_dirty?(applied)
    end

    test "a failed compile records apply errors, not diagnostics" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_declaration(~s({"type": "string"}))
        |> Playground.apply_sources()

      assert [%{document: :compile, message: _message} | _rest] = applied.apply_errors
      assert applied.accepted_declaration == session.accepted_declaration
      assert applied.form == session.form
      assert applied.diagnostics == session.diagnostics
      assert Session.declaration_dirty?(applied)
    end

    test "a successful apply replaces accepted state and rebuilds the form" do
      session = Playground.start_session()

      new_declaration =
        String.replace(session.declaration_text, "Talk title", "Session title")

      applied =
        session
        |> Playground.edit_declaration(new_declaration)
        |> Playground.apply_sources()

      assert applied.accepted_declaration_text == new_declaration
      assert applied.accepted_declaration["properties"]["title"]["title"] == "Session title"
      assert applied.form != session.form
      assert applied.apply_errors == []
      refute Session.dirty?(applied)
    end

    test "a successful apply clears a stale submission result" do
      applied =
        Playground.start_session()
        |> Playground.submit_preview(valid_params())
        |> Playground.apply_sources()

      refute Session.has_submission?(applied)
    end

    test "parse errors from several documents are all reported" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_declaration("{ nope")
        |> Playground.edit_data("[ nope")
        |> Playground.apply_sources()

      assert Enum.map(applied.apply_errors, & &1.document) == [:declaration, :data]
      assert applied.form == session.form
    end
  end

  describe "load_example/2" do
    test "replaces editor text, accepted state, and form, discarding dirty edits" do
      session = Playground.start_session()

      loaded =
        session
        |> Playground.edit_declaration("{ dirty edit")
        |> Playground.submit_preview(valid_params())
        |> Playground.load_example("talk-proposal")

      assert loaded.example_id == "talk-proposal"
      assert loaded.declaration_text == session.declaration_text
      assert loaded.accepted_declaration == session.accepted_declaration
      assert %Formentation.Form{} = loaded.form
      assert loaded.apply_errors == []
      assert loaded.submitted == nil
      refute Session.dirty?(loaded)
    end

    test "raises on an unknown example id" do
      session = Playground.start_session()

      assert_raise KeyError, fn -> Playground.load_example(session, "does-not-exist") end
    end
  end

  describe "reset_session/1" do
    test "discards edits and form interactions, restoring the example baseline" do
      session = Playground.start_session()

      reset =
        session
        |> Playground.edit_data("{ dirty")
        |> Playground.validate_preview(%{"title" => "typed something"})
        |> Playground.reset_session()

      assert reset.example_id == session.example_id
      assert reset.data_text == session.data_text
      assert Formentation.Form.field(reset.form, ["title"]).display_value in [nil, ""]
      assert reset.apply_errors == []
      refute Session.dirty?(reset)
    end
  end

  defp valid_params do
    %{
      "title" => "Formentation in anger",
      "track" => "Elixir",
      "level" => "intermediate",
      "duration_minutes" => "45",
      "abstract" => "Declaring forms as data.",
      "email" => "ada@example.com",
      "preferred_date" => "2026-09-01",
      "first_time" => "true",
      "contact" => %{"street" => "Hauptstr. 1", "city" => "Berlin"}
    }
  end
end
