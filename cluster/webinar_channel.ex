defmodule ClientWeb.WebinarChannel do
  use ClientWeb, :channel

  defdelegate user_full_name(a), to: Lms.Utils.Formatter.User
  defdelegate topic_between(a1, a2, s), to: Lms.Utils.PubSub

  alias ClientWeb.Presence
  alias Phoenix.PubSub

  require Logger

  def join("webinar:" <> wid, params, socket) do
    topic = PubSubUtils.topic(wid, "webinar")

    {
      :ok,
      %{channel: topic},
      socket
      |> set_tenant_to_socket_and_repo(socket.assigns.current_tenant)
      |> assign(:webinar_id, wid)
      |> fetch_webinar(wid)
      |> assign(:track_uid, Map.get(params, "track_uid", UUID.uuid1()))
      |> presence_tracking()
      |> register_access(:join)
    }
  end

  def presence_tracking(socket) do
    %{user: user, event_bus: bus} = socket.assigns
    PubSubUtils.presence_track(self(), user, bus)
    socket
  end


  def terminate(reason, socket) do
    %{user: user, event_bus: bus} = socket.assigns
    PubSubUtils.presence_untrack(self(), user, bus)
    socket
    |> register_access(:left)
    :ok
  end



  def register_access(socket, type) do
    %{webinar: webinar, user: user} = socket.assigns
    Lms.Components.ComponentEnrollment.action(type, webinar, user)
    socket
  end

  def fetch_webinar(socket, id) do
    # TODO: need a call to cacher to register currently active webinar to speed up process
    webinar = Lms.Webinars.get_one!(id)
              |> Lms.Webinars.preloads()
    assign(socket, :webinar, webinar)
    |> PubSubUtils.channel_buses(WebinarChannel, webinar)
  end

end