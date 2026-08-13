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
