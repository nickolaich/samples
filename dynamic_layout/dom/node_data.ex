defmodule DynamicLayout.Node.Data do
  #@derive Jason.Encoder
  defstruct [
    :kind,
    :configuration,
    :version
  ]


  def create(opts \\ []) do
    %__MODULE__{
      kind: view_module(opts),
      version: Keyword.get(opts, :version, 1)
    }
    |> put_view_configuration(opts)
  end

  def view_module(opts) when is_list(opts), do: view_module(opts[:kind])
  #def box_render(nil), do: :div
  # TODO:: ensure view module loaded??? or impl protocol???
  def view_module(view) when is_atom(view), do: view


  def put_view_configuration(%__MODULE__{} = d, opts), do: Map.put(d, :configuration, opts[:configuration])


end

#defimpl Jason.Encoder, for: [DynamicLayout.Node.Data] do
#  def encode(struct, opts) do
#    Jason.Encode.map(struct, opts)
#  end
#end