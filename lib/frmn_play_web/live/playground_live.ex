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
  alias FrmnPlay.Playground.Session

  import FrmnPlayWeb.PlaygroundComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:dom_revision, 1)
     |> assign_session(Playground.start_session())}
  end

  @impl true
  def handle_event("validate-preview", %{"preview" => params}, socket) do
    {:noreply,
     assign_session(socket, Playground.validate_preview(socket.assigns.session, params))}
  end

  def handle_event("submit-preview", %{"preview" => params}, socket) do
    {:noreply, assign_session(socket, Playground.submit_preview(socket.assigns.session, params))}
  end

  def handle_event("edit-sources", params, socket) do
    {:noreply, assign_session(socket, edit_sources(socket.assigns.session, params))}
  end

  def handle_event("apply-sources", params, socket) do
    session =
      socket.assigns.session
      |> edit_sources(params)
      |> Playground.apply_sources()

    socket =
      if Session.has_apply_errors?(session) or Session.has_apply_diagnostics?(session) do
        socket
      else
        bump_dom_revision(socket)
      end

    {:noreply, assign_session(socket, session)}
  end

  def handle_event("select-example", %{"example" => example_id}, socket) do
    {:noreply,
     socket
     |> bump_dom_revision()
     |> assign_session(Playground.load_example(socket.assigns.session, example_id))}
  end

  def handle_event("reset-session", _params, socket) do
    {:noreply,
     socket
     |> bump_dom_revision()
     |> assign_session(Playground.reset_session(socket.assigns.session))}
  end

  defp assign_session(socket, session) do
    socket
    |> assign(:session, session)
    |> assign(
      :preview_form,
      to_form(session.form, as: "preview", id: "preview-#{socket.assigns.dom_revision}")
    )
  end

  defp edit_sources(session, params) do
    session
    |> Playground.edit_declaration(Map.get(params, "declaration", session.declaration_text))
    |> Playground.edit_presentation(Map.get(params, "presentation", session.presentation_text))
    |> Playground.edit_data(Map.get(params, "data", session.data_text))
  end

  defp bump_dom_revision(socket), do: update(socket, :dom_revision, &(&1 + 1))

  def format_json(instance), do: Jason.encode!(instance, pretty: true)
end
