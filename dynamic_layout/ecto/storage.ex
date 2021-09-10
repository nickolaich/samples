defmodule DynamicLayout.Ecto.Storage do
	use DynamicLayout.Ecto.Service
	alias DynamicLayout.Ecto.Node, as: EctoNode
	alias DynamicLayout.Ecto.{Block, Layout, Page}
	alias DynamicLayout.Builder
	import Ecto.Query
	
	
	
	# 1. iterate through existing db nodes structure and if there is nodes not existing in memory-tree -> delete from DB
	# (it looks like they were deleted during editing)
	# 2. Iterate through tree from memory and update or create nodes in DB
	def save_tree(dom_tree, src, opts \\ [])
	#  def save_tree(dom_tree, src, opts) when is_list(dom_tree) do
	#    # list of trees
	#    Enum.reduce(dom_tree, [], &(&2 ++ [save_tree(&1, src, opts)]))
	#  end
	def save_tree(dom_tree, %Block{} = src, opts) do
		get_nodes(src, opts)
		|> Enum.each(
			   fn n ->
			     case Builder.find_node(dom_tree, n.uid, to_string: true) do
				     nil ->
					     delete_node(n.uid, opts)
				     _ -> nil
			     end
			
			   end
		   )
		
		create_node(dom_tree, src, opts)
	end
	def save_tree(dom_tree, %Page{} = src, opts) do
		save_tree(dom_tree, src.content, opts)
	end
	
	
	# Create new node from tree
	def create_node(node, block \\ nil, opts \\ [])
	def create_node(nodes, src, opts) when is_list(nodes) do
	  # list of trees
		elem(
			Enum.reduce(
				nodes,
				{[], 0},
				&(
					{
						elem(&2, 0) ++ [
							create_node(
								&1,
								src,
								opts ++ [
									attrs: %{
										#position: (elem(&2, 1) + 1)
									}
								]
							)
						],
						(elem(&2, 1) + 1)
					})
			),
			0
		)
	end
	def create_node(%DynamicLayout.Node{} = node, block, opts) do
		attrs = Map.from_struct(node)
		        |> Map.merge(Keyword.get(opts, :attrs, %{}))
		opts = Keyword.drop(opts, [:attrs])
		case create_node(attrs, block, opts) do
			{:ok, ecto_node} ->
				Enum.reduce(
					node.children,
					{:ok, [ecto_node], 0},
					fn child, acc ->
					  case acc do
						  {:error, _, pos} ->
							# Error happened in chain
							  {:error, {:skiped, child, pos}}
						  {:ok, nodes, pos} ->
							  case create_node(
								       Map.put(child, :parent_id, ecto_node.id),
								       #|> Map.put(:position, pos),
								       block,
								       opts
							       ) do
								  {:ok, n, _} -> {:ok, n ++ nodes, pos + 1}
								  {:error, ch, _} -> {:error, ch ++ nodes, pos + 1}
							  end
					  end
					end
				)
			err? -> err?
		end
	end
	def create_node(attrs, nil, opts) do
		EctoNode.changeset(%EctoNode{}, attrs)
		|> insert_to_tenant(opts)
	end
	
	def create_node(attrs, %DynamicLayout.Ecto.Page{} = page, opts) do
		create_node(attrs, page.content, opts)
	end
	def create_node(attrs, %DynamicLayout.Ecto.Block{} = block, opts) do
		uid = Map.get(attrs, :uid)
		cond do
			!is_nil(uid) ->
				case find_node(uid, block, opts) do
					%EctoNode{} = n ->
						update_node(n, attrs, opts)
					_ ->
						new_node(attrs, block, opts)
				end
			true ->
				new_node(attrs, block, opts)
		end
	end
	
	defp new_node(attrs, %DynamicLayout.Ecto.Block{} = block, opts \\ []) do
		EctoNode.changeset(%EctoNode{}, attrs)
		|> Ecto.Changeset.put_assoc(:block, block)
		|> insert_to_tenant(opts)
	end
	
	
	def delete_node(n, opts \\ [])
	def delete_node(uid, opts) when is_binary(uid) do
		find_by_filters(EctoNode, %{uid: uid}, opts)
		|> delete_node(opts)
	end
	def delete_node(id, opts) when is_integer(id) do
		get_node(id, opts)
		|> delete_node(opts)
	end
	def delete_node(%EctoNode{} = n, opts) do
	  # delete whole tree
		Enum.each(get_children(n, opts), fn ch -> delete_node(ch, opts) end)
		delete_from_tenant(n, opts)
	end
	def delete_node(nil, _), do: nil
	
	def get_node(id, opts \\ []) do
		find_by_filters(EctoNode, %{id: id}, opts)
	end
	
	
	def find_or_create_root_node(%Block{} = block, opts) do
		case find_all(
			     %{parent_id: nil},
			     block,
			     opts
		     ) do
			
			[] ->
			  # auto create root node
				{:ok, root} = create_node(
					%{uid: UUID.uuid1(), name: "page canvas ##{opts[:page_id]}"},
					block,
					opts
				)
				root
			[root | []] -> root
			nodes ->
			  # there is more than one root node, delete them and auto-create new
				Enum.each(nodes, fn ch -> delete_node(ch, opts) end)
				# next call will return it
				find_or_create_root_node(block, opts)
		end
	end
	
	
	def find_node(attrs, block \\ nil, opts \\ [])
	def find_node(uid, block, opts) when is_atom(uid), do: find_node(Atom.to_string(uid), block, opts)
	def find_node(uid, block, opts) when is_binary(uid) do
		find_node(%{uid: uid}, block, opts)
	end
	def find_node(attrs, block, opts) do
		filters = (case block do
			           %Block{id: block_id} -> %{content_block_id: block_id}
			           _ -> %{}
		           end)
		          |> Map.merge(attrs)
		find_by_filters(EctoNode, filters, opts)
		|> preloads([:block, :data], opts)
	end
	
	def find_all(attrs, block, opts) do
		filters = (case block do
			           %Block{id: block_id} -> %{content_block_id: block_id}
			           _ -> %{}
		           end)
		          |> Map.merge(attrs)
		find_all_by_filters(EctoNode, filters, opts)
	end
	
	def get_children(%EctoNode{id: parent_id} = _n, opts) when is_integer(parent_id) do
		find_all_by_filters(EctoNode, %{parent_id: parent_id}, opts)
	end
	
	def update_node(node, attrs, opts \\ [])
	def update_node(%EctoNode{} = n, attrs, opts) do
		EctoNode.changeset(n, attrs)
		|> update_at_tenant(opts)
	end
	#  def update_node(%DynamicLayout.Node{} = n, attrs, opts) do
	#    EctoNode.changeset(n, attrs)
	#    |> update_at_tenant(opts)
	#  end
	
	
	def create_block(attrs, opts \\ []) do
		Block.changeset(%Block{}, attrs)
		|> insert_to_tenant(opts)
	end
	def update_block(%Block{} = block, attrs, opts \\ []) do
		Block.changeset(block, attrs)
		|> update_at_tenant(opts)
	end
	
	def get_block(id, opts \\ []) do
		find_by_filters(Block, %{id: id}, opts)
		|> preloads([:nodes], opts)
	end
	def delete_block(%Block{} = block, opts \\ []) do
		delete_from_tenant(block, opts)
	end
	def get_blocks(attrs \\ %{}, opts \\ []) do
	  #find_all_by_filters(Block, attrs, opts)
		repo(opts).all(
			query_by_fields(Block, attrs, opts)
			|> join(:left, [m], p in "content_pages", on: m.id == p.content_block_id)
			|> where([m, p], is_nil(p.id))
			|> order_by([m], m.id),
			opts
		)
	end
	
	def create_layout(attrs, opts \\ []) do
		Layout.changeset(%Layout{}, attrs)
		|> insert_to_tenant(opts)
	end
	def update_layout(%Layout{} = l, attrs, opts \\ []) do
		{:ok, _layout} = Layout.changeset_update(l, attrs)
		                 |> update_at_tenant(opts)
		get_layout(l.id, opts)
	end
	def delete_layout(%Layout{} = l, opts \\ []) do
		delete_from_tenant(l, opts)
	end
	def get_layout(id, opts \\ []) do
		find_by_filters(Layout, %{id: id}, opts)
		|> preloads([:block, :inner], opts)
	end
	def get_layouts(attrs \\ %{}, opts \\ []) do
		find_all_by_filters(
			Layout,
			attrs
			|> Map.put(:order, fn q -> order_by(q, [m], m.id) end),
			opts
		)
	end
	
	def create_page(attrs, opts \\ []) do
		Page.changeset(
			%Page{},
			attrs
			|> Map.put(:content, %{name: "inner-block"})
		)
		|> Ecto.Changeset.put_assoc(:layout, Map.get(attrs, :layout))
		|> insert_to_tenant(opts)
	end
	
	def get_page(attrs, opts \\ [])
	def get_page(attrs, opts) when is_integer(attrs) or is_binary(attrs) do
		get_page(%{id: attrs}, opts)
	end
	def get_page(attrs, opts) when is_map(attrs) do
		find_by_filters(Page, attrs, opts)
		|> preloads([:content, layout: [:block, :inner]], opts)
	end
	def get_pages(attrs, opts \\ []) do
		find_all_by_filters(
			Page,
			attrs
			|> Map.put(:order, fn q -> order_by(q, [m], m.id) end),
			opts
		)
		|> preloads([:content, :layout], opts)
	end
	def count_pages(attrs, opts \\ []) do
		count_all_by_filters(Page, attrs, opts)
	end
	
	def update_page(%Page{} = p, attrs, opts \\ []) do
		Page.changeset(p, attrs)
		|> Map.put(:action, :update)
		|> update_at_tenant(opts)
	end
	
	def delete_page(%Page{} = p, opts \\ []) do
		delete_block(
			p.content
			|> preloads(:pages, opts)
		)
		delete_from_tenant(p, opts)
	end
	
	def add_page_node(%Page{} = page, attrs, opts \\ []) do
		create_node(attrs, page.content, opts)
	end
	
	def get_nodes(src, opts \\ [])
	def get_nodes(%Page{} = page, opts) do
		get_nodes(page.content, opts)
	end
	def get_nodes(%Layout{} = layout, opts) do
		get_nodes(layout.block, opts)
	end
	def get_nodes(%Block{} = block, opts) do
		find_all(%{content_block_id: block.id, order: fn q -> order_by(q, [m], m.position) end}, nil, opts)
		|> preloads([:data], opts)
	end
	
	
	# Recursively read nodes tree
	# Not efficient and needs caching. Not recommended to call it every time on the fly to build tree.
	def node_tree(parent, opts \\ [])
	def node_tree(%EctoNode{} = parent, opts) do
		children_query =
		  EctoNode
		  |> where([n], n.parent_id == ^parent.id)
		  |> order_by([n], n.position)
		%{
			node: parent,
			children: Enum.map(
				repo(opts).all(children_query, opts)
				|> preloads([:data], opts),
				fn ch ->
				  node_tree(ch, opts)
				end
			)
		}
	end
	
	# nodes tree for block
	def node_tree(%Block{} = block, opts) do
		find_all(
			%{content_block_id: block.id, parent_id: nil, order: fn q -> order_by(q, [m], m.position) end},
			nil,
			opts
		)
		|> preloads([:data], opts)
		|> Enum.map(&(node_tree(&1, opts)))
	end

end