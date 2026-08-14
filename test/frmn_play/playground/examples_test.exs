defmodule FrmnPlay.Playground.ExamplesTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground.{Example, Examples}

  test "default/0 returns the talk-proposal example" do
    example = Examples.default()

    assert %Example{id: "talk-proposal", source: :json_schema} = example
    assert example.title == "Talk proposal"
  end

  test "all JSON Schema example documents are valid JSON" do
    for example <- Examples.all(),
        example.source == :json_schema,
        text <- [example.declaration_text, example.presentation_text, example.data_text] do
      assert {:ok, _decoded} = Jason.decode(text)
    end
  end

  test "all/0 lists built-in examples in order" do
    assert [
             "talk-proposal",
             "basic-fields",
             "unsupported-array",
             "talk-proposal-map",
             "pump-inspection",
             "unsupported-kind"
           ] =
             Enum.map(Examples.all(), & &1.id)
  end

  test "get!/1 returns the example with the given id" do
    assert %Example{id: "talk-proposal"} = Examples.get!("talk-proposal")
  end

  test "get!/1 raises on an unknown id" do
    assert_raise KeyError, fn -> Examples.get!("does-not-exist") end
  end

  test "all/0 lists the built-in examples" do
    all = Examples.all()

    assert Enum.any?(all, &(&1.id == "talk-proposal"))
    assert Enum.all?(all, &match?(%Example{}, &1))
  end

  describe "map examples" do
    test "follow the JSON examples and have no presentation document" do
      assert Enum.map(Examples.all(), & &1.source) == [
               :json_schema,
               :json_schema,
               :json_schema,
               :map,
               :map,
               :map
             ]

      for example <- Examples.all(), example.source == :map do
        assert example.presentation_text == nil
      end
    end

    test "initialize successfully, including the accepted unsupported-kind warning" do
      alias FrmnPlay.Playground

      for id <- ["talk-proposal-map", "pump-inspection"] do
        session = Playground.load_example(Playground.start_session(), id)
        assert session.diagnostics == []
        assert %Formentation.Form{} = session.form
      end

      session = Playground.load_example(Playground.start_session(), "unsupported-kind")

      assert [%Formentation.Diagnostic{severity: :warning, code: :unsupported_kind}] =
               session.diagnostics

      submitted = Playground.submit_preview(session, %{"title" => "Existing record"})
      assert submitted.submitted["tags"] == ["elixir", "phoenix"]
    end
  end
end
