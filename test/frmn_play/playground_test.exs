defmodule FrmnPlay.PlaygroundTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground
  alias FrmnPlay.Playground.{Example, Session}

  describe "examples/0" do
    test "lists the built-in examples as public Example values" do
      examples = Playground.examples()

      assert Enum.any?(examples, &(&1.id == "talk-proposal"))
      assert Enum.all?(examples, &match?(%Example{}, &1))
    end
  end

  describe "built-in examples" do
    test "every registered example loads successfully" do
      session = Playground.start_session()

      for example <- Playground.examples() do
        loaded = Playground.load_example(session, example.id)
        assert loaded.form != nil
        assert loaded.apply_errors == []
        assert loaded.apply_diagnostics == []
      end
    end

    test "basic-fields compiles with zero diagnostics" do
      session = Playground.load_example(Playground.start_session(), "basic-fields")
      assert session.diagnostics == []
    end

    test "unsupported-array compiles with the expected accepted warning" do
      session = Playground.load_example(Playground.start_session(), "unsupported-array")

      assert [diagnostic] = session.diagnostics
      assert diagnostic.severity == :warning
      assert diagnostic.code == :unsupported_type
      assert diagnostic.message =~ "tags"
      assert diagnostic.origin == {:json_schema, "/properties/tags/type"}
    end

    test "unsupported-array preserves the initial array data through submit" do
      session = Playground.load_example(Playground.start_session(), "unsupported-array")

      submitted =
        Playground.submit_preview(session, %{"title" => "Existing record"}).submitted

      assert submitted["title"] == "Existing record"
      assert submitted["tags"] == ["elixir", "phoenix"]
    end
  end

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
      assert session.apply_diagnostics == []
      assert session.submitted == nil
      refute Session.has_submission?(session)
      refute Session.has_apply_errors?(session)
      refute Session.has_apply_diagnostics?(session)
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

    test "a failed compile records apply diagnostics, not apply errors" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_declaration(~s({"type": "string"}))
        |> Playground.apply_sources()

      assert [%Formentation.Diagnostic{} | _rest] = applied.apply_diagnostics
      assert applied.apply_errors == []
      assert Session.has_apply_diagnostics?(applied)
      refute Session.has_apply_errors?(applied)
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
      assert applied.apply_diagnostics == []
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

    test "a JSON array data document is an apply error, not a crash" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_data("[]")
        |> Playground.apply_sources()

      assert [%{document: :data, message: _message}] = applied.apply_errors
      assert applied.accepted_data == session.accepted_data
      assert applied.form == session.form
      assert Session.has_preview?(applied)
    end

    test "a JSON null data document is an apply error, not a crash" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_data("null")
        |> Playground.apply_sources()

      assert [%{document: :data, message: _message}] = applied.apply_errors
      assert applied.accepted_data == session.accepted_data
      assert Session.has_preview?(applied)
    end

    test "a JSON string data document is an apply error, not a crash" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_data(~s("foo"))
        |> Playground.apply_sources()

      assert [%{document: :data, message: _message}] = applied.apply_errors
      assert applied.accepted_data == session.accepted_data
      assert Session.has_preview?(applied)
    end

    test "a JSON array declaration document is an apply error, not a crash" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_declaration("[]")
        |> Playground.apply_sources()

      assert [%{document: :declaration, message: _message}] = applied.apply_errors
      assert applied.accepted_declaration == session.accepted_declaration
      assert Session.has_preview?(applied)
    end

    test "a JSON array presentation document is an apply error, not a crash" do
      session = Playground.start_session()

      applied =
        session
        |> Playground.edit_presentation("[]")
        |> Playground.apply_sources()

      assert [%{document: :presentation, message: _message}] = applied.apply_errors
      assert applied.accepted_presentation == session.accepted_presentation
      assert Session.has_preview?(applied)
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

  describe "map source mode" do
    @map_declaration """
    %{
      kind: :object,
      title: "Map demo",
      required: ["name"],
      properties: [{"name", %{kind: :string, title: "Name", min_length: 1}}]
    }
    """

    defp map_session do
      Playground.apply_sources(%Session{
        source: :map,
        example_id: "map-test",
        declaration_text: @map_declaration,
        presentation_text: nil,
        data_text: ~s({"name": "Ada"})
      })
    end

    test "applies without a presentation document" do
      session = map_session()

      assert session.apply_errors == []
      assert session.apply_diagnostics == []
      assert %Formentation.Form{} = session.form
      assert session.diagnostics == []
      assert %{kind: :object} = session.accepted_declaration
      assert session.accepted_presentation_text == nil
      assert session.accepted_presentation == nil
      refute Playground.dirty?(session)
    end

    test "presentation edits are ignored and never dirty" do
      session = map_session()
      edited = Playground.edit_presentation(session, ~s({"anything": true}))

      assert edited == session
      assert edited.presentation_text == nil
      refute Playground.presentation_dirty?(edited)
    end

    test "failed parses retain the last accepted preview" do
      session = map_session()

      failed =
        session
        |> Playground.edit_declaration("foo()")
        |> Playground.apply_sources()

      assert [%{document: :declaration, code: :forbidden_syntax}] = failed.apply_errors
      assert failed.apply_diagnostics == []
      assert failed.form == session.form
      assert failed.accepted_declaration == session.accepted_declaration
      assert failed.diagnostics == session.diagnostics
    end

    test "compile failures and submissions use the Map adapter" do
      bad = ~s(%{kind: :object, properties: [{"x", %{kind: :string, title: 5}}]})

      failed =
        map_session()
        |> Playground.edit_declaration(bad)
        |> Playground.apply_sources()

      assert failed.apply_errors == []
      assert [%Formentation.Diagnostic{severity: :error} | _] = failed.apply_diagnostics

      submitted = Playground.submit_preview(map_session(), %{"name" => "Grace"})
      assert submitted.submitted == %{"name" => "Grace"}
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
