playwright_included? =
  ExUnit.configuration()
  |> Keyword.get(:include, [])
  |> Enum.any?(&(&1 == :playwright or match?({:playwright, _}, &1)))

ExUnit.start(exclude: [:playwright])

if playwright_included? do
  # phoenix_test_playwright looks for <assets_dir>/node_modules/playwright/cli.js.
  # Playwright is pinned globally by mise (see mise.toml), whose install prefix
  # has that exact layout under lib/, so point assets_dir there rather than
  # installing a second copy into assets/.
  #
  # `System.cmd/3` raises `ErlangError` (:enoent) when the executable itself
  # can't be found — it does not return a non-zero exit status for that case.
  # So we have to check for the executable ourselves before shelling out, or
  # a machine without mise on PATH would crash here with an opaque stack
  # trace instead of falling back to "./assets".
  assets_dir =
    if System.find_executable("mise") do
      case System.cmd("mise", ["where", "npm:playwright"], stderr_to_stdout: true) do
        {prefix, 0} -> prefix |> String.trim() |> Path.join("lib")
        _ -> "./assets"
      end
    else
      "./assets"
    end

  playwright_cli = Path.join([assets_dir, "node_modules", "playwright", "cli.js"])

  unless File.exists?(playwright_cli) do
    Mix.raise("""
    Could not find the Playwright CLI at #{playwright_cli}.

    The browser test suite (tagged :playwright) needs a mise-managed
    Playwright + Chromium install. Run:

        mise install
        mise run playwright-browsers

    then re-run `mix test.e2e` (or `mix ci`).
    """)
  end

  playwright_config =
    :phoenix_test
    |> Application.get_env(:playwright, [])
    |> Keyword.put(:assets_dir, assets_dir)

  Application.put_env(:phoenix_test, :playwright, playwright_config)

  {:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
  Application.put_env(:phoenix_test, :base_url, FrmnPlayWeb.Endpoint.url())
end
