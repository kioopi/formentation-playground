defmodule FrmnPlayWeb.ProposalFormLiveTest do
  use FrmnPlayWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the declared widgets", %{conn: conn} do
    {:ok, _live, html} = live(conn, ~p"/proposal")

    assert html =~ "Formentation playground"
    # the declaration compiles without diagnostics, so no warning banner
    refute html =~ "compile diagnostic"
    # string field, select from :one_of, radio widget, textarea, nested object
    assert html =~ ~s(name="proposal[title]")
    assert html =~ ~s(<option value="Tooling">)
    assert html =~ ~s(name="proposal[level]" value="advanced")
    assert html =~ ~s(name="proposal[contact][city]")
    # :default applied at initialization
    assert html =~ ~s(name="proposal[duration_minutes]" value="30")
  end

  test "a failed submit shows the error summary and keeps raw input", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/proposal")

    html =
      live
      |> form("#proposal-form", proposal: %{"title" => "Hi", "duration_minutes" => "abc"})
      |> render_submit()

    assert html =~ "ftn-error-summary"
    assert html =~ ~s(value="abc")
    refute html =~ "Decoded instance"
  end

  test "a valid submit decodes the instance to its declared types", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/proposal")

    html =
      live
      |> form("#proposal-form",
        proposal: %{
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
end
