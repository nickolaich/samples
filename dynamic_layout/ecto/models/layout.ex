defmodule DynamicLayout.Ecto.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_layouts" do
    field :name, :string
    field :phx_layout, :map
    field :shared_id, :integer
    field :rev, :integer, default: 0
    belongs_to :block, DynamicLayout.Ecto.Block, foreign_key: :content_block_id
    belongs_to :inner, DynamicLayout.Ecto.Node, foreign_key: :inner_node_id
    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(attrs, [:name, :phx_layout, :shared_id, :rev])
    |> put_assoc(:block, Map.get(attrs, :block))
    |> put_assoc(:inner, Map.get(attrs, :inner))
    |> validate_required([:name])
  end

  def changeset_update(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(attrs, [:name, :inner_node_id, :content_block_id, :phx_layout, :shared_id, :rev])
    |> validate_required([:name])
  end

end