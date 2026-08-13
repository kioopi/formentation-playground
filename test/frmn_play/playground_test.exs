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
end
