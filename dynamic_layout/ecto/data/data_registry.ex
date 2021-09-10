defmodule DynamicLayout.Ecto.Data.Registry do
  # Data registry: available components
	
	def built_in() do
		[none: nil]
	end
	
	def from_config() do
		Application.get_env(:dynamic_layout, :data_components, [])
	end
	
	
	def components_for_scope(scope, _opts \\ []) do
		from_config()
		|> Enum.reduce(
			   %{},
			   fn
				   {title, module, allowed}, acc ->
					   cond do
						   Enum.member?(allowed, scope) -> Map.put(acc, title, module)
						   true -> acc
					   end
			   end
		   )
	end
	
	def components(opts \\ []) do
		
		list = built_in() ++ from_config()
		cond do
			opts[:selector] -> components_list(list)
			true -> list
		end
	end
	
	def component_name(kind) do
		case components(selector: true)
		     |> Enum.find(&(elem(&1, 1) == kind)) do
			{name, _} -> name
			_ -> nil
		end
	end
	
	def ecto_enum(opts \\ []) do
		Map.values(components_list(components(opts)))
	end
	
	def data_module(kind, opts \\ []) do
		Map.get(components_list(components(opts)), kind)
	end
	
	
	defp components_list(l) do
		Enum.reduce(l, %{}, &(Map.put(&2, elem(&1, 0), elem(&1, 1))))
	end
end