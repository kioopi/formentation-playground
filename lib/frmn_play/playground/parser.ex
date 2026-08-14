defmodule FrmnPlay.Playground.Parser do
  @moduledoc """
  Parses playground source texts into documents.

  It owns the per-document resource-safety envelope: the 64 KiB byte cap
  runs before any tokenizer or decoder for every source mode.

  Instance data is always JSON, in every source mode, so `parse_data/1`
  takes no source argument.
  """

  @typedoc """
  A parse failure. `position` is Jason's byte offset into the source text;
  `line`/`column` are derived from it by counting newlines. Column is
  therefore a byte column, not a grapheme column, on lines containing
  multi-byte characters.
  """
  @type error :: %{
          document: :declaration | :presentation | :data,
          code: :invalid_json | :expected_object | :input_too_large,
          message: String.t(),
          position: non_neg_integer() | nil,
          line: pos_integer() | nil,
          column: pos_integer() | nil
        }

  @spec parse_declaration(:json_schema, String.t()) :: {:ok, map()} | {:error, error()}
  def parse_declaration(:json_schema, text), do: decode(:declaration, text)

  @spec parse_presentation(:json_schema, String.t()) :: {:ok, map()} | {:error, error()}
  def parse_presentation(:json_schema, text), do: decode(:presentation, text)

  @spec parse_data(String.t()) :: {:ok, map()} | {:error, error()}
  def parse_data(text), do: decode(:data, text)

  @max_source_bytes 65_536

  defp decode(document, text) do
    with :ok <- check_size(document, text) do
      case Jason.decode(text) do
        {:ok, value} when is_map(value) ->
          {:ok, value}

        {:ok, value} ->
          {:error,
           %{
             document: document,
             code: :expected_object,
             message: "must be a JSON object, got: #{inspect(value)}",
             position: nil,
             line: nil,
             column: nil
           }}

        {:error, %Jason.DecodeError{position: position} = error} ->
          {line, column} = line_and_column(text, position)

          {:error,
           %{
             document: document,
             code: :invalid_json,
             message: Exception.message(error),
             position: position,
             line: line,
             column: column
           }}
      end
    end
  end

  defp check_size(document, text) do
    if byte_size(text) > @max_source_bytes do
      {:error,
       %{
         document: document,
         code: :input_too_large,
         message:
           "source is #{byte_size(text)} bytes; the maximum is #{@max_source_bytes} bytes (64 KiB)",
         position: nil,
         line: nil,
         column: nil
       }}
    else
      :ok
    end
  end

  # Byte-offset arithmetic is intentional: `position` may sit inside a
  # multi-byte character, so grapheme-aware String functions are unsafe on
  # the truncated prefix.
  defp line_and_column(text, position) do
    prefix = binary_part(text, 0, min(position, byte_size(text)))
    lines = :binary.split(prefix, "\n", [:global])
    {length(lines), byte_size(List.last(lines)) + 1}
  end
end
