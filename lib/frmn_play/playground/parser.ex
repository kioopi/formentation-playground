defmodule FrmnPlay.Playground.Parser do
  @moduledoc """
  Parses playground source texts into documents.

  Milestone 1 supports the `:json_schema` source (all three documents are
  JSON). Milestone 3 adds a restricted Elixir literal parser for the
  `:map` source behind the same boundary.

  Instance data is always JSON, in every source mode, so `parse_data/1`
  takes no source argument.
  """

  @type error :: %{document: :declaration | :presentation | :data, message: String.t()}

  @spec parse_declaration(:json_schema, String.t()) :: {:ok, map()} | {:error, error()}
  def parse_declaration(:json_schema, text), do: decode(:declaration, text)

  @spec parse_presentation(:json_schema, String.t()) :: {:ok, map()} | {:error, error()}
  def parse_presentation(:json_schema, text), do: decode(:presentation, text)

  @spec parse_data(String.t()) :: {:ok, map()} | {:error, error()}
  def parse_data(text), do: decode(:data, text)

  defp decode(document, text) do
    case Jason.decode(text) do
      {:ok, value} -> {:ok, value}
      {:error, error} -> {:error, %{document: document, message: Exception.message(error)}}
    end
  end
end
