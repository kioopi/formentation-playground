defmodule FrmnPlay.E2E.PlaygroundTest do
  @moduledoc """
  Browser test for the Formentation playground form.

  Excluded from `mix test`. Run with `mix test.e2e`, which requires the
  Playwright CLI and Chromium from `mise run playwright-browsers`.
  """

  use PhoenixTest.Playwright.Case, async: true

  @moduletag :playwright

  test "filling the form and submitting shows the decoded instance", %{conn: conn} do
    conn
    |> visit("/playground")
    |> assert_has("h1", text: "Formentation playground")
    |> fill_in("Talk title", with: "Formentation in anger")
    |> select("Track", option: "Elixir")
    |> choose("intermediate")
    |> fill_in("Duration (minutes)", with: "45")
    |> fill_in("Speaker email", with: "ada@example.com")
    |> fill_in("City", with: "Berlin")
    |> click_button("Submit")
    |> assert_has("h2", text: "Decoded instance")
    |> assert_has("pre", text: "duration_minutes")
  end

  test "submitting undecodable input shows the error summary and keeps the raw text", %{
    conn: conn
  } do
    conn
    |> visit("/playground")
    |> fill_in("Duration (minutes)", with: "45x")
    |> click_button("Submit")
    |> assert_has(".ftn-error-summary")
    |> assert_has("input[name='preview[duration_minutes]'][value='45x']")
    |> refute_has("h2", text: "Decoded instance")
  end

  test "successful Apply authoritatively resets modified preview controls", %{conn: conn} do
    conn
    |> visit("/playground")
    |> fill_in("Duration (minutes)", with: "60")
    |> click_button("Apply sources")
    |> assert_has("input[name='preview[duration_minutes]'][value='30']")
  end

  test "switching examples replaces dirty editor and preview browser state", %{conn: conn} do
    conn
    |> visit("/playground")
    |> fill_in("Initial instance", with: ~s({"track": "OTP"}))
    |> fill_in("Talk title", with: "Dirty preview text")
    |> select("Example", option: "Basic fields")
    |> assert_has("h2", text: "Preview")
    |> assert_has("input[name='preview[name]']")
    |> refute_has("input[name='preview[title]'][value='Dirty preview text']")
    |> refute_has("textarea[name='data']", text: "OTP")
  end

  test "Reset restores editor and preview browser state", %{conn: conn} do
    conn
    |> visit("/playground")
    |> fill_in("Schema", with: "{ not json")
    |> fill_in("Duration (minutes)", with: "60")
    |> click_button("Reset example")
    |> assert_has("textarea[name='declaration']", text: "Talk proposal")
    |> assert_has("input[name='preview[duration_minutes]'][value='30']")
  end

  test "full authoring workflow: edit sources, apply, fill, submit, decode", %{conn: conn} do
    new_declaration = ~s"""
    {
      "type": "object",
      "title": "Signup",
      "required": ["full_name"],
      "properties": {
        "full_name": {"type": "string", "title": "Full name", "minLength": 1},
        "age": {"type": "integer", "title": "Age"}
      }
    }
    """

    conn
    |> visit("/playground")
    |> fill_in("Schema", with: new_declaration)
    |> fill_in("Presentation", with: "{}")
    |> fill_in("Initial instance", with: "{}")
    |> click_button("Apply sources")
    |> assert_has("input[name='preview[full_name]']")
    |> refute_has("input[name='preview[title]']")
    |> fill_in("Full name", with: "Ada Lovelace")
    |> fill_in("Age", with: "36")
    |> click_button("Submit")
    |> assert_has("h2", text: "Decoded instance")
    |> evaluate("document.querySelector('pre').textContent", fn text ->
      assert text =~ ~s("age": 36)
    end)
    |> assert_has("pre", text: "Ada Lovelace")
  end

  @map_e2e_declaration """
  %{
    kind: :object,
    title: "Edited map form",
    required: ["name"],
    properties: [
      {"name", %{kind: :string, title: "Headline"}},
      {"level", %{kind: :string, title: "Level", one_of: ["low", "high"], widget: :radio}}
    ]
  }
  """

  test "map mode: select, edit, apply, interact, submit, and switch back", %{conn: conn} do
    conn
    |> visit("/playground")
    |> select("Example", option: "Talk proposal (Map)")
    |> assert_has("#presentation-inline", text: "Defined inline")
    |> fill_in("Declaration", with: @map_e2e_declaration)
    |> fill_in("Initial instance", with: "{}")
    |> click_button("Apply sources")
    |> assert_has("label", text: "Headline")
    |> fill_in("Headline", with: "From the map source")
    |> choose("high")
    |> click_button("Submit")
    |> assert_has("h2", text: "Decoded instance")
    |> assert_has("pre", text: "From the map source")
    |> select("Example", option: "Talk proposal")
    |> assert_has("textarea[name=presentation]", text: "groups")
    |> refute_has("#presentation-inline")
  end
end
