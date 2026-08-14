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

    test "declarations are formatted for editing in the textarea" do
      for example <- Examples.all(), example.source == :map do
        formatted =
          example.declaration_text
          |> Code.format_string!(line_length: Examples.map_line_length())
          |> IO.iodata_to_binary()
          |> Kernel.<>("\n")

        assert formatted == example.declaration_text,
               "#{example.id} declaration is not formatted; expected:\n#{formatted}"
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

  describe "the talk-proposal pair" do
    # `talk-proposal` and `talk-proposal-map` are the milestone's
    # source-equivalence fixture: the same visible form declared twice, once
    # in JSON Schema plus a presentation document and once in an Elixir Map
    # with groups, roles and widgets inline. They are two large independent
    # literals, so without this test they drift silently.
    #
    # The comparison is deliberately of the observable form only. Whole
    # Definitions must NOT be compared: provenance differs by design (origins
    # name JSON pointers on one side), and only the JSON Schema source carries
    # an authoritative validation plan.
    test "presents the same form from both sources" do
      assert presentation_shape("talk-proposal") == presentation_shape("talk-proposal-map"),
             "the two talk-proposal examples no longer render the same form"
    end

    defp presentation_shape(example_id) do
      definition =
        FrmnPlay.Playground.start_session()
        |> FrmnPlay.Playground.load_example(example_id)
        |> Map.fetch!(:form)
        |> Map.fetch!(:definition)

      definition |> Formentation.Info.presentation_root() |> descriptor_shape(definition)
    end

    defp descriptor_shape(%Formentation.Info.Layout.Object{} = object, definition) do
      {:object, object.id, object.label, object.help, path(object.semantic_path),
       Enum.map(object.children, &descriptor_shape(&1, definition))}
    end

    defp descriptor_shape(%Formentation.Info.Layout.Group{} = group, definition) do
      {:group, group.id, group.label, group.help,
       Enum.map(group.children, &descriptor_shape(&1, definition))}
    end

    defp descriptor_shape(%Formentation.Info.Layout.Field{} = field, definition) do
      segments = path(field.semantic_path)
      semantic = Formentation.Info.node_at(definition, segments)

      {:field, segments, field.label, field.help, field.widget, field.hidden?,
       semantic.value_type, semantic.role, semantic.required?, semantic.read_only?,
       semantic.options, semantic.default, semantic.constraints}
    end

    defp path(%Formentation.InstancePath{segments: segments}), do: segments
  end
end
