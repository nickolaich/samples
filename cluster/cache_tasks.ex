defmodule Lms.Tasks.Cache do
	use Task
	require Logger
	alias Ecto.Schema.Metadata
	
	def start_link(arg) do
		Task.start_link(__MODULE__, :run, [arg])
	end
	
	def run(arg) do
	  #IO.inspect "run cache task"
	  #IO.inspect arg
	end

	
	def clear_caches(opts \\ []) do
		Lms.Regions.RegionSelector.clear_cache(nil, nil)
		Lms.Clients.Detector.clear_domains_cache()
		Lms.Acl.clear_roles_cache(nil)
		clients = opts[:clients] || Lms.Clients.list_clients()
		Enum.each(
			clients,
			fn %{tenant: tenant} ->
			  Lms.Cacher.delete_cache_table_of_struct(%Lms.Regions.Region{}, tenant)
			  Lms.Clients.Detector.clear_regions_for_user(nil, tenant)
			end
		)
		
		recalculate_limits(clients)
	end
	
	def recalculate_limits(%Lms.Clients.Client{} = client)do
		Lms.Repo.put_tenant(client.tenant)
		Lms.Billing.UsageCache.clear_limits_for_client(client)
		Lms.Billing.UsageCache.clear_periods_cache(client)
		lms_resources_per_region = [:webinar, :video, :quiz, :course, :cms_page]
		Lms.Regions.list_records(prefix: client.tenant)
		|> Enum.each(
			   fn region ->
			     Enum.each(
				     lms_resources_per_region,
				     fn resource ->
					   Lms.Billing.LmsFeaturesUsage.update_limit_for_resource(
						   client,
						   resource,
						   :allowed_number,
						   region: region,
						   prefix: client.tenant
					   )
				     end
			     )
			   end
		   )
	end
	def recalculate_limits(clients) when is_list(clients) do
		clients
		|> Enum.each(
			   fn client ->
			     recalculate_limits(client)
			   end
		   )
	end
	
	
	def clear_on(nodes, opts \\ [])
	def clear_on(node, opts) when is_binary(node), do: clear_on(String.to_atom(node), opts)
	def clear_on(:cluster, opts), do: clear_on(nodes(opts), opts)
	def clear_on(nodes, opts) when is_list(nodes) do
		nodes
		|> Enum.each(
			   fn node ->
			     clear_on(node, opts)
			   end
		   )
	end
	def clear_on(node, opts) when is_atom(node) do
		Logger.warn("cache tasks clear_on node <#{node}>")
		task = Task.Supervisor.async(
			{Lms.RouterTasks, node},
			opts[:module] || Lms.Tasks.Cache,
			opts[:fun] || :clear_caches,
			opts[:args] || [opts]
		)
		Task.await(task)
	end
	
	def nodes(opts), do: opts[:nodes] || [node() | Node.list]
	
	
	# Fetch from Cachex
	def clear_for(source, opts \\ [])
	def clear_for(%{__meta__: %Metadata{source: source, prefix: prefix} = _metadata, id: id} = model, opts) do
		#IO.inspect clear
		default_opts = [module: Core.Cache, fun: :delete, args: [model, opts]]
		clear_on(opts[:on] || :cluster, Keyword.merge(default_opts, opts))
	end
	def clear_for(_, _), do: nil


end