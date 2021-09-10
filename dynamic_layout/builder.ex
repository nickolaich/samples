defmodule DynamicLayout.Builder do
  # Building layout (recursive with DOM-tree inheritance)
	alias DynamicLayout.{Node, Node.Dom, Node.Data}
	
	# box -> %DynamicLayout.Node
	
	defdelegate init_property(src, variant, keypath, opts), to: Dom
	defdelegate add_attribute(src, k, v), to: Dom
	defdelegate add_attribute(src, k), to: Dom
	defdelegate set_attributes(src, attrs, opts), to: Dom
	
	
	def node(opts \\ []) do
	  # return BOX
		Node.create(opts)
	end
	
	@spec add_node(Node.t(), Node.t()) :: Phoenix.HTML.safe()
	def add_node(%Node{} = container, %Node{} = node) do
		Map.put(container, :children, container.children ++ [node])
	end
	def add_node(%Node{} = container, node_opts) when is_list(node_opts) do
		add_node(
			container,
			Node.create(
				node_opts
				|> append_property_module(container, :property_module)
			)
		)
	end
	def add_node(%Node{} = container, nil) do
	  # default opts
		add_node(container, Node.create([property_module: container.property_module]))
	end
	
	def find_node(src, k, opts \\ [])
	def find_node(nodes, k, opts) when is_list(nodes) do
		Enum.find(nodes, &(!is_nil(find_node(&1, k, opts))))
	end
	def find_node(%Node{} = container, k, opts) do
		DynamicLayout.TreeHelpers.find(container, k, Keyword.merge([list_key: :children, lookup_key: :uid], opts))
	end
	
	def update_node(container, k, attrs, opts \\ []) do
		update_fun = fn n ->
			cond do
				is_function(attrs, 1) -> attrs.(n)
				is_function(attrs, 2) -> attrs.(n, opts)
				
				is_map(attrs) -> Map.merge(n, attrs)
				true -> raise("can't update node. attrbites not a map neither function")
			end
		end
		DynamicLayout.TreeHelpers.update(container, k, update_fun, [], list_key: :children, lookup_key: :uid)
	end
	
	def delete_node(container, k, fun, opts \\ []) do
		DynamicLayout.TreeHelpers.delete(container, k, fun, list_key: :children, lookup_key: :uid)
	end
	
	# It's just a wrapper
	def update_node_property(container, uid, variant, property_path, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Dom.init_property(n, variant, property_path, append_property_module(opts, container)) end,
			opts
		)
	end
	def update_node_property_value(container, uid, variant, property_path, value, opts \\ []) do
		update_node(
			container,
			uid,
			fn n ->
			  set_dom_property_value(n, variant, property_path, value, append_property_module(opts, container))
			end,
			opts
		)
	end
	
	def update_node_variants(container, uid, variants, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Dom.set_variants(n, variants, opts) end,
			opts
		)
	end
	
	def update_node_attributes(%Node{} = container, uid, attributes, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> set_attributes(n, attributes, opts) end,
			opts
		)
	end
	
	def update_node_data(container, uid, data, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> case data do
				        nil -> Node.clear_data(n)
				        %DynamicLayout.Node.Data{} = d -> Node.put_data(n, d)
				        %{configuration: config} ->
					        Node.put_data(n, Map.put(n.data, :configuration, config))
				        _ -> raise("Invalid node data passed")
			          #                d ->
			          #                  case d do
			          #                    %DynamicLayout.Node.Data{} -> Node.put_data(n, d)
			          #                    %{configuration: config} ->
			          #                      Node.put_data(n, Map.put(n.data, :configuration, config))
			          #                  end
			
			        end
			end,
			opts
		)
	end
	
	def update_node_children(container, uid, children, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Node.put_children(n, children) end,
			opts
		)
	end
	
	def add_node_children(%Node{} = container, parent_uid, new_child, opts \\ []) do
		update_node(
			container,
			parent_uid,
			fn n -> Node.put_children(n, n.children ++ [new_child]) end,
			opts
		)
	end
	
	def update_node_requirements(node, uid, requirements, opts \\ [])
	def update_node_requirements(%Node{} = container, nil, requirements, _opts) do
	  # if uid nil -> update on self instance
		Node.put_requirements(container, requirements)
	end
	def update_node_requirements(%Node{} = container, uid, requirements, opts) do
		update_node(
			container,
			uid,
			fn n -> update_node_requirements(n, nil, requirements, opts) end,
			opts
		)
	end
	
	def fetch_all_requirements(container, opts \\ [])
	def fetch_all_requirements(container, opts) when is_list(container) do
		Enum.reduce(container, [], &(&2 ++ fetch_all_requirements(&1, opts)))
	end
	def fetch_all_requirements(%Node{} = container, opts) do
		DynamicLayout.TreeHelpers.collect(
			container,
			[],
			Keyword.merge([list_key: :children, lookup_key: :requirements, flatten: true], opts)
		)
	end
	
	
	
	def set_dom_property_value(%Node{} = node, variant, property_key, value, opts \\ []) do
		Map.put(node, :dom, Dom.modify_property(node.dom, variant, property_key, %{value: value}, opts))
	end
	
	
	defp detect_property_module(%Node{} = n, node_opts) do
		Keyword.get(node_opts, :property_module, n.property_module)
	end
	
	defp append_property_module(node_opts, %Node{} = n, key \\ :module) do
		Keyword.put(node_opts, key, detect_property_module(n, node_opts))
	end
	
	def set_dom_tag(container, uid, tag, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Map.put(n, :dom, Map.put(n.dom, :tag, Dom.node_tag(tag))) end,
			opts
		)
	end
	
	def set_node_position(container, uid, position, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Node.put_position(n, position) end,
			opts
		)
	end
	
	def set_node_property_module(container, uid, module, opts \\ []) do
		update_node(
			container,
			uid,
			fn n -> Map.put(n, :property_module, module) end,
			opts
		)
	end

end