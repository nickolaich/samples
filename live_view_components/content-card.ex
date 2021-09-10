defmodule BackOffice.Components.ContentCard do
  use BackOffice, :live_component

  @moduledoc """
    Content card rendering.
    Sample of integration into eex-template (@tabs_container populate with helper function and contains structure:
       tabs: [TAB LIST From sample below],
           state: [
             current_tab: current,
             current_tab_info: current_tab_info,
             component: current_tab_info[:component] || nil,
             component_params: (opts[:component_params] || [])
                               |> Keyword.merge(current_tab_info[:component_params] || [])
                               |> Lms.Utils.append_id_if_need
           ]
    TODO1:: need to migrate to macros <%= content_card ... %>
    TODO2: warning: passing the @socket to live_component is no longer necessary, please remove the socket argument
    ```
    <%= live_component @socket, BackOffice.Components.ContentCard, id: "edit-webinar",
      card_title: @webinar.name,
      buttons: edit_webinar_buttons(@socket, @current_user, @webinar, @page, []),
      tabs: [
        container: @tabs_container,
        position: :right
      ]
    %>
    ```

    Sample of function that initialize tabs for content card (it's a sample, state could be optimized per tab)
    ```
       def webinar_edit_tabs(socket, current_user, webinar) do
          %{client: client, region: region, page: page, site: site} = socket.assigns
          params = [
            webinar: webinar,
            user: current_user,
            client: client,
            region: region,
            page: page,
            site: site
          ]
          c = webinar.component
          active = c.status == :active
          [
            get_tab_item(
              "live-dashboard",
              dgettext("webinars", "Live Dashboard"),
              BackOffice.WebinarLive.Dashboard,
              params,
              has_force_reload_to_live_dashboard() || active
            ),
            get_tab_item("details", dgettext("webinars", "Details"), BackOffice.WebinarLive.EditForm, params),
            get_tab_item(
              "connection",
              dgettext("webinars", "Connection"),
              BackOffice.WebinarLive.ConnectionDetails,
              params,
              !active
            ),
            get_tab_item("privacy", dgettext("webinars", "Privacy"), BackOffice.WebinarLive.Access, params),
            get_tab_item("room", dgettext("webinars", "Room"), BackOffice.WebinarLive.Room, params),
            get_tab_item("design", dgettext("webinars", "Design"), BackOffice.WebinarLive.Design, params),
            get_tab_item("reminders", dgettext("webinars", "Emails&Reminders"), BackOffice.WebinarLive.Reminders, params),
            get_tab_item("countdown", dgettext("webinars", "CountDown"), BackOffice.WebinarLive.CountDown, params),

            get_tab_item("speakers", dgettext("webinars", "Speakers"), BackOffice.WebinarLive.Speakers, params),
            get_tab_item("participants", dgettext("webinars", "Participants"), BackOffice.WebinarLive.Participants, params),
            get_tab_item("chat", dgettext("webinars", "Chat"), BackOffice.WebinarLive.Chat, params),
            get_tab_item("qa", dgettext("webinars", "QA"), BackOffice.WebinarLive.QA, params),
            get_tab_item("links", dgettext("webinars", "Calls To Actions"), BackOffice.WebinarLive.Links, params),
            get_tab_item("surveys", dgettext("webinars", "Surveys"), BackOffice.WebinarLive.Surveys, params),
            get_tab_item("agreements", dgettext("webinars", "Terms&Conditions"), BackOffice.AgreementsLive.AgreementsAtComponent, params ++ [component: c]),
            #get_tab_item("preview", dgettext("webinars", "Preview"), nil, [], true, [external_url: ClientRoutes.live_path(ClientWeb.Endpoint, ClientWeb.WebinarLive.Details, webinar)]),
          ]
        end
    ```

  """
  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    BackOffice.ComponentView.render("content-card.html", assigns)
  end


  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
      |> assign_computed()
      |> assign_content_renderer()
    }
  end


  defp assign_computed(socket) do
    a = socket.assigns
    socket
    |> assign(:wrapped, (Map.get(a, :wrap) == true) && is_list(Map.get(a, :header)))
    |> assign(:css, Map.get(a, :css, []))
    |> assign(:no_paddings, Map.get(a, :no_paddings, false))
    |> assign(:h_screen, Map.get(a, :h_screen, false))
    |> tabs_assigns


  end

  defp tabs_assigns(socket) do
    a = socket.assigns
    # it's has a container
    tab_info = Map.get(a, :tabs, [])
    container = Keyword.get(tab_info, :container, [])
    html_id = Keyword.get(tab_info, :id, UUID.uuid4())
    tabs = Keyword.get(container, :tabs, [])
    tabs_state = Keyword.get(container, :state, [])
    hide_if_single = Keyword.get(tab_info, :hide_tabs_if_single, false)
    show_tabs_nav = (hide_if_single && length(tabs) > 1) or (!hide_if_single && length(tabs) > 0)
    has_tabs = length(tabs) > 0
    tabs_pos = Keyword.get(tab_info, :position, :top_right)

    tabs_type = Keyword.get(tab_info, :type, :vertical)
    are_vertical = tabs_type == :vertical
    are_horizontal = tabs_type == :horizontal
    at_right = tabs_pos in [:top_right, :right]
    at_top = tabs_pos in [:top_right, :top]
    at_left = tabs_pos in [:top_left, :left]
    has_vertical_tabs = (are_vertical && has_tabs)
    socket
    |> assign(:has_tabs, has_tabs)
    |> assign(:show_tabs_nav, show_tabs_nav)
    |> assign(:has_vertical_tabs, has_vertical_tabs)
    |> assign(:tabs_position, tabs_pos)
    |> assign(:are_tabs_at_right, has_tabs and at_right)
    |> assign(:are_tabs_at_top, has_tabs and at_top)
    |> assign(:are_vertical_tabs_at_right, has_tabs and are_vertical and at_right)
    |> assign(:are_vertical_tabs_at_left, has_tabs and are_vertical and at_left)
    |> assign(:are_horizontal_tabs_at_top, are_horizontal and at_top)
    |> assign(
         :content_width,
         (cond do
            show_tabs_nav == false -> "w-full lg:w-full"
            has_vertical_tabs == true -> "w-full lg:w-10/12"
            true -> "w-full lg:w-full"
          end)
       )
    |> assign(:tabs_content_width, (if has_vertical_tabs == true, do: "w-full lg:w-2/12", else: "w-full lg:w-full"))
    |> assign(
         :tab_opts,
         [
           id: html_id,
           tabs: tabs,
           type: tabs_type,
           state: tabs_state
         ]
       )
    |> assign(
         :mobile_tab_opts,
         [
           id: Keyword.get(tab_info, :mobile_id, UUID.uuid4()),
           tabs: tabs,
           type: :vertical,
           state: tabs_state,
           mobile: true
         ]
       )

  end

  def assign_content_renderer(socket) do
    a = socket.assigns
    socket
    |> assign(:current_tab_component_to_render, get_tab_component_to_render(a))
    |> assign(
         :current_tab_component_params_to_render,
         get_tab_component_params_to_render(a)
         |> (fn x -> if x[:id], do: x, else: Keyword.put(x, :id, UUID.uuid4()) end).()
       )
  end



end
