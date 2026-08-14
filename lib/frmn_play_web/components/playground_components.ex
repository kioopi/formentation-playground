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
end
