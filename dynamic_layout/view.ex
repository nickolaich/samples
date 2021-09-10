defmodule DynamicLayout.View do
  # Building layout (recursive with DOM-tree inheritance)
  use Phoenix.HTML

  # box -> %DynamicLayout.Node

  alias DynamicLayout.{Node, Node.Dom, Node.Data, Property}
  @doc """
    Render Node and all it's children
  """
  @spec render(Node.t(), Keyword.t()) :: Phoenix.HTML.safe()
  def render(box, opts \\ [])

  def render(nodes, opts) when is_list(nodes) do
    Enum.reduce(nodes, [], &(&2 ++ [render(&1, opts)]))
  end
  def render(%Node{} = node, opts) do
    attrs = Map.to_list(node.dom.attributes)
            ++ (if node.dom.tag !== :html and opts[:dom_ids], do: [id: node.uid], else: [])
               #++ build_attributes(node.dom, opts)
            ++ build_attributes(
                 node.dom,
                 opts
                 |> Keyword.put(
                      :callback_attrs,
                      (if opts[:callback], do: apply(opts[:callback], [node, opts]), else: [])
                    )
               )
            |> attrs_from_requirements(node.requirements, opts)

    node_data_rendered = cond do
      !is_nil(node.data) ->
        render(
          node.data,
          opts
          |> Keyword.put(:uid, node.uid)
        )
      true -> nil
    end
    #node_data_rendered =
    content = (cond do
                 node.children != [] ->
                   Enum.reduce(
                     node.children,
                     [],
                     fn child, acc ->
                       acc ++ [render(child, opts)]
                     end
                   ) ++ (if is_tuple(node_data_rendered), do: node_data_rendered, else: [])
                 #true -> "-#{node.uid}-"
                 true ->
                   Phoenix.HTML.Tag.content_tag(:div, node_data_rendered)
               end)
    Phoenix.HTML.Tag.content_tag(node.dom.tag, content, attrs)
    #|> safe_to_string()
    #|> EEx.compile_string()


  end



  def render(%Property{} = prop, opts) do
    # return :safe
    prop.module.render(prop, opts) <> render_props(prop.properties, opts)
  end

  def render(%Data{} = data, opts) do
    # return :safe
    handler = opts[:data_handler] || DynamicLayout.Data.Handler

    substitutions = Map.merge(opts[:substitutions] || %{}, %{data: data.configuration || %{}})
    uid = opts[:uid] || nil
    #data.view.render(opts)

    cond do
      opts[:inline_edit] == true ->
        raw handler.render(
              %{kind: data.kind, substitutions: substitutions, mode: :configuration, socket: opts[:socket]}
            )
      #"<%= live_component @socket, ContentEditorWeb.LiveComponents.NodeDataEditor, id: uid %>"
      #                            <%= live_component @socket, ContentEditorWeb.LiveComponents.NodeDataEditor,
      #                                                                        id: "data-editor", node: @current, parent: @editor_module, parent_id: @id, configurator_assigns: @configurator_assigns %>
      opts[:ignore_data] == true -> data.kind

      opts[:compile] == true ->
        raw "<%= #{handler}.render(%{kind: #{data.kind}, substitutions: assigns[:#{uid}]}) %>"
      opts[:editor_preview] == true ->
        raw handler.render(
              %{
                kind: data.kind,
                substitutions: substitutions,
                assigns: Keyword.get(opts, :preview_assigns, %{}),
                mode: :preview,
                socket: opts[:socket]
              }
            )
      true ->

        raw handler.render(%{kind: data.kind, substitutions: substitutions})
    end
  end

  def render(nil, _), do: nil


  def render_props(props, opts) do
    # return :safe
    #prop.module.render(prop, opts)
    separator = opts[:separator] || " "
    Enum.reduce(
      props,
      "",
      fn x, acc ->
        case x do
          %Property{} = p -> "#{acc}#{separator}#{render(p, opts)}"
          {_, %Property{} = p} -> "#{acc}#{separator}#{render(p, opts)}"
        end
      end
    )
  end

  def build_attributes(prop, opts \\ [])
  def build_attributes(%Dom{} = dom, opts) do
    Enum.reduce(
      dom.variants,
      [],
      fn {variant, properties}, acc ->
        Enum.reduce(
          properties,
          acc,
          fn {_, prop}, acc ->
            acc ++ build_attributes(prop, Keyword.put(opts, :variant, variant))
          end
        )
      end
    )
    |> (fn attrs ->
      # inject default class to each node. (useful in builder/debug to see tree)
      if opts[:default_class] do
        attrs ++ [class: opts[:default_class]]
      else
        attrs
      end
        end).()
    |> (fn attrs ->
      # inject default attributes (on click etc handlers)
      if is_list(opts[:default_attrs]) do
        attrs ++ opts[:default_attrs]
      else
        attrs
      end
        end).()
    |> (fn attrs ->
      # inject default attributes (on click etc handlers)
      if is_list(opts[:callback_attrs]) and opts[:callback_attrs] !== [] do
        attrs ++ opts[:callback_attrs]
      else
        attrs
      end
        end).()

      # merge duplicates (there could be same properties built for different variants: w-full, md:w-full etc)
    |> Enum.reduce(
         [],
         fn res, acc ->
           case res do
             {k, values} ->
               if Keyword.has_key?(acc, k) do

                 Keyword.put(
                   acc,
                   k,
                   (if is_binary(values), do: [values], else: values) ++ (
                     if is_binary(acc[k]), do: [acc[k]], else: acc[k])
                 )
               else
                 Keyword.put(acc, k, (if is_binary(values), do: [values], else: values))
               end

             _ ->
               acc ++ [res]
           end
         end
       )
  end
  def build_attributes(%Property{} = prop, opts) do
    case prop.attr do
      nil ->
        build_attributes(prop.properties, opts)
      attr ->
        Keyword.put([], attr, build_property(prop, opts))
    end
  end
  def build_attributes(props, opts) when is_list(props) do
    Enum.reduce(
      props,
      [],
      fn x, acc ->
        case x do
          %Property{} = p -> acc ++ build_property(p, opts)
          {p_key, %Property{} = p} ->
            cond do
              is_list(opts[:ignore_properties]) && Enum.member?(opts[:ignore_properties], p_key) -> acc
              true -> acc ++ build_property(p, opts)
            end

        end
      end
    )
  end

  def build_property(%Property{} = prop, opts) do
    # self render (sometimes it's only container like a :class property that needs to wrap everything into class: [])
    # + all childs
    case prop.module.render(prop, opts) do
      nil -> build_attributes(prop.properties, opts)
      self -> [self | build_attributes(prop.properties, opts)]
    end

  end

  def attrs_from_requirements(attrs, requirement, opts) do
    case requirement do
      [r | tail] -> attrs_from_requirements(attrs, r, opts) ++ attrs_from_requirements(attrs, tail, opts)
      [r | []] -> attrs_from_requirements(attrs, r, opts)
      r when is_map(r) ->
        cond do
          Map.has_key?(r, :key) && Map.has_key?(r, :module) ->
            subs = Map.get(Keyword.get(opts, :substitutions, %{}), r.key)
            cond do
              Code.ensure_loaded?(r.module) && !is_nil(subs) && function_exported?(r.module, :attributes, 2) ->

                attrs ++ apply(r.module, :attributes, [subs, []])
              true -> attrs
            end
          true -> attrs
        end

      _ -> attrs
    end
  end


end