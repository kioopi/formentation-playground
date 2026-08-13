defmodule FrmnPlay.Playground do
  @moduledoc """
  Public API of the playground core.

  The web layer calls only this module; `FrmnPlay.Playground.*` submodules
  are implementation detail.
  """

  alias FrmnPlay.Playground.{Example, Examples}

  @spec default_example() :: Example.t()
  defdelegate default_example, to: Examples, as: :default
end
