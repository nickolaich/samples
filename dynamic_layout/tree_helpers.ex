defmodule DynamicLayout.TreeHelpers do

  @docmodule """
    Help module to work with trees. Could be improved, but enough for quick PoC.
  """

  def has_path?(tree, path, opts \\ []), do: !is_nil(fetch(tree, path, opts))

  def fetch(tree, path, opts \\ [])
  def fetch(tree, path, opts) when is_map(tree), do: fetch(Map.get(tree, opts[:list_key] || :properties), path, opts)
  def fetch(tree, path, opts) do
    cond do
      is_nil(tree) -> nil
      path == [] -> nil
      true -> case path do
                [k | []] -> Keyword.get(tree, k)
                [k | tail] -> fetch(Keyword.get(tree, k), tail, opts)
              end
    end
  end

  def find(tree, val, opts \\ [])
  def find(tree, val, opts) do
    list_key = opts[:list_key] || :children
    lookup_key = opts[:lookup_key] || :uid
    cond do
      is_map(tree) and lookup_value(tree, lookup_key, opts) === val -> tree
      is_map(tree) -> find(Map.get(tree, list_key), val, opts)
      true -> case tree do
                [] -> nil
                [node | tail] ->
                  if lookup_value(node, lookup_key, opts) === val do
                    node
                  else
                    case find(Map.get(node, list_key), val, opts) do
                      nil -> find(tail, val, opts)
                      v -> v
                    end
                  end
              end
    end
  end

  defp lookup_value(tree, key, opts) do
    cond do
      (opts[:to_string] === true) && is_atom(Map.get(tree, key)) -> Atom.to_string(Map.get(tree, key))
      true -> Map.get(tree, key)
    end
  end

  def update(tree, key, fun, acc \\ [], opts \\ [])
  def update(tree, key, fun, acc, opts) when is_map(tree) do
    lookup_key = opts[:lookup_key] || :uid
    list_key = opts[:list_key] || :children
    if Map.get(tree, lookup_key) === key do
      fun.(tree)
    else
      Map.put(tree, list_key, update(Map.get(tree, list_key), key, fun, acc, opts))
    end

  end

  def update(children, key, fun, acc, opts) when is_list(children) do
    list_key = opts[:list_key] || :children
    lookup_key = opts[:lookup_key] || :uid
    case children do
      [] ->
        acc
      [node | tail] ->
        update(tail, key, fun, acc ++ [update(node, key, fun, [], opts)], opts)
    end
  end


  def merge(dest, inject, acc \\ [], current \\ nil, opts \\ [])
  def merge(dest, inject, acc, current, opts) when is_list(dest) do
    %{properties: dest}
    |> merge(inject, acc, current, opts)
    |> Map.get(:properties)
  end
  def merge(dest, inject, acc, current, opts) do
    prop_key = opts[:list_key] || :properties
    case  Map.get(inject, prop_key) do
      [] ->
        cond do
          acc == [] -> dest
          !has_path?(dest, acc, opts) ->
            replace(dest, acc, current, opts)
          true -> dest
        end
      [{key, childs} | tail] ->
        merge(merge(dest, childs, acc ++ [key], childs, opts), Map.put(inject, prop_key, tail), acc, inject, opts)
    end
  end

  defp fetch_props(acc, k) do
    cond do
      is_map(acc) -> Map.get(acc, k)
      is_list(acc) -> Keyword.get(acc, k)
      true -> raise("invalid acc for fetching property")
    end
  end

  def replace(acc, key_path, value, opts \\ []) do
    props_key = opts[:props_key] || :properties
    case key_path do
      [k | []] ->
        Map.put(
          acc,
          props_key,
          Keyword.put(fetch_props(acc, props_key), k, value)
        )
      [k | tail] ->
        childs = get_list_from_acc(acc, props_key)
        if childs[k] do
          Map.put(
            acc,
            props_key,
            Keyword.put(childs, k, replace(childs[k], tail, value, opts))
          )
        else
          if opts[:strict] do
            raise "invalid tree path to replace value. turn of :strict to ignore this option"
          else
            acc
          end
        end
    end
  end


  def delete(tree, key, fun, acc \\ [], opts \\ [])
  def delete(tree, key, fun, acc, opts) when is_map(tree) do
    lookup_key = opts[:lookup_key] || :uid
    list_key = opts[:list_key] || :children
    if Map.get(tree, lookup_key) === key do
      if is_function(fun, 3) do
        fun.(tree, key, opts)
      end
      %{}
    else
      Map.put(tree, list_key, delete(Map.get(tree, list_key), key, fun, acc, opts))
    end
  end

  def delete(children, key, fun, acc, opts) when is_list(children) do
    list_key = opts[:list_key] || :children
    lookup_key = opts[:lookup_key] || :uid
    Enum.reduce(
      children,
      [],
      fn node, acc ->
        if Map.get(node, lookup_key) === key do
          if is_function(fun, 3) do
            fun.(node, key, opts)
          end
          acc
        else
          acc ++ [delete(node, key, fun, acc, opts)]
        end
      end
    )
  end


  def collect(tree, acc \\ [], opts \\ [])
  def collect(tree, acc, opts) when is_map(tree) do
    lookup_key = opts[:lookup_key] || :uid
    list_key = opts[:list_key] || :children
    flatten = Keyword.get(opts, :flatten, false)
    val = Map.get(tree, lookup_key)
    acc ++ (cond do
              !is_nil(val) && (!flatten || !is_list(val)) -> [val]
              !is_nil(val) && flatten && is_list(val) -> val
              true -> []
            end)
    ++ collect(Map.get(tree, list_key), [], opts)
  end
  def collect(children, acc, opts) when is_list(children) do
    list_key = opts[:list_key] || :children
    lookup_key = opts[:lookup_key] || :uid
    case children do
      [] ->
        acc
      [node | tail] ->
        collect(tail, acc ++ collect(node, [], opts), opts)
    end
  end

  defp get_list_from_acc(acc, props_key) do
    cond do
      is_list(acc) -> acc[props_key]
      is_map(acc) -> Map.get(acc, props_key)
      true -> raise "invalid accumulator to fetch children from (must implement access behaviour)"
    end
  end
end