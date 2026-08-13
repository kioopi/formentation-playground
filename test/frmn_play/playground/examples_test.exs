defmodule FrmnPlay.Playground.ExamplesTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground.{Example, Examples}

  test "default/0 returns the talk-proposal example" do
    example = Examples.default()

    assert %Example{id: "talk-proposal", source: :json_schema} = example
    assert example.title == "Talk proposal"
  end

  test "example documents are valid JSON" do
    example = Examples.default()

    for text <- [example.declaration_text, example.presentation_text, example.data_text] do
      assert {:ok, _decoded} = Jason.decode(text)
    end
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
end
