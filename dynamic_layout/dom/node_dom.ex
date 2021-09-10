defimpl Jason.Encoder, for: [DynamicLayout.Node.Dom] do
  def encode(struct, opts) do
    variants = Enum.reduce(struct.variants, %{}, fn {k, v}, acc -> Map.put(acc, k, Enum.into(v, %{})) end)
    map = Map.put(struct, :variants, variants)
    Jason.Encode.map(map, opts)
  end
end

defmodule DynamicLayout.Node.Dom do
  #@derive Jason.Encoder
  defstruct [
    tag: :div,
    attributes: %{},
    variants: %{},
    #    :flexbox_vs_grid,
    #    :alignment,
    #    :spacing,
    #    :size,
    #    :typography,
    #    :backgrounds,
    #    :border,
    #    :shadow,
    #    :opacity,
    #    :mixblend,
    #    :filters,
    #    :transform,
    #    :transition
  ]
  use DynamicLayout, :builder
  use DynamicLayout, :property
  alias DynamicLayout.{Node, Property, TreeHelpers}


  def create(opts \\ []) do
    %__MODULE__{
      tag: node_tag(opts),
      attributes: opts[:attributes] || %{}
    }
  end

  def build_variant(%__MODULE__{} = dom, variant, opts) do
    Map.put(dom, :variants, Map.put(dom.variants, variant, opts))
  end

  #  def property(:layout, v, opts) do
  #    Layout.create(opts)
  #    |> Map.put(:value, v)
  #  end
  def property(key, v, opts) when is_list(key) do
    key
    |> Enum.map(&(property(&1, v, opts)))
  end

  # not supported type
  def property(k, _v, opts) do
    cond do
      !is_nil(opts[:module]) -> apply(opts[:module], :property, [k, opts])
      true -> raise "can't create property <#{k}>. No UI module specified"
    end
  end

  def node_tag(opts) when is_list(opts), do: node_tag(opts[:tag])
  def node_tag(nil), do: :div
  def node_tag(tag) when is_binary(tag), do: String.to_atom(tag)
  def node_tag(tag) when is_atom(tag), do: tag



  def find_variant(src, variant, default \\ nil)
  def find_variant(%Node{dom: dom}, variant, default), do: find_variant(dom, variant, default)
  def find_variant(%__MODULE__{} = dom, variant, default), do: Map.get(dom.variants, variant, default)

  def modify_variant(%__MODULE__{} = dom, variant, data),
      do: Map.put(dom, :variants, Map.put(dom.variants, variant, data))
  def init_variant(%__MODULE__{} = dom, variant, data),
      do: Map.put(dom, :variants, Map.put(dom.variants, variant, data))



  def find_property(%Node{dom: dom}, variant, key), do: find_property(dom, variant, key)
  def find_property(%__MODULE__{} = dom, variant, key) do
    Property.fetch_by_path(find_variant(dom, variant, []), build_path(key))
  end



  def build_path(key, path \\ [])
  def build_path(key, path) when is_atom(key), do: build_path([key], path)
  def build_path(key, path) when is_binary(key) do
    case String.split(key, ".") do
      list when is_list(list) ->
        build_path(list, path)
      _ -> # single string key
        build_path(String.to_atom(key), path)
    end
  end
  def build_path(key, path) when is_list(key),
      do: Enum.reduce(
        key,
        path,
        fn x, acc ->
          cond do
            is_atom(x) -> acc ++ [x]
            is_binary(x) -> acc ++ [String.to_atom(x)]
            true -> build_path(x, acc)
          end

        end
      )

  def init_property(src, variant, key, opts \\ [])
  def init_property(%Node{dom: dom} = box, variant, key, opts) do
    Map.put(box, :dom, init_property(dom, variant, key, opts))
  end
  def init_property(%__MODULE__{} = dom, variant, key, opts) do
    property = create_property(%Property{}, build_path(key), opts)
    case find_variant(dom, variant) do
      nil ->
        # no variant in dom. it's required to create variant first and add property to modify it
        init_variant(dom, variant, Keyword.put([], property.key, property))
      v ->
        # replace property at variant
        modify_variant(dom, variant, Keyword.put(v, property.key, property))
    end
  end

  def init_property_tree(key, opts \\ [])
  def init_property_tree(key, opts) do
    create_property(%Property{}, build_path(key), opts)
  end


  def create_property(acc, key_path, opts) do
    case key_path do
      [k | []] ->
        property(k, opts[:value], opts)
      [k | tail] ->
        prop = property(k, nil, opts)
        child = create_property(
          acc,
          tail,
          opts
          |> Keyword.put(:module, prop.module)
        )
        Map.put(
          prop,
          :properties,
          Keyword.put([], child.key, child)
        )
    end
  end

  def drop_property(src, variant, key, opts \\ [])
  def drop_property(%Node{dom: dom} = container, variant, key, opts),
      do: Map.put(container, :dom, drop_property(dom, variant, key, opts))
  def drop_property(%__MODULE__{} = dom, variant, key, opts) do
    case find_variant(dom, variant) do
      nil ->
        # no variant
        dom
      v ->
        case find_property(dom, variant, key) do
          %Property{} = existing ->
            # modify variant with dropped property in it
            modify_variant(dom, variant, Property.drop(v, build_path(key)))
          _ ->
            # no prop, return variant
            dom
        end

    end
  end

  def modify_property(src, variant, key, attrs, opts \\ [])
  def modify_property(%Node{dom: dom} = container, variant, key, attrs, opts),
      do: Map.put(container, :dom, modify_property(dom, variant, key, attrs, opts))

  def modify_property(%__MODULE__{} = dom, variant, key, attrs, opts) do
    case find_variant(dom, variant) do
      nil ->
        # no variant in dom. it's required to create variant first and add property to modify it
        property = create_property(%Property{}, build_path(key), opts)
        init_variant(
          dom,
          variant,
          Keyword.put([], property.key, property)
          |> Property.modify(build_path(key), attrs)
        )
      v ->
        case find_property(dom, variant, key) do
          %Property{} = _existing ->
            # existing property
            Property.modify(v, build_path(key), attrs)
            modify_variant(dom, variant, Property.modify(v, build_path(key), attrs))
          _ ->
            # new prop in tree, need to merge into parent

            new = create_property(
              %Property{},
              build_path(key),
              opts
              |> Keyword.merge(Map.to_list(attrs))
            )
            #|> Property.modify(build_path(key), attrs)
            modify_variant(
              dom,
              variant,
              TreeHelpers.merge(%{properties: v}, %{properties: Keyword.put([], hd(build_path(key)), new)}).properties
            )
        end

    end
  end



  def encode!(%__MODULE__{} = dom, _opts \\ []) do
    Jason.encode!(dom, [])
  end

  def decode!(json, _opts \\ []) do
    d = struct(__MODULE__, Jason.decode!(json, native: true, keys: :atoms))
    d
    |> Map.put(:tag, String.to_atom(d.tag))
    |> Map.put(
         :variants,
         Enum.reduce(
           d.variants,
           %{},
           fn {k, v}, acc ->
             Map.put(
               acc,
               k,
               Map.to_list(v)
               |> Property.decode!(nil)
             )
           end
         )
       )
  end

  #  def merge_property(%__MODULE__{} = dom, variant, path_to, property) do
  #    case find_variant(dom, variant) do
  #      nil ->
  #        # no path, error?
  #        raise "can't merge property by path. variant #{variant} isn't exists."
  #      v ->
  #        case find_property(dom, variant, path_to) do
  #          %Property{} = parent ->
  #            # existing parent, modify it's properties with new one
  #            #Property.modify(v, build_path(key), attrs)
  #
  #            modify_variant(
  #              dom,
  #              variant,
  #              Property.modify(
  #                v,
  #                build_path(path_to),
  #                %{properties: Keyword.put(parent.properties, property.key, property)}
  #              )
  #            )
  #          _ ->
  #            raise "can't merge property by path. parent isn't exists."
  #        end
  #    end
  #  end
  def add_attribute(src, key, value \\ nil, opts \\ [])
  def add_attribute(%Node{dom: dom} = box, key, value, opts) do
    Map.put(box, :dom, add_attribute(dom, key, value, opts))
  end
  def add_attribute(%__MODULE__{} = dom, key, value, _opts) do
    Map.put(dom, :attributes, Map.put(dom.attributes, key, value))
  end

  def set_attributes(src, attrs \\ %{}, opts \\ [])
  def set_attributes(%Node{dom: dom} = box, attrs, opts) do
    Map.put(box, :dom, set_attributes(dom, attrs, opts))
  end
  def set_attributes(%__MODULE__{} = dom, attrs, _opts) do
    Map.put(dom, :attributes, attrs)
  end


  def set_variants(src, variants \\ %{}, opts \\ [])
  def set_variants(%Node{dom: dom} = box, variants, opts) do
    Map.put(box, :dom, set_variants(dom, variants, opts))
  end
  def set_variants(%__MODULE__{} = dom, variants, _opts) do
    Map.put(dom, :variants, variants)
  end
end