defmodule FrmnPlayWeb.PlaygroundComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias FrmnPlayWeb.PlaygroundComponents

  describe "parse_error_list/1" do
    test "renders document label, position, and message" do
      html =
        render_component(&PlaygroundComponents.parse_error_list/1,
          errors: [
            %{
              document: :declaration,
              code: :invalid_json,
              message: "unexpected byte at position 9",
              position: 9,
              line: 2,
              column: 8
            }
          ]
        )

      assert html =~ "Schema"
      assert html =~ "line 2, column 8"
      assert html =~ "unexpected byte at position 9"
    end

    test "renders a shape error without position" do
      html =
        render_component(&PlaygroundComponents.parse_error_list/1,
          errors: [
            %{
              document: :data,
              code: :expected_object,
              message: "must be a JSON object, got: []",
              position: nil,
              line: nil,
              column: nil
            }
          ]
        )

      assert html =~ "Initial instance"
      refute html =~ "line"
      assert html =~ "must be a JSON object"
    end
  end

  describe "diagnostic_list/1" do
    test "renders severity, code, message, origin, and field path" do
      html =
        render_component(&PlaygroundComponents.diagnostic_list/1,
          id: "diagnostics",
          diagnostics: [
            %Formentation.Diagnostic{
              severity: :warning,
              code: :unsupported_type,
              message: ~s(unsupported type "array" for property "tags"),
              origin: {:json_schema, "/properties/tags/type"},
              template_path: Formentation.TemplatePath.new!(["tags"])
            }
          ]
        )

      assert html =~ "warning"
      assert html =~ "unsupported_type"
      assert html =~ "unsupported type"
      assert html =~ "Schema: /properties/tags/type"
      assert html =~ "Field: tags"
    end

    test "renders a diagnostic without origin or path" do
      html =
        render_component(&PlaygroundComponents.diagnostic_list/1,
          id: "diagnostics",
          diagnostics: [
            %Formentation.Diagnostic{
              severity: :error,
              code: :max_depth_exceeded,
              message: "too deep"
            }
          ]
        )

      assert html =~ "error"
      assert html =~ "too deep"
      refute html =~ "Field:"
    end
  end
end
