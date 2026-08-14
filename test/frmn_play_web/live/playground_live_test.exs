defmodule FrmnPlayWeb.PlaygroundLiveTest do
  use FrmnPlayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FrmnPlay.Playground

  test "renders the declared widgets", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/playground")

    assert html =~ "Formentation playground"
    # the declaration compiles without diagnostics, so no warning banner
    refute html =~ "compile diagnostic"
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

  test "renders a warning banner when the session has compile diagnostics" do
    session = %{Playground.start_session() | diagnostics: [%{code: :test, message: "boom"}]}

    assigns = %{
      flash: %{},
      session: session,
      preview_form: Phoenix.Component.to_form(session.form, as: "preview")
    }

    html =
      assigns
      |> FrmnPlayWeb.PlaygroundLive.render()
      |> rendered_to_string()

    assert html =~ "1 compile diagnostic(s)"
  end

  test "the preview form id carries the dom revision", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/playground")

    assert html =~ ~s(id="preview-1")
  end
end
