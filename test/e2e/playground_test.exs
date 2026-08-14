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
end
