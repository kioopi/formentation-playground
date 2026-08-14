defmodule FrmnPlay.Playground.ParserTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground.Parser

  describe "parse_declaration/2" do
    test "rejects a JSON array" do
      assert {:error, %{document: :declaration, message: message}} =
               Parser.parse_declaration(:json_schema, "[]")

      assert message =~ "JSON object"
    end

    test "rejects a JSON null" do
      assert {:error, %{document: :declaration, message: _}} =
               Parser.parse_declaration(:json_schema, "null")
    end

    test "rejects a JSON string" do
      assert {:error, %{document: :declaration, message: _}} =
               Parser.parse_declaration(:json_schema, ~s("hello"))
    end

    test "accepts a JSON object" do
      assert {:ok, %{"type" => "object"}} =
               Parser.parse_declaration(:json_schema, ~s({"type": "object"}))
    end
  end

  describe "parse_presentation/2" do
    test "rejects a JSON array" do
      assert {:error, %{document: :presentation, message: message}} =
               Parser.parse_presentation(:json_schema, "[]")

      assert message =~ "JSON object"
    end
  end

  describe "parse_data/1" do
    test "rejects a JSON array" do
      assert {:error, %{document: :data, message: message}} = Parser.parse_data("[]")
      assert message =~ "JSON object"
    end

    test "rejects a JSON null" do
      assert {:error, %{document: :data, message: _}} = Parser.parse_data("null")
    end

    test "rejects a JSON number" do
      assert {:error, %{document: :data, message: _}} = Parser.parse_data("42")
    end

    test "rejects a JSON string" do
      assert {:error, %{document: :data, message: _}} = Parser.parse_data(~s("foo"))
    end

    test "accepts a JSON object" do
      assert {:ok, %{"track" => "Elixir"}} = Parser.parse_data(~s({"track": "Elixir"}))
    end
  end

  describe "structured error positions" do
    test "invalid JSON reports code, byte position, line and column" do
      text = "{\n  \"a\": nope\n}"

      assert {:error, error} = Parser.parse_declaration(:json_schema, text)

      assert %{
               document: :declaration,
               code: :invalid_json,
               position: position,
               line: 2,
               column: column
             } = error

      assert is_integer(position)
      assert column >= 8
      assert error.message =~ "unexpected"
    end

    test "invalid JSON on the first line reports line 1" do
      assert {:error, %{line: 1, column: column}} = Parser.parse_data("{\"a\" nope}")

      assert is_integer(column)
    end

    test "wrong top-level shape reports :expected_object with nil position" do
      assert {:error, error} = Parser.parse_data("[]")

      assert %{
               document: :data,
               code: :expected_object,
               position: nil,
               line: nil,
               column: nil
             } = error

      assert error.message =~ "JSON object"
    end
  end
end
