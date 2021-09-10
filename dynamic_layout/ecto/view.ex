defmodule DynamicLayout.Ecto.View do
  alias DynamicLayout.Ecto.{Storage, Reader, Block, Layout, Page}
  alias DynamicLayout.View, as: DynamicLayoutView

  def render(source, opts \\ []) do
    # TODO:: here we can cache ecto structure (not a content!)
    # So, we will not build trees using Reader.ecto_to_dom(source, opts) on the fly
    # But we will use trees from memory to render HTML with dynamic DATA in it.
    # If we will find child -> it will call this again
    # Collect inherit id's to prevent circular dependencies???
    subs = Map.merge(Map.get(source, :substitutions, %{}) || %{}, Keyword.get(opts, :substitutions, %{}))
    opts = Keyword.put(opts, :substitutions, subs)
           |> Keyword.put(:data_block_provider, ContentEditorWeb.DataProvider.Block)

    phx_layout = get_phx_layout(source, opts)

    ecto_opts = (cond do
                   is_nil(opts[:prefix]) -> Keyword.put(opts, :skip_tenant, true)
                   true -> opts
                 end)

    content = Reader.ecto_to_dom(source, ecto_opts)
              |> DynamicLayoutView.render(opts)

    if !is_nil(phx_layout) do
      opts[:phoenix_view].render(phx_layout.view_module, phx_layout.view_template, [inner_content: content] ++ opts)
    else
      content
    end

  end

  defp get_phx_layout(source, opts) do
    phx_layout = Reader.get_phx_layout(source, opts)
    cond do
      is_map(phx_layout) && is_binary(Map.get(phx_layout, "view")) && Code.ensure_loaded?(
        String.to_atom(Map.get(phx_layout, "view"))
      )
      -> %{view_module: String.to_atom(Map.get(phx_layout, "view")), view_template: Map.get(phx_layout, "template")}
      true -> nil
    end
  end
end