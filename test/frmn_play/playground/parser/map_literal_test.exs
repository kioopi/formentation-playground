defmodule FrmnPlay.Playground.Parser.MapLiteralTest do
  use ExUnit.Case, async: true

  alias FrmnPlay.Playground.Parser.MapLiteral

  describe "accepted literal shapes" do
    test "scalars" do
      assert {:ok, 5} = MapLiteral.decode("5")
      assert {:ok, 1.5} = MapLiteral.decode("1.5")
      assert {:ok, "hello"} = MapLiteral.decode(~s("hello"))
      assert {:ok, true} = MapLiteral.decode("true")
      assert {:ok, false} = MapLiteral.decode("false")
      assert {:ok, nil} = MapLiteral.decode("nil")
    end

    test "unary numeric literals" do
      assert {:ok, -5} = MapLiteral.decode("-5")
      assert {:ok, 5} = MapLiteral.decode("+5")
      assert {:ok, -1.5} = MapLiteral.decode("-1.5")
    end

    test "heredoc strings" do
      assert {:ok, "line\n"} = MapLiteral.decode(~s("""\nline\n"""))
    end

    test "lists and keyword sugar" do
      assert {:ok, [1, "two", true]} = MapLiteral.decode(~s([1, "two", true]))
      assert {:ok, [kind: :string]} = MapLiteral.decode("[kind: :string]")
    end

    test "two-element tuples" do
      assert {:ok, {1, 2}} = MapLiteral.decode("{1, 2}")
      assert {:ok, {"name", %{kind: :string}}} = MapLiteral.decode(~s({"name", %{kind: :string}}))
    end

    test "maps with allowed atom keys" do
      assert {:ok, %{kind: :object, title: "T"}} =
               MapLiteral.decode(~s(%{kind: :object, title: "T"}))
    end

    test "a realistic Map declaration" do
      text = """
      %{
        kind: :object,
        title: "Demo",
        required: ["name"],
        properties: [
          {"name", %{kind: :string, title: "Name", min_length: 1}},
          {"level", %{kind: :string, one_of: ["low", "high"], widget: :radio}},
          {"when", %{kind: :string, role: :date, default: "2026-01-01"}}
        ],
        groups: [%{id: "main", title: "Main", fields: ["name", "level"]}]
      }
      """

      assert {:ok, decoded} = MapLiteral.decode(text)
      assert %{kind: :object, properties: [{"name", _} | _], groups: [%{id: "main"}]} = decoded

      assert {"level", %{one_of: ["low", "high"], widget: :radio}} =
               Enum.at(decoded.properties, 1)
    end
  end

  describe "rejected syntax" do
    test "tuples with three or more elements" do
      assert {:error, %{code: :forbidden_syntax, message: message, line: 1}} =
               MapLiteral.decode("{1, 2, 3}")

      assert message =~ "two-element tuples"
    end

    test "map update syntax" do
      assert {:error, %{code: :forbidden_syntax, message: message}} =
               MapLiteral.decode("%{base | kind: :object}")

      assert message =~ "map update"
    end

    test "variables" do
      assert {:error, %{code: :forbidden_syntax, message: message, line: 1, column: 1}} =
               MapLiteral.decode("foo")

      assert message =~ "variable"
    end

    test "calls, aliases, operators, and special forms" do
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("foo()")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("self()")

      assert {:error, %{code: :forbidden_syntax, message: message}} =
               MapLiteral.decode(~s|System.cmd("ls", [])|)

      assert message =~ "not allowed"

      assert {:error, %{code: :forbidden_syntax, message: alias_message}} =
               MapLiteral.decode("String")

      assert alias_message =~ "alias"
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("1 + 2")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("-foo")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("&foo/1")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("fn -> 1 end")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("if true, do: 1")
      assert {:error, %{code: :forbidden_syntax}} = MapLiteral.decode("for x <- [1], do: x")
    end

    test "interpolation, sigils, structs, blocks, and charlists" do
      assert {:error, %{code: :forbidden_syntax, message: message}} =
               MapLiteral.decode(~S("a#{1}"))

      assert message =~ "interpolation"

      assert {:error, %{code: :forbidden_syntax, message: sigil_message}} =
               MapLiteral.decode(~s[~c"abc"])

      assert sigil_message =~ "sigil"

      assert {:error, %{code: :forbidden_syntax, message: struct_message}} =
               MapLiteral.decode("%String{}")

      assert struct_message =~ "struct"

      assert {:error, %{code: :forbidden_syntax, message: block_message}} =
               MapLiteral.decode("1\n2")

      assert block_message =~ "single expression"

      assert {:error, %{code: :forbidden_syntax, message: charlist_message, line: 1, column: 1}} =
               MapLiteral.decode("'abc'")

      assert charlist_message =~ "charlist"
      assert {:ok, [97, 98, 99]} = MapLiteral.decode("[97, 98, 99]")
    end
  end

  describe "atom policy" do
    test "existing but unapproved atoms are rejected" do
      assert {:error, %{code: :atom_not_allowed, message: message}} = MapLiteral.decode(":erlang")
      assert message =~ ":erlang"
      assert message =~ ":kind"
      assert message =~ ":widget"
      assert {:error, %{code: :atom_not_allowed}} = MapLiteral.decode("%{kind: :ok}")
    end

    test "unknown atoms fail without being interned" do
      name = "playground_never_interned_#{System.unique_integer([:positive])}"

      assert {:error, %{code: :invalid_elixir, message: message, line: 1}} =
               MapLiteral.decode(":#{name}")

      assert message =~ "does not exist"
      assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
    end
  end

  describe "limits and metadata" do
    test "depth and node limits" do
      deep = String.duplicate("[", 65) <> String.duplicate("]", 65)
      assert {:error, %{code: :ast_too_deep}} = MapLiteral.decode(deep)
      ok = String.duplicate("[", 64) <> String.duplicate("]", 64)
      assert {:ok, _} = MapLiteral.decode(ok)
      big = "[" <> Enum.map_join(1..10_000, ",", &Integer.to_string/1) <> "]"
      assert {:error, %{code: :ast_too_large}} = MapLiteral.decode(big)
    end

    test "syntax and atom errors carry their applicable positions" do
      assert {:error, %{code: :invalid_elixir, line: 1, column: column}} = MapLiteral.decode("%{")
      assert is_integer(column)

      assert {:error, %{code: :atom_not_allowed, line: nil, column: nil}} =
               MapLiteral.decode(":erlang")
    end
  end
end
