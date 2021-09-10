defmodule DynamicLayout.Ecto.Reader do

  defdelegate repo(opts), to: DynamicLayout.Ecto.Service
  defdelegate preloads(r, list, opts), to: DynamicLayout.Ecto.Service

  alias DynamicLayout.Ecto.Node, as: EctoNode
  alias DynamicLayout.Ecto.Node.Data, as: EctoNodeData
  alias DynamicLayout.Ecto.{Block, Layout, Page}
  alias DynamicLayout.Ecto.Storage
  alias DynamicLayout.Node, as: DomNode
  alias DynamicLayout.Node.Data, as: DomNodeData
  alias DynamicLayout.Builder


  def ecto_opts_for_shared(opts, src) do
    shared_id = Map.get(src, :shared_id)
    cond do
      is_integer(shared_id) and (shared_id > 0) ->
        Keyword.put(opts, :prefix, nil)
      true -> opts
    end
  end

  def ecto_to_dom(src, opts \\ [])

  def ecto_to_dom(%Page{} = page, opts) do
    case page.layout do
      %Layout{} = layout ->
        ecto_to_dom(layout, Keyword.put(opts, :inner, page.content))
      _ ->
        ecto_to_dom(page.content, opts)
    end
  end

  def ecto_to_dom(%Layout{} = layout, opts) do
    cond do
      is_integer(layout.shared_id) && (layout.shared_id > 0) ->
        shared_opts = Keyword.drop(opts, [:prefix, :tenant])
                      |> Keyword.drop([:inner])
                      |> Keyword.put(:skip_tenant, true)
                      |> Keyword.put(:prefix, nil)

        Storage.get_layout(layout.shared_id, shared_opts)
        |> ecto_to_dom(shared_opts)
      !is_nil(opts[:inner_content]) ->
        ecto_opts = opts
        ecto_to_dom(layout.block, ecto_opts)
        |> Builder.update_node_children(
             layout.inner.uid,
             ecto_to_dom(
               opts[:inner_content],
               ecto_opts
               |> Keyword.put(:prefix, Keyword.get(opts, :inner_prefix))
             ),
             ecto_opts
           )
      true ->
        case opts[:inner] do
          %Block{} = inner ->
            case ecto_to_dom(layout.block, opts) do
              [r | []] ->
                Builder.update_node_children(r, layout.inner.uid, ecto_to_dom(inner, opts))
              other -> other
            end
          _ ->
            ecto_to_dom(layout.block, opts)
        end
    end


  end

  def ecto_to_dom(%Block{} = block, opts) do
    cond do
      is_integer(block.shared_id) && (block.shared_id > 0) ->
        shared_opts = Keyword.drop(opts, [:prefix, :tenant])
                      |> Keyword.put(:skip_tenant, true)
        ecto_to_dom(Storage.get_block(block.shared_id, shared_opts), shared_opts)
      true ->
        Storage.node_tree(block, opts)
        |> Enum.map(&(ecto_to_dom(&1, opts)))
    end
  end

  def ecto_to_dom(%EctoNode{} = n, opts) do
    tree = Storage.node_tree(n, opts)
    convert_ecto_node_to_dom(tree.node, tree.children, opts)
  end

  # tree structure
  def ecto_to_dom(%{children: children, node: node}, opts) do
    convert_ecto_node_to_dom(node, children, opts)
  end

  def ecto_to_dom(%EctoNodeData{} = data, _opts) do
    config = Map.put(data.configuration, "tenant", Ecto.get_meta(data, :prefix))
             |> Map.put("content_node_data_id", data.id)
    %DomNodeData{
      kind: data.kind,
      version: data.version,
      configuration: config
    }
  end

  def ecto_to_dom(data, opts) when is_list(data) do
    Enum.reduce(data, [], &(&2 ++ [ecto_to_dom(&1, opts)]))
  end

  def put_children_from_data(node, opts) do
    cond do
      opts[:data_block_provider] ->
        case node.data do
          %DynamicLayout.Node.Data{
            configuration: %{
              "block" => block_id
            }
          } = data ->
            if opts[:data_block_provider] == data.kind do
              DomNode.put_children(node, ecto_to_dom(Storage.get_block(block_id, opts), opts))
              |> DomNode.put_data(Map.put(data, :configuration, Map.put(data.configuration, "tenant", opts[:prefix])))
            else
              node
            end
          _ -> node
        end
      true -> node
    end
  end

  def tenants(opts \\ []) do
    Triplex.all(repo(opts))
  end

  def get_phx_layout(src, opts \\ []) do
    shared_opts = Keyword.drop(opts, [:prefix, :tenant])
                  |> Keyword.put(:skip_tenant, true)
    (case src do
       %Page{} = p ->
         case p.layout do
           %Layout{} = l -> get_phx_layout(l, opts)
           _ -> nil
         end
       %Block{} = b ->
         cond do
           is_integer(b.shared_id) && (b.shared_id > 0) ->
             get_phx_layout(Storage.get_block(b.shared_id, shared_opts), shared_opts)
           true -> b.phx_layout
         end
       %Layout{} = l ->
         cond do
           is_integer(l.shared_id) && l.shared_id > 0 ->
             get_phx_layout(Storage.get_layout(l.shared_id, shared_opts), shared_opts)
           true -> l.phx_layout
         end
       _ -> nil
     end)
  end

  defp convert_ecto_node_to_dom(%EctoNode{} = n, children, opts \\ []) do
    dom = n.dom
    converted = DomNode.create(
                  uid: n.uid,
                  position: n.position,
                  name: n.name,
                  requirements: n.requirements,
                  #children: children
                )
                |> (
                     fn node ->
                       case dom do
                         %DynamicLayout.Ecto.Node.Dom{} = d ->
                           DomNode.put_dom(
                             node,
                             %DynamicLayout.Node.Dom{
                               attributes: d.attributes,
                               #           uid: dom.uid,
                               tag: dom.tag,
                               variants: (
                                 if is_map(dom.variants),
                                    do: decode_variants(DynamicLayoutEcto.key_to_atom(dom.variants)), else: %{})
                             }
                           )
                         %DynamicLayout.Node.Dom{} = d ->
                           DomNode.put_dom(node, d)
                         _ ->
                           node
                         #DomNode.put_dom(node, %DynamicLayout.Node.Dom{tag: :virtual})
                       end
                     end
                     ).()
                |> (
                     fn node ->
                       case n.data do
                         %EctoNodeData{} = d ->
                           DomNode.put_data(node, ecto_to_dom(d))
                           |> put_children_from_data(opts)
                         _ -> node
                       end
                     end
                     ).()

    Enum.reduce(
      children,
      converted,
      fn ch, %{children: acc_children} = acc ->
        %{acc | children: acc_children ++ [convert_ecto_node_to_dom(ch.node, ch.children, opts)]}
      end
    )
  end

  defp decode_variants(variants) do
    #    variants
    Enum.reduce(
      variants,
      %{},
      fn {k, props}, acc ->
        Map.put(acc, k, decode_properties(%{properties: props}))
      end
    )
  end

  defp decode_properties(%{properties: properties}) do
    Enum.reduce(
      properties,
      [],
      fn {k, v}, acc ->
        props = Map.put(v, :properties, decode_properties(%{properties: v.properties}))
        property = DynamicLayout.Property.build(k, Map.to_list(props))
                   |> cast_property()
        Keyword.put(acc, k, property)
      end
    )
  end




  defp cast_property(%DynamicLayout.Property{} = p) do
    p = Map.put(p, :module, String.to_existing_atom(p.module))
    if is_binary(p.attr) do
      Map.put(p, :attr, String.to_atom(p.attr))
    else
      p
    end
  end

end