defmodule FrmnPlayWeb.CoreComponents do
  @moduledoc """
  Translates error messages through this application's Gettext backend.

  Despite the name, this module holds no components. All UI comes from
  `DaisyUIComponents` (imported wholesale in `FrmnPlayWeb.html_helpers/0`)
  and form fields come from `Formentation`; see CLAUDE.md. The generated
  Phoenix components that used to live here were deleted once every one of
  them had a `DaisyUIComponents` equivalent.

  `translate_error/1` is also wired up as `DaisyUIComponents`' configured
  `:translate_function` in `config/config.exs`, so strings baked into that
  library's components pass through this backend too.
  """

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(FrmnPlayWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FrmnPlayWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
