defmodule DynamicLayout.Ecto.Service do


  import Ecto.Query
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import DynamicLayout.Ecto.Service
    end
  end

  #def model_class(), do: Webinar

  def tenant(), do: Application.get_env(:dynamic_layout_ecto, :tenant)

  def get_tenant_from_model(%{__meta__: _} = m), do: Ecto.get_meta(m, :prefix)

  def repo(opts \\ []), do: Keyword.get(opts, :repo, Application.get_env(:dynamic_layout_ecto, :repo))


  def insert_to_tenant(changeset, opts \\ []), do:
    repo(opts).insert(changeset, repo_opts(opts, prefix: tenant()))
  def insert_to_tenant!(changeset, opts \\ []), do:
    repo(opts).insert!(changeset, repo_opts(opts, prefix: tenant()))


  def update_at_tenant(changeset, opts \\ []), do: repo(opts).update(changeset, repo_opts(opts, prefix: tenant()))
  def update_at_tenant!(changeset, opts \\ []), do: repo(opts).update!(changeset, repo_opts(opts, prefix: tenant()))

  def update_all_at_tenant(changeset, opts \\ []), do: repo(opts).update_all(changeset, repo_opts(opts, prefix: tenant()))



  #def delete_from_tenant(record, opts \\ [])
  def delete_from_tenant(record, opts \\ []), do: repo(opts).delete(record, repo_opts(opts, prefix: tenant()))
  def delete_from_tenant!(record, opts \\ []), do: repo(opts).delete!(record, repo_opts(opts, prefix: tenant()))


  def delete_all_from_tenant(q, opts \\ []), do: repo(opts).delete_all(q, repo_opts(opts, prefix: tenant()))



  def query_by_fields(model_class, filters, opts \\ []) do
    query = (from m in model_class)
            |> (fn q ->
      if opts[:count] == true do
        select(q, [m], count(m.id, :distinct))
      else
        q
      end
                end).()
    Enum.reduce(
      filters,
      query,
      fn attr, query ->
        field = elem(attr, 0)
        value = elem(attr, 1)
        cond do
          is_list(value) -> where(query, [m], field(m, ^field) in ^value)
          is_nil(value) -> where(query, [m], is_nil(field(m, ^field)))
          is_function(value, 1) -> value.(query)
          true -> where(query, [m], field(m, ^field) == ^value)
        end

      end
    )
  end

  def find_by_filters(model_class, fields, opts \\ []) do
    repo(opts).one(query_by_fields(model_class, fields, opts), opts)
  end
  def find_all_by_filters(model_class, fields, opts \\ []) do
    repo(opts).all(query_by_fields(model_class, fields, opts), opts)
  end
  def count_all_by_filters(model_class, fields, opts \\ []) do
    repo(opts).one(query_by_fields(model_class, fields, Keyword.put(opts, :count, true)), opts)
  end
  def has_by_filters?(model_class, fields, opts \\ []) do
    repo(opts).exists?(query_by_fields(model_class, fields, opts), opts)
  end

  def preloads(source, preloads_list, opts) do
    source
    |> repo(opts).preload(preloads_list, opts)
  end


  def repo_opts(opts, base_opts \\ [])
  def repo_opts(opts, base_opts) when is_map(opts), do: repo_opts(Map.to_list(opts), base_opts)
  def repo_opts(opts, base_opts) when is_list(opts), do: Keyword.merge(base_opts, opts)
  def repo_opts(_, base_opts), do: base_opts

end
