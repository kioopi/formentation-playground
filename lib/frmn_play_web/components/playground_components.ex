defmodule FrmnPlayWeb.PlaygroundComponents do
  @moduledoc "Function components for the playground page."
  use FrmnPlayWeb, :html

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :dirty, :boolean, default: false

  def source_editor(assigns) do
    ~H"""
    <div>
      <label for={@id} class="label gap-2">
        {@label}
        <span
          :if={@dirty}
          class="status status-warning"
          data-dirty="true"
          title="This document has unapplied changes"
        />
      </label>
      <.textarea
        id={@id}
        name={@name}
        rows="10"
        spellcheck="false"
        phx-debounce="300"
        class="w-full font-mono text-sm"
      >{@value}</.textarea>
    </div>
    """
  end

  attr :errors, :list, required: true

  def parse_error_list(assigns) do
    ~H"""
    <div class="space-y-2" id="apply-errors">
      <.alert :for={error <- @errors} color="error" class="items-start text-sm">
        <div>
          <p class="font-semibold">
            {document_label(error.document)}<span :if={error.line}> — line {error.line}, column {error.column}</span>
          </p>
          <p class="font-mono">{error.message}</p>
        </div>
      </.alert>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :diagnostics, :list, required: true

  def diagnostic_list(assigns) do
    ~H"""
    <div class="space-y-2" id={@id}>
      <.alert :for={diagnostic <- @diagnostics} color={severity_color(diagnostic.severity)} class="items-start text-sm">
        <div>
          <p class="font-semibold"><span class="uppercase">{diagnostic.severity}</span> <code>{diagnostic.code}</code></p>
          <p>{diagnostic.message}</p>
          <p :if={diagnostic.origin} class="font-mono text-xs">{origin_label(diagnostic.origin)}</p>
          <p :if={diagnostic.template_path} class="font-mono text-xs">Field: {Enum.join(diagnostic.template_path.segments, ".")}</p>
        </div>
      </.alert>
    </div>
    """
  end

  defp document_label(:declaration), do: "Schema"
  defp document_label(:presentation), do: "Presentation"
  defp document_label(:data), do: "Initial instance"

  defp severity_color(:error), do: "error"
  defp severity_color(:warning), do: "warning"

  defp origin_label({:json_schema, pointer}), do: "Schema: #{pointer}"
  defp origin_label({:ui_hints, pointer}), do: "Presentation: #{pointer}"
  defp origin_label({:inference, rule}), do: "Inferred: #{rule}"
  defp origin_label({:map_source, path}), do: "Source: #{inspect(path)}"
end
