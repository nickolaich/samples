defmodule DynamicLayout.Ecto.Node.Requirement do
  use Ecto.Schema
  import Ecto.Changeset


  embedded_schema do
    field :name, :string
    field :key, :string
    field :help, :string
    field :module,
          Ecto.Enum,
          values: DynamicLayout.Node.Data.Registry.available_requirements(db: true)
  end

  def changeset(%__MODULE__{} = model, attrs \\ %{}) do

    model
    |> cast(cast_attrs(attrs), [:name, :module, :key, :help])
    |> validate_required([:name, :module, :key])
  end

  defp cast_attrs(attrs) do
    case attrs do
      %__MODULE__{} -> Map.from_struct(attrs)
      _ -> attrs
    end

    #cast_module(attrs)
  end

  #  defp cast_module(%{module: module} = attrs) when is_atom(module), do: Map.put(attrs, :module, Atom.to_string(module))
  #  defp cast_module(attrs), do: attrs

end