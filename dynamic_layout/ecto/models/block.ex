defmodule DynamicLayout.Ecto.Block do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_blocks" do
    field :name, :string
    timestamps(type: :utc_datetime)
    field :phx_layout, :map
    field :shared_id, :integer
    field :rev, :integer, default: 0
    has_many :nodes, DynamicLayout.Ecto.Node, foreign_key: :content_block_id
    has_many :pages, DynamicLayout.Ecto.Page, foreign_key: :content_block_id
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(attrs, [:name, :phx_layout, :shared_id, :rev])
    |> validate_required([:name])
  end

end