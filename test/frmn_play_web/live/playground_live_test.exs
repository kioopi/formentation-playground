defmodule FrmnPlayWeb.PlaygroundLiveTest do
  use FrmnPlayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FrmnPlay.Playground

  # `mix reach.check --arch` enforces the Playground facade for .ex files,
  # but reach only ingests .ex sources — calls inside HEEx templates are
  # invisible to it. This guard covers that blind spot.
  test "templates reach Playground internals only through the facade" do
    for template <- Path.wildcard("lib/frmn_play_web/**/*.heex") do
      source = File.read!(template)

      refute source =~ ~r/\b(Session|Parser|Examples)\./,
             "#{template} must call FrmnPlay.Playground delegates, not its submodules"
    end
  end

  describe "sources textarea round-trip" do
    # A browser parses a rendered <textarea> body by dropping the single
    # leading newline and unescaping HTML entities; phx-change then sends
    # that parsed value back for all three documents. If the template
    # injects any other whitespace around the value, every edit cycle
    # compounds it in every textarea (regression: whitespace accumulation).
    test "a phx-change echo of the rendered content leaves the session clean", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/playground")

      params =
        Map.new(["declaration", "presentation", "data"], fn name ->
          {name, browser_textarea_value(html, name)}
        end)

      html = live |> form("#sources-form", params) |> render_change()

      refute html =~ ~s(data-dirty="true")

      # fixpoint: the re-rendered textareas parse back to the same values
      for {name, value} <- params do
        assert browser_textarea_value(html, name) == value
      end
    end

    defp browser_textarea_value(html, name) do
      [_, body] = Regex.run(~r|<textarea[^>]*name="#{name}"[^>]*>(.*?)</textarea>|s, html)

      body
      |> String.replace_prefix("\n", "")
      |> String.replace("&quot;", "\"")
      |> String.replace("&#39;", "'")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
      |> String.replace("&amp;", "&")
    end
  end

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
               String.trim(
                 Phoenix.HTML.html_escape(example.data_text)
                 |> Phoenix.HTML.safe_to_string()
               )
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

      html =
        live
        |> form("#sources-form", %{"declaration" => ~s({"type": "string"})})
        |> render_submit()

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
        |> form("#sources-form", %{
          "declaration" => unsupported.declaration_text,
          "presentation" => unsupported.presentation_text,
          "data" => unsupported.data_text
        })
        |> render_submit()

      refute html =~ "Could not apply sources"
      assert html =~ ~s(id="accepted-diagnostics")
      assert html =~ "unsupported_type"
      assert html =~ "Schema: /properties/tags/type"
    end
  end

  describe "example selector and reset" do
    test "selecting an example replaces sources and preview and bumps the revision", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html = live |> form("#example-form", %{"example" => "basic-fields"}) |> render_change()

      assert html =~ "Basic fields"
      assert html =~ ~s(name="preview[name]")
      refute html =~ ~s(name="preview[title]")
      assert html =~ ~s(id="preview-2")
      assert html =~ ~s(id="declaration-editor-2")
    end

    test "selecting an example discards dirty edits immediately", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")
      live |> form("#sources-form", %{"declaration" => "{ not json"}) |> render_change()

      html = live |> form("#example-form", %{"example" => "basic-fields"}) |> render_change()

      refute html =~ ~s(data-dirty="true")
      refute html =~ "Could not apply sources"
    end

    test "reset restores the current example's baseline and bumps the revision", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")
      live |> form("#sources-form", %{"declaration" => "{ not json"}) |> render_submit()

      html = live |> element("button", "Reset example") |> render_click()

      refute html =~ "Could not apply sources"
      refute html =~ ~s(data-dirty="true")
      assert html =~ ~s(id="preview-2")
    end
  end

  describe "staleness banner" do
    test "editing a source shows the banner over the whole right-hand side", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      html =
        live
        |> form("#sources-form", %{"declaration" => ~s({"type": "object", "properties": {}})})
        |> render_change()

      assert html =~ ~s(id="stale-banner")
      assert html =~ "Changes not applied"
    end

    test "a successful apply clears the banner", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")

      live
      |> form("#sources-form", %{"declaration" => ~s({"type": "object", "properties": {}})})
      |> render_change()

      html = live |> form("#sources-form") |> render_submit()

      refute html =~ ~s(id="stale-banner")
    end

    test "a pristine session shows no banner", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/playground")
      refute html =~ ~s(id="stale-banner")
    end
  end

  describe "map source mode" do
    test "the selector groups examples by source", %{conn: conn} do
      {:ok, live, html} = live(conn, ~p"/playground")
      assert has_element?(live, "optgroup[label='JSON Schema']")
      assert has_element?(live, "optgroup[label='Elixir Map']")
      assert html =~ "Talk proposal (Map)"
    end

    test "selecting map mode swaps the presentation editor for the inline panel", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/playground")
      html = live |> form("#example-form", %{"example" => "talk-proposal-map"}) |> render_change()

      assert html =~ "Declared with the Elixir Map source"
      assert html =~ "Defined inline"
      assert has_element?(live, "textarea[name=declaration]")
      assert has_element?(live, "textarea[name=data]")
      refute has_element?(live, "textarea[name=presentation]")
      assert has_element?(live, "#presentation-inline")
    end
  end
end
