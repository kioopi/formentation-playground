defmodule FrmnPlay.Playground.Examples do
  @moduledoc """
  Registry of built-in playground examples.

  Examples are static data; no persistence is involved.
  """

  alias FrmnPlay.Playground.Example

  @talk_proposal_declaration """
  {
    "type": "object",
    "title": "Talk proposal",
    "required": ["title", "email", "track"],
    "properties": {
      "title": {
        "type": "string",
        "title": "Talk title",
        "minLength": 5,
        "maxLength": 80,
        "description": "The headline attendees see in the schedule."
      },
      "track": {
        "type": "string",
        "title": "Track",
        "enum": ["Elixir", "Phoenix", "OTP", "Tooling"]
      },
      "level": {
        "type": "string",
        "title": "Audience level",
        "enum": ["beginner", "intermediate", "advanced"]
      },
      "duration_minutes": {
        "type": "integer",
        "title": "Duration (minutes)",
        "minimum": 5,
        "maximum": 90,
        "default": 30
      },
      "abstract": {
        "type": "string",
        "title": "Abstract",
        "description": "A few sentences on what the talk covers."
      },
      "email": {
        "type": "string",
        "title": "Speaker email",
        "format": "email",
        "minLength": 3
      },
      "preferred_date": {
        "type": "string",
        "title": "Preferred date",
        "format": "date"
      },
      "first_time": {
        "type": "boolean",
        "title": "This is my first conference talk"
      },
      "contact": {
        "type": "object",
        "title": "Contact address",
        "required": ["city"],
        "properties": {
          "street": {"type": "string", "title": "Street"},
          "city": {"type": "string", "title": "City", "minLength": 1}
        }
      }
    }
  }
  """

  @talk_proposal_presentation """
  {
    "groups": [
      {
        "id": "talk",
        "title": "The talk",
        "fields": ["title", "track", "level", "duration_minutes", "abstract"]
      },
      {
        "id": "speaker",
        "title": "Speaker",
        "fields": ["email", "preferred_date", "first_time"]
      }
    ],
    "order": ["talk", "speaker", "contact"],
    "fields": {
      "level": {"widget": "radio"},
      "abstract": {"widget": "textarea"}
    }
  }
  """

  @talk_proposal_data """
  {"track": "Elixir"}
  """

  @basic_fields_declaration """
  {
    "type": "object",
    "title": "Basic fields",
    "required": ["name"],
    "properties": {
      "name": {"type": "string", "title": "Name", "minLength": 1},
      "age": {"type": "integer", "title": "Age"},
      "rating": {"type": "number", "title": "Rating"},
      "active": {"type": "boolean", "title": "Active"},
      "category": {
        "type": "string",
        "title": "Category",
        "enum": ["standard", "premium", "internal"]
      },
      "start_date": {"type": "string", "title": "Start date", "format": "date"}
    }
  }
  """

  @basic_fields_presentation """
  {}
  """

  @basic_fields_data """
  {}
  """

  @unsupported_array_declaration """
  {
    "type": "object",
    "title": "Unsupported feature",
    "properties": {
      "title": {"type": "string", "title": "Title"},
      "tags": {
        "type": "array",
        "title": "Tags",
        "items": {"type": "string"}
      }
    }
  }
  """

  @unsupported_array_presentation """
  {}
  """

  @unsupported_array_data """
  {
    "title": "Existing record",
    "tags": ["elixir", "phoenix"]
  }
  """

  @talk_proposal_map_declaration """
  %{
    kind: :object, title: "Talk proposal", required: ["title", "email", "track"],
    properties: [
      {"title", %{kind: :string, title: "Talk title", min_length: 5, max_length: 80, help: "The headline attendees see in the schedule."}},
      {"track", %{kind: :string, title: "Track", one_of: ["Elixir", "Phoenix", "OTP", "Tooling"]}},
      {"level", %{kind: :string, title: "Audience level", one_of: ["beginner", "intermediate", "advanced"], widget: :radio}},
      {"duration_minutes", %{kind: :integer, title: "Duration (minutes)", min: 5, max: 90, default: 30}},
      {"abstract", %{kind: :string, title: "Abstract", widget: :textarea, help: "A few sentences on what the talk covers."}},
      {"email", %{kind: :string, title: "Speaker email", role: :email, min_length: 3}},
      {"preferred_date", %{kind: :string, title: "Preferred date", role: :date}},
      {"first_time", %{kind: :boolean, title: "This is my first conference talk"}},
      {"contact", %{kind: :object, title: "Contact address", required: ["city"], properties: [{"street", %{kind: :string, title: "Street"}}, {"city", %{kind: :string, title: "City", min_length: 1}}]}}
    ],
    groups: [%{id: "talk", title: "The talk", fields: ["title", "track", "level", "duration_minutes", "abstract"]}, %{id: "speaker", title: "Speaker", fields: ["email", "preferred_date", "first_time"]}]
  }
  """

  @pump_inspection_declaration """
  %{
    kind: :object, title: "Pump inspection", required: ["serial_number", "condition", "mounting"],
    properties: [
      {"serial_number", %{kind: :string, title: "Serial number", min_length: 4}},
      {"condition", %{kind: :string, title: "Condition", one_of: ["good", "worn", "defective"]}},
      {"mounting", %{kind: :string, title: "Mounting", one_of: ["floor", "wall"], widget: :radio}},
      {"last_service", %{kind: :string, title: "Last service", role: :date}},
      {"operating_hours", %{kind: :integer, title: "Operating hours", min: 0}},
      {"voltage", %{kind: :number, title: "Voltage (V)"}},
      {"insulation_ok", %{kind: :boolean, title: "Insulation test passed"}},
      {"notes", %{kind: :string, title: "Notes", widget: :textarea, help: "Visible to all technicians."}}
    ], groups: [%{id: "electrical", title: "Electrical", fields: ["voltage", "insulation_ok"]}]
  }
  """

  @unsupported_kind_declaration """
  %{kind: :object, title: "Unsupported kind", properties: [{"title", %{kind: :string, title: "Title"}}, {"tags", %{kind: :array, title: "Tags"}}]}
  """

  @examples [
    %Example{
      id: "talk-proposal",
      title: "Talk proposal",
      description: "A grouped conference-talk form exercising most field kinds.",
      source: :json_schema,
      declaration_text: @talk_proposal_declaration,
      presentation_text: @talk_proposal_presentation,
      data_text: @talk_proposal_data
    },
    %Example{
      id: "basic-fields",
      title: "Basic fields",
      description:
        "What Formentation derives from JSON Schema alone, with no presentation customization.",
      source: :json_schema,
      declaration_text: @basic_fields_declaration,
      presentation_text: @basic_fields_presentation,
      data_text: @basic_fields_data
    },
    %Example{
      id: "unsupported-array",
      title: "Unsupported array",
      description:
        "An array property compiles as a preserve-only unsupported field with a warning diagnostic.",
      source: :json_schema,
      declaration_text: @unsupported_array_declaration,
      presentation_text: @unsupported_array_presentation,
      data_text: @unsupported_array_data
    },
    %Example{
      id: "talk-proposal-map",
      title: "Talk proposal (Map)",
      description:
        "The talk proposal in the Elixir Map source, with groups, roles and widgets inline.",
      source: :map,
      declaration_text: @talk_proposal_map_declaration,
      presentation_text: nil,
      data_text: ~s({"track": "Elixir"})
    },
    %Example{
      id: "pump-inspection",
      title: "Pump inspection",
      description: "An idiomatic Map-source example with ordered properties and constraints.",
      source: :map,
      declaration_text: @pump_inspection_declaration,
      presentation_text: nil,
      data_text: "{}"
    },
    %Example{
      id: "unsupported-kind",
      title: "Unsupported kind",
      description:
        "An unknown kind compiles as a preserve-only unsupported field with a warning diagnostic.",
      source: :map,
      declaration_text: @unsupported_kind_declaration,
      presentation_text: nil,
      data_text: ~s({"title": "Existing record", "tags": ["elixir", "phoenix"]})
    }
  ]

  @by_id Map.new(@examples, &{&1.id, &1})

  @spec default() :: Example.t()
  def default, do: hd(@examples)

  @spec get!(String.t()) :: Example.t()
  def get!(id), do: Map.fetch!(@by_id, id)

  @spec all() :: [Example.t()]
  def all, do: @examples
end
