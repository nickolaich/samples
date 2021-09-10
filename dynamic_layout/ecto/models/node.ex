defmodule DynamicLayout.Ecto.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_nodes" do
    field :uid, :string
    field :name, :string
    field :position, :integer # ordering of nodes inside of same level at tree's branch
    belongs_to :parent, DynamicLayout.Ecto.Node
    embeds_one :dom, DynamicLayout.Ecto.Node.Dom, on_replace: :update
    belongs_to :block, DynamicLayout.Ecto.Block, foreign_key: :content_block_id
    belongs_to :data, DynamicLayout.Ecto.Node.Data, foreign_key: :content_node_data_id, on_replace: :update
    embeds_many :requirements, DynamicLayout.Ecto.Node.Requirement, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(cast_attrs(attrs), [:uid, :parent_id, :position, :name])
    |> cast_assoc(:block)
    |> cast_assoc(:data)
    |> cast_embed(:dom)
    |> cast_embed(:requirements)
    |> validate_required([:uid])
  end

  defp cast_attrs(attrs) do
    cast_dom(attrs)
    |> cast_uid()
    |> cast_parent_id()
    |> cast_data()
  end

  defp cast_dom(%{dom: %DynamicLayout.Node.Dom{} = d} = attrs), do: Map.put(attrs, :dom, Map.from_struct(d))
  defp cast_dom(attrs), do: attrs

  defp cast_uid(%{uid: uid} = attrs) when is_atom(uid), do: Map.put(attrs, :uid, Atom.to_string(uid))
  defp cast_uid(attrs), do: attrs

  defp cast_parent_id(%{parent_id: parent_id} = attrs) when is_atom(parent_id), do: Map.put(attrs, :parent_id, Atom.to_string(parent_id))
  defp cast_parent_id(attrs), do: attrs

  defp cast_data(%{data: %DynamicLayout.Node.Data{} = data} = attrs), do: Map.put(attrs, :data, Map.from_struct(data))
  defp cast_data(attrs), do: attrs
end