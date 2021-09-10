defmodule DynamicLayout.Node do
  @derive Jason.Encoder
  defstruct [
    :uid,
    :name,
    :dom,
    :data,
    :children,
    :property_module,
    :requirements,
    :position
  ]

  alias DynamicLayout.Node.{Dom, Data}

  def create(opts \\ []) do
    %__MODULE__{
      uid: opts[:uid] || UUID.uuid4(),
      name: opts[:name],
      dom: Dom.create(opts),
      data: opts[:data],
      children: opts[:children] || [],
      property_module: opts[:property_module],
      requirements: opts[:requirements] || [],
      position: opts[:position]
    }
  end

  def put_dom(%__MODULE__{} = n, %Dom{} = d), do: Map.put(n, :dom, d)
  def put_data(%__MODULE__{} = n, %Data{} = d), do: Map.put(n, :data, d)
  def put_children(%__MODULE__{} = n, children) when is_list(children), do: Map.put(n, :children, children)
  def clear_data(%__MODULE__{} = n), do: Map.put(n, :data, nil)
  def put_position(%__MODULE__{} = n, pos), do: Map.put(n, :position, pos)
  def put_name(%__MODULE__{} = n, name), do: Map.put(n, :name, name)
  def put_requirements(%__MODULE__{} = n, requirements) when is_list(requirements),
      do: Map.put(n, :requirements, requirements)

end