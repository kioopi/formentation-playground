defmodule FrmnPlayWeb.PlaygroundLive do
  @moduledoc """
  The interactive playground page for
  [Formentation](https://github.com/kioopi/formentation).

  The page owns no playground state of its own: it mounts a
  `FrmnPlay.Playground` Session and translates LiveView events into
  Playground actions. The `%Phoenix.HTML.Form{}` projection of the
  session's preview form is built here, in the web layer.
  """
  use FrmnPlayWeb, :live_view

  alias FrmnPlay.Playground

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_session(socket, Playground.start_session())}
  end

  @impl true
  def handle_event("validate-preview", %{"proposal" => params}, socket) do
    {:noreply,
     assign_session(socket, Playground.validate_preview(socket.assigns.session, params))}
  end

  def handle_event("submit-preview", %{"proposal" => params}, socket) do
    {:noreply, assign_session(socket, Playground.submit_preview(socket.assigns.session, params))}
  end

  defp assign_session(socket, session) do
    socket
    |> assign(:session, session)
    |> assign(:preview_form, to_form(session.form, as: "proposal"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 class="text-2xl font-bold">Formentation playground</h1>
          <p class="text-base-content/70">
            Declared with the JSON Schema source, rendered by <code class="text-sm">Formentation.Phoenix.fields/1</code>.
          </p>
        </div>

        <div :if={@session.diagnostics != []} role="alert" class="alert alert-warning">
          <span>
            {length(@session.diagnostics)} compile diagnostic(s): {inspect(@session.diagnostics)}
          </span>
        </div>

        <.form
          for={@preview_form}
          id="proposal-form"
          phx-change="validate-preview"
          phx-submit="submit-preview"
          novalidate
          class="card bg-base-100 shadow"
        >
          <div class="card-body gap-4">
            <Formentation.Phoenix.fields form={@preview_form} />
            <div class="card-actions justify-end">
              <button type="submit" class="btn btn-primary">Submit proposal</button>
            </div>
          </div>
        </.form>

        <div :if={@session.submitted} class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Decoded instance</h2>
            <pre class="overflow-x-auto text-sm"><code>{format_json(@session.submitted)}</code></pre>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_json(instance), do: Jason.encode!(instance, pretty: true)
end
