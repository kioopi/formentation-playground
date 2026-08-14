defmodule FrmnPlayWeb.PlaygroundLiveTest do
  use FrmnPlayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FrmnPlay.Playground

  test "renders the declared widgets", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/playground")

    assert html =~ "Formentation playground"
    # the declaration compiles without diagnostics, so no warning banner
    refute html =~ "accepted-diagnostics"
    # string field, select from enum, radio widget, nested object
    assert html =~ ~s(name="preview[title]")
    assert html =~ ~s(<option value="Tooling">)
    assert html =~ ~s(name="preview[level]" value="advanced")
    assert html =~ ~s(name="preview[contact][city]")
    # default applied at initialization
    assert html =~ ~s(name="preview[duration_minutes]" value="30")
  end

  test "the initial state comes from the Playground domain", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/playground")

    # every field declared in the default example's declaration document is
    # rendered — the page has no declaration of its own
    example = FrmnPlay.Playground.default_example()
    declaration = Jason.decode!(example.declaration_text)

    for {name, _schema} <- declaration["properties"] do
      assert html =~ ~s(preview[#{name}])
    end
  end

  test "changing the form validates the preview without submitting", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/playground")

    html =
      live
      |> form("#preview-1", preview: %{"duration_minutes" => "abc"})
      |> render_change()

    assert html =~ ~s(value="abc")
    refute html =~ "Decoded instance"
  end

  test "a failed submit shows the error summary and keeps raw input", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/playground")

    html =
      live
      |> form("#preview-1", preview: %{"title" => "Hi", "duration_minutes" => "abc"})
      |> render_submit()

    assert html =~ "ftn-error-summary"
    assert html =~ ~s(value="abc")
    refute html =~ "Decoded instance"
  end

  test "a valid submit decodes the instance to its declared types", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/playground")

    html =
      live
      |> form("#preview-1",
        preview: %{
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
      )
      |> render_submit()

    assert html =~ "Decoded instance"
    # integers decode as integers, booleans as booleans (quotes are HTML-escaped)
    assert html =~ "&quot;duration_minutes&quot;: 45"
    assert html =~ "&quot;first_time&quot;: true"
    assert html =~ "&quot;city&quot;: &quot;Berlin&quot;"
  end

  test "the preview form id carries the dom revision", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/playground")

    assert html =~ ~s(id="preview-1")
  end

  describe "sources panel" do
    test "renders the three editors with the example's source texts", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/playground")
      example = Playground.default_example()

      assert html =~ ~s(id="declaration-editor-1")
      assert html =~ ~s(id="presentation-editor-1")
      assert html =~ ~s(id="data-editor-1")
      assert html =~ "Talk proposal"

      assert html =~
               String.trim(Phoenix.HTML.html_escape(example.data_text) |> Phoenix.HTML.safe_to_string())
    end

    test "editing a source marks it dirty without touching the preview", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html =
        live
        |> form("#sources-form", %{"declaration" => "{ not json"})
        |> render_change()

      assert html =~ ~s(data-dirty="true")
      assert html =~ ~s(id="preview-1")
      assert html =~ ~s(name="preview[title]")
    end

    test "a failed apply keeps the preview and the revision", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html =
        live
        |> form("#sources-form", %{"declaration" => "{ not json"})
        |> render_submit()

      assert html =~ ~s(id="preview-1")
      assert html =~ ~s(name="preview[title]")
    end

    test "a successful apply bumps the revision and rebuilds the preview", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")
      example = Playground.default_example()

      new_declaration =
        example.declaration_text
        |> Jason.decode!()
        |> put_in(["properties", "title", "title"], "Renamed title")
        |> Jason.encode!()

      html =
        live
        |> form("#sources-form", %{"declaration" => new_declaration})
        |> render_submit()

      assert html =~ "Renamed title"
      assert html =~ ~s(id="preview-2")
      refute html =~ ~s(id="preview-1")
    end
  end

  describe "diagnostics placement" do
    test "a parse failure renders on the sources side and keeps the preview", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html = live |> form("#sources-form", %{"declaration" => "{ not json"}) |> render_submit()

      assert html =~ "Could not apply sources"
      assert html =~ ~s(id="apply-errors")
      assert html =~ "Schema"
      assert html =~ "line 1"
      assert html =~ ~s(name="preview[title]")
      refute html =~ ~s(id="accepted-diagnostics")
    end

    test "a fatal compile failure renders apply diagnostics on the sources side", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html = live |> form("#sources-form", %{"declaration" => ~s({"type": "string"})}) |> render_submit()

      assert html =~ "Could not apply sources"
      assert html =~ ~s(id="apply-diagnostics")
      assert html =~ "unsupported_type"
      assert html =~ ~s(name="preview[title]")
    end

    test "accepted warnings render on the preview side", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")
      unsupported = FrmnPlay.Playground.Examples.get!("unsupported-array")

      html =
        live
        |> form("#sources-form", %{"declaration" => unsupported.declaration_text, "presentation" => unsupported.presentation_text, "data" => unsupported.data_text})
        |> render_submit()

      refute html =~ "Could not apply sources"
      assert html =~ ~s(id="accepted-diagnostics")
      assert html =~ "unsupported_type"
      assert html =~ "Schema: /properties/tags/type"
    end
  end
end
