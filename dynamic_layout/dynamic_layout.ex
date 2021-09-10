defmodule DynamicLayout do
  @moduledoc """
  Documentation for `DynamicLayout`.
  """

  def property do
    quote do
      alias DynamicLayout.Property
      defdelegate put_properties(container, props), to: DynamicLayout.Property
      defdelegate variant_prefix(opts), to: DynamicLayout.Property
    end
  end

  def builder do
    quote do
      import DynamicLayout

      def property(k, opts) when is_atom(k) do
        module = Atom.to_string(k)
                 |> String.split(".")
                 |> Enum.map(&String.capitalize/1)
                 |> Enum.join(".")
                 |> (fn str -> "#{__MODULE__}.#{str}" end).()
                 |> String.to_atom()

        attr = Keyword.get(
          opts,
          :attr,
          (
            if Code.ensure_loaded?(module) and Kernel.function_exported?(module, :dom_attribute, 1),
               do: apply(module, :dom_attribute, [opts]), else: nil)
        )
        #attr: :l0
        property_build(
          k,
          # force rewrite module
          [
            module: module,
            attr: attr
          ],
          # opts are going to be as a default
          opts
        )
      end

      defoverridable property: 2
    end
  end


  def data_component do
    quote do
      def notify_parent(socket, data) do
        %{parent: parent, parent_id: pid} = socket.assigns
        Phoenix.LiveView.send_update parent, id: pid, configuration: data
        socket
      end

      def notify_parent_changes(socket, data) do
        %{parent: parent, parent_id: pid} = socket.assigns
        Phoenix.LiveView.send_update parent, id: pid, configuration_changes: data
        socket
      end


      def fetch_node_data_from_assigns(assigns) do
        case Map.get(assigns, :data, %{}) do
          %DynamicLayout.Node.Data{configuration: config} -> config
          data when is_map(data) -> data
          _ -> %{}
        end
      end

      unquote(view_helpers())

    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML
    end
  end

  def property_build(k, opts, default_opts) do
    DynamicLayout.Property.build(
      k,
      Keyword.merge(default_opts, opts)
      |> (fn o -> Keyword.put(o, :module, Keyword.get(o, :module, __MODULE__)) end).()
    )
  end


  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end


