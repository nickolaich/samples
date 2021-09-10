defmodule DynamicLayout.Ecto.Node.Data do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_node_data" do
    field :kind, Ecto.Enum, values: DynamicLayout.Ecto.Data.Registry.ecto_enum()
    field :version, :integer, default: 1
    field :configuration, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(attrs, [:kind, :version, :configuration])
    |> validate_required([:kind, :version])
  end
end