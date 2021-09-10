defmodule DynamicLayout.Ecto.Node.Dom do
  use Ecto.Schema
  import Ecto.Changeset


  embedded_schema do
    field :tag,
          Ecto.Enum,
          values: DynamicLayout.Node.Data.Registry.available_tags(),
          default: Application.get_env(:dynamic_layout, :default_tag, :div)
    field :attributes, :map #DynamicLayout.Ecto.Node.Dom.Attribute
    field :variants, :map
    #embeds_many :variants, DynamicLayout.Ecto.Node.Dom.Variant
  end


  def changeset(%__MODULE__{} = model, attrs \\ %{}) do
    model
    |> cast(cast_attrs(attrs), [:tag, :attributes, :variants])
      #|> cast_embed(:variants)
    |> validate_required([:tag])
  end

  defp cast_attrs(attrs) do
    cast_tag(attrs)
    |> cast_variants()
  end

  defp cast_tag(%{tag: tag} = attrs) when is_atom(tag), do: Map.put(attrs, :tag, Atom.to_string(tag))
  defp cast_tag(attrs), do: attrs

  defp cast_variants(%{variants: variants} = attrs) do
    Map.put(
      attrs,
      :variants,
      Enum.reduce(
        variants,
        %{},
        fn {k, props}, acc ->

          Map.put(acc, k, cast_properties(props))
        end
      )
    )
  end
  defp cast_variants(attrs), do: attrs


  defp cast_properties(props) when is_list(props) do
    Enum.reduce(
      props,
      %{},
      fn {key, property}, acc ->
        Map.put(
          acc,
          key,
          Map.from_struct(Map.put(property, :properties, cast_properties(property.properties)))
          |> Map.drop([:help, :options])
        )
      end
    )
  end




end