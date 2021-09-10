defmodule DynamicLayout.Ecto.Page do
  use Ecto.Schema
  import Ecto.Changeset
  alias DynamicLayout.Ecto.{Layout, Block}

  schema "content_pages" do
    field :name, :string
    field :rev, :integer, default: 0
    belongs_to :layout, Layout, foreign_key: :content_layout_id
    # Block is tree of nodes we will render inside of page's layout to "inner" node selected in layout
    belongs_to :content, Block, foreign_key: :content_block_id
    field :substitutions, :map
    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(
         attrs
         |> put_layout(),
         [:name, :content_layout_id, :substitutions, :rev]
       )
    |> cast_assoc(:content)
    |> validate_required([:name, :content])
  end


  defp put_layout(%{layout: %Layout{} = layout} = attrs) do
    Map.put(attrs, :content_layout_id, layout.id)
  end
  defp put_layout(%{layout: layout} = attrs) when is_integer(layout) or is_nil(layout) do
    Map.put(attrs, :content_layout_id, layout)
  end
  defp put_layout(attrs), do: attrs

end