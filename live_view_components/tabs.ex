defmodule BackOffice.Components.Tabs do
  use BackOffice, :live_component

  @moduledoc """
    Tabs rendering component
  """

  def render(assigns) do
    BackOffice.ComponentView.render("tabs.html", assigns)
  end


  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
    }
  end


end
