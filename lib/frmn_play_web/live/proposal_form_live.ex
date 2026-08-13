defmodule FrmnPlayWeb.ProposalFormLive do
  @moduledoc """
  A playground page for [Formentation](https://github.com/kioopi/formentation).

  The form is declared once with the `:map` source, compiled on mount, and
  driven through `Formentation.Form.validate/2` (`phx-change`) and
  `Formentation.Form.submit/2` (`phx-submit`). The decoded JSON instance is
  shown once a submission is accepted.
  """
  use FrmnPlayWeb, :live_view

  alias Formentation.Form

  @declaration %{
    kind: :object,
    title: "Talk proposal",
    required: ["title", "email", "track"],
    properties: [
      {"title",
       %{
         kind: :string,
         title: "Talk title",
         min_length: 5,
         max_length: 80,
         help: "The headline attendees see in the schedule."
       }},
      {"track",
       %{kind: :string, title: "Track", one_of: ["Elixir", "Phoenix", "OTP", "Tooling"]}},
      {"level",
       %{
         kind: :string,
         title: "Audience level",
         one_of: ["beginner", "intermediate", "advanced"],
         widget: :radio
       }},
      {"duration_minutes",
       %{kind: :integer, title: "Duration (minutes)", min: 5, max: 90, default: 30}},
      {"abstract",
       %{
         kind: :string,
         title: "Abstract",
         widget: :textarea,
         help: "A few sentences on what the talk covers."
       }},
      {"email", %{kind: :string, title: "Speaker email", role: :email, min_length: 3}},
      {"preferred_date", %{kind: :string, title: "Preferred date", role: :date}},
      {"first_time", %{kind: :boolean, title: "This is my first conference talk"}},
      {"contact",
       %{
         kind: :object,
         title: "Contact address",
         required: ["city"],
         properties: [
           {"street", %{kind: :string, title: "Street"}},
           {"city", %{kind: :string, title: "City", min_length: 1}}
         ]
       }}
    ],
    groups: [
      %{
        id: "talk",
        title: "The talk",
        fields: ["title", "track", "level", "duration_minutes", "abstract"]
      },
      %{
        id: "speaker",
        title: "Speaker",
        fields: ["email", "preferred_date", "first_time"]
      }
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, form_state, diagnostics} =
      Formentation.form(@declaration,
        adapter: :map,
        data: %{"track" => "Elixir"},
        defaults: :apply
      )

    {:ok,
     socket
     |> assign(diagnostics: diagnostics, submitted: nil)
     |> assign_form(form_state)}
  end

  @impl true
  def handle_event("validate", %{"proposal" => params}, socket) do
    {:noreply, assign_form(socket, Form.validate(socket.assigns.form_state, params))}
  end

  def handle_event("save", %{"proposal" => params}, socket) do
    case Form.submit(socket.assigns.form_state, params) do
      {:ok, instance, submitted_form} ->
        {:noreply,
         socket
         |> assign(:submitted, instance)
         |> assign_form(submitted_form)}

      {:error, submitted_form} ->
        {:noreply,
         socket
         |> assign(:submitted, nil)
         |> assign_form(submitted_form)}
    end
  end

  defp assign_form(socket, form_state) do
    assign(socket,
      form_state: form_state,
      proposal_form: to_form(form_state, as: "proposal")
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 class="text-2xl font-bold">Formentation playground</h1>
          <p class="text-base-content/70">
            Declared with the map source, rendered by <code class="text-sm">Formentation.Phoenix.fields/1</code>.
          </p>
        </div>

        <div :if={@diagnostics != []} role="alert" class="alert alert-warning">
          <span>{length(@diagnostics)} compile diagnostic(s): {inspect(@diagnostics)}</span>
        </div>

        <.form
          for={@proposal_form}
          id="proposal-form"
          phx-change="validate"
          phx-submit="save"
          novalidate
          class="card bg-base-100 shadow"
        >
          <div class="card-body gap-4">
            <Formentation.Phoenix.fields form={@proposal_form} />
            <div class="card-actions justify-end">
              <button type="submit" class="btn btn-primary">Submit proposal</button>
            </div>
          </div>
        </.form>

        <div :if={@submitted} class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Decoded instance</h2>
            <pre class="overflow-x-auto text-sm"><code>{format_json(@submitted)}</code></pre>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_json(instance), do: Jason.encode!(instance, pretty: true)
end
