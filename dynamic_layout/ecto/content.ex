defmodule DynamicLayout.Ecto.Content do
  use DynamicLayout.Ecto.Service
  alias DynamicLayout.Ecto.Storage
  import Ecto.Query


  def list_records(kind, filters \\ %{}, opts \\ [])
  def list_records(:page, filters, opts) do
    Storage.get_pages(filters, opts)
  end




  def count_records(kind, filters \\ %{}, opts \\ [])
  def count_records(:page, filters, opts) do
    Storage.count_pages(filters, opts)
  end

end