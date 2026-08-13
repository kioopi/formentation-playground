defmodule FrmnPlay.E2E.LandingPageTest do
  @moduledoc """
  Browser test for the landing page.

  Excluded from `mix test`. Run with `mix test.e2e`, which requires the
  Playwright CLI and Chromium from `mise run playwright-browsers`.
  """

  use PhoenixTest.Playwright.Case, async: true

  @moduletag :playwright

  test "the landing page renders the heading, tagline and docs link", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Phoenix Framework")
    |> assert_has("p", text: "Peace of mind from prototype to production.")
    |> assert_has("a", text: "Guides & Docs")
  end
end
