defmodule DynamicLayout.Ecto.Installer do
  alias DynamicLayout.Ecto.Storage
  alias DynamicLayout.Ecto.{Block, Layout, Page}


  def install_public_to_tenant(src, tenant, opts \\ [])
  def install_public_to_tenant(%Layout{} = l, tenant, opts) do
    case Storage.get_layouts(%{shared_id: l.id}, prefix: tenant) do
      [] ->
        Storage.create_layout(%{name: l.name, shared_id: l.id}, prefix: tenant)
      layouts -> layouts
    end
  end

end