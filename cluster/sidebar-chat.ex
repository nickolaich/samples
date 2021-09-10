defmodule ClientWeb.ChatLive.SidebarChat do
  use ClientWeb, :live_component


  alias Lms.Chats.ChatActions
  alias Lms.Chats.ChatReader
  alias Lms.Chats

  def render(assigns) do
    ClientWeb.ChatView.render("sidebar-chat.html", assigns)
  end

  def mount(socket) do
    {
      :ok,
      socket
      |> assign(:messages, [])
      |> assign(:chat_message_changeset, Chats.ChatMessage.changeset(%Chats.ChatMessage{}, %{}))
    }
  end

  def update(
        %{
          payload: %{
            message: _message
          } = payload
        } = assigns,
        socket
      ) do
    prepared = ChatReader.prepare_message(%{payload: payload})
    %{webinar: webinar} = socket.assigns
    chat = Lms.Webinars.Webinar.get_chat(webinar)
    {
      :ok,
      socket
      |> assign(
           :messages,
           ChatReader.append_message(socket.assigns.messages, prepared)
         )
      |> notify_parent()
      |> push_event(
           "new-message",
           %{
             message: prepared,
             options: %{
               sound: (if !is_nil(chat) && !is_nil(chat.sound), do: Routes.static_path(socket, chat.sound), else: nil)
             }
           }
         )
    }
  end

  def update(%{webinar: webinar, user: user} = assigns, socket) do

    {
      :ok,
      socket
      |> assign(user: user)
      |> assign(webinar: webinar)
      |> assign(is_on: Lms.Webinars.Webinar.is_chat_available(webinar))
      |> (fn socket ->
        if Map.has_key?(assigns, :payload), do: socket, else: fetch(socket)
          end).()
    }
  end

  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)

    }
  end

  #message_list
  def fetch(socket) do
    chat = Chats.get_default_component_chat(socket.assigns.webinar)
    socket
    |> assign(
         :messages,
         ChatReader.fetch_and_group(chat)
       )
    |> assign(:chat, chat)
    |> notify_parent()
  end


  def handle_event(
        "type_message",
        %{
          "chat_message" => m
        },
        socket
      ) do

    {
      :noreply,
      socket
      |> assign(:chat_message_changeset, Chats.ChatMessage.changeset(%Chats.ChatMessage{}, m))

    }
  end


  def handle_event(
        "message",
        %{
          "chat_message" => %{
            "message" => message
          }
        },
        socket
      ) do
    a = socket.assigns
    chat = a.chat
    user = get_logged_user(socket)
    _participant = ChatActions.join(chat, user)
    case ChatActions.message(chat, user, message) do
      {:ok, m} ->
        prepared = ChatReader.prepare_message(
          m
          |> Lms.Repo.preload(chat_participant: [:user])
        )
        #ClientWeb.Endpoint.broadcast_from(self(), topic(socket.assigns.webinar), "message", prepared)
        send self(), {:broadcast, %{kind: :chat_message, payload: prepared}}
        {
          :noreply,
          socket
          |> assign(:chat_message_changeset, Chats.ChatMessage.changeset(%Chats.ChatMessage{}, %{}))
        }
      _ -> {:noreply, socket}
    end

  end

  defp notify_parent(socket) do
    send self(), {:active_tab_info, %{tab: :chat, bindings: ChatReader.stats(%{groups: socket.assigns.messages})}}
    socket
  end
end