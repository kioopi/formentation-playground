defmodule FrmnPlay.Playground.Parser.MapLiteral do
  @moduledoc """
  Restricted decoder for Map-declaration source text.

  It accepts a deliberately small AST whitelist and reconstructs plain
  terms recursively. Submitted text is never evaluated.
  """

  @max_depth 64
  @max_nodes 10_000
  @charlist_message "charlists are not part of the Map declaration format — use a double-quoted string"

  @key_atoms ~w(kind properties required title help groups id fields role widget one_of default examples hidden read_only min_length max_length min max)a
  @kind_atoms ~w(object string integer number boolean array)a
  @widget_atoms ~w(text textarea select radio checkbox)a
  @role_atoms ~w(date email uri)a
  @allowed_atoms MapSet.new(@key_atoms ++ @kind_atoms ++ @widget_atoms ++ @role_atoms)
  @allowed_atoms_listing @allowed_atoms |> Enum.sort() |> Enum.map_join(", ", &inspect/1)

  @type error :: %{
          code:
            :invalid_elixir
            | :forbidden_syntax
            | :atom_not_allowed
            | :ast_too_deep
            | :ast_too_large,
          message: String.t(),
          line: pos_integer() | nil,
          column: pos_integer() | nil
        }

  @spec decode(String.t()) :: {:ok, term()} | {:error, error()}
  def decode(text) when is_binary(text) do
    case Code.string_to_quoted(text,
           existing_atoms_only: true,
           columns: true,
           token_metadata: true,
           emit_warnings: false,
           literal_encoder: &charlist_gate/2
         ) do
      {:ok, ast} ->
        with {:ok, term, _nodes} <- build(ast, 1, 0), do: {:ok, term}

      {:error, {meta, message_info, token}} ->
        {:error, syntax_error(meta, message_info, token)}
    end
  end

  # Heredoc charlists carry delimiter "'''", single-line ones "'".
  defp charlist_gate(literal, meta) do
    if meta[:delimiter] in ["'", "'''"], do: {:error, @charlist_message}, else: {:ok, literal}
  end

  defp build(_ast, depth, _nodes) when depth > @max_depth,
    do: {:error, limit_error(:ast_too_deep, "nesting exceeds the maximum depth of #{@max_depth}")}

  defp build(term, _depth, nodes)
       when is_integer(term) or is_float(term) or is_binary(term) or is_boolean(term) or
              is_nil(term),
       do: count(term, nodes)

  defp build(atom, _depth, nodes) when is_atom(atom) do
    if MapSet.member?(@allowed_atoms, atom) do
      count(atom, nodes)
    else
      {:error,
       %{
         code: :atom_not_allowed,
         message:
           "atom #{inspect(atom)} is not in the playground vocabulary; permitted atoms: #{@allowed_atoms_listing}",
         line: nil,
         column: nil
       }}
    end
  end

  defp build({:-, _meta, [number]}, _depth, nodes) when is_number(number),
    do: count(-number, nodes)

  defp build({:+, _meta, [number]}, _depth, nodes) when is_number(number),
    do: count(number, nodes)

  defp build(list, depth, nodes) when is_list(list) do
    with {:ok, terms, nodes} <- build_all(list, depth + 1, nodes), do: count(terms, nodes)
  end

  defp build({a, b}, depth, nodes) do
    with {:ok, a, nodes} <- build(a, depth + 1, nodes),
         {:ok, b, nodes} <- build(b, depth + 1, nodes),
         do: count({a, b}, nodes)
  end

  defp build({:%{}, meta, [{:|, _, _} | _]}, _depth, _nodes),
    do: forbidden(meta, "map update syntax is not allowed")

  defp build({:%{}, _meta, pairs}, depth, nodes) do
    with {:ok, pair_terms, nodes} <- build_all(pairs, depth + 1, nodes),
         do: count(Map.new(pair_terms), nodes)
  end

  defp build({:{}, meta, elements}, _depth, _nodes),
    do:
      forbidden(
        meta,
        "only two-element tuples are allowed, got a #{length(elements)}-element tuple"
      )

  defp build({:__block__, meta, _}, _depth, _nodes),
    do: forbidden(meta, "the declaration must be a single expression")

  defp build({:__aliases__, meta, _}, _depth, _nodes),
    do: forbidden(meta, "aliases and module names are not allowed")

  defp build({:%, meta, _}, _depth, _nodes), do: forbidden(meta, "struct syntax is not allowed")

  defp build({:<<>>, meta, _}, _depth, _nodes),
    do: forbidden(meta, "string interpolation and binary syntax are not allowed")

  defp build({name, meta, context}, _depth, _nodes) when is_atom(name) and is_atom(context),
    do: forbidden(meta, "variables are not allowed: #{name}")

  defp build({name, meta, args}, _depth, _nodes) when is_atom(name) and is_list(args) do
    if String.starts_with?(Atom.to_string(name), "sigil_"),
      do: forbidden(meta, "sigils are not allowed"),
      else: forbidden(meta, "calls and operators are not allowed: #{name}")
  end

  defp build({{:., _, _}, meta, _args}, _depth, _nodes),
    do: forbidden(meta, "remote calls are not allowed")

  defp build(other, _depth, _nodes),
    do: forbidden([], "unsupported syntax: #{inspect(other, limit: 3)}")

  defp build_all(items, depth, nodes) do
    items
    |> Enum.reduce_while({:ok, [], nodes}, fn item, {:ok, acc, nodes} ->
      case build(item, depth, nodes) do
        {:ok, term, nodes} -> {:cont, {:ok, [term | acc], nodes}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, terms, nodes} -> {:ok, Enum.reverse(terms), nodes}
      {:error, _} = error -> error
    end
  end

  defp count(term, nodes) do
    nodes = nodes + 1

    if nodes > @max_nodes,
      do:
        {:error,
         limit_error(:ast_too_large, "the declaration exceeds the maximum of #{@max_nodes} nodes")},
      else: {:ok, term, nodes}
  end

  defp limit_error(code, message), do: %{code: code, message: message, line: nil, column: nil}

  defp forbidden(meta, message),
    do:
      {:error,
       %{code: :forbidden_syntax, message: message, line: meta[:line], column: meta[:column]}}

  defp syntax_error(meta, message_info, token) do
    message = compose_message(message_info, token)

    if String.starts_with?(message, @charlist_message),
      do: %{
        code: :forbidden_syntax,
        message: @charlist_message,
        line: meta[:line],
        column: meta[:column]
      },
      else: %{code: :invalid_elixir, message: message, line: meta[:line], column: meta[:column]}
  end

  defp compose_message({prefix, suffix}, token), do: prefix <> to_string(token) <> suffix
  defp compose_message(prefix, token), do: prefix <> to_string(token)
end
