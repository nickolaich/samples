defmodule LmsJobs.ScheduledEmails do
  use GenServer
  alias Lms.Components.{ComponentReminders, Reminder}
  alias Lms.Regions
  alias Lms.Regions.Region
  alias Lms.Users.User
  require Logger
  alias BackOffice.Emails.Handler, as: EmailHandler

  def start_link(client) do
    GenServer.start_link(__MODULE__, %{client: client})
  end

  def init(state) do
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, state) do
    # do important stuff
    # Read here env variable if sending is turned on and if not -> write to log
    # Also, read here interval of checking reminders
    #state.client -> here is a client, read all scheduled emails for webinar, for example, and spawn async tasks to send them
    #Logger.critical("Reminder work")
    tenant = state.client.tenant
    Regions.list_records(active: true, prefix: state.client.tenant)
    |> Lms.Repo.preload(:settings)
    |> Enum.each(
         fn region ->
           # Read only reminders for components in active region
           Logger.info("check reminders for region #{region.id} at #{tenant}")
           ComponentReminders.get_reminders_to_send(:webinar, prefix: tenant, region: region)
           |> Enum.each(
                fn reminder ->
                  Logger.info("reminder ready to send #{reminder.id}")
                  ComponentReminders.change_status_to(reminder, :processing, prefix: tenant)
                  # Mark reminder as in progress
                  # For each reminder we need to read list of participants w/o reminder sent and sent email
                  # Read recipients only for this region
                  ComponentReminders.get_recipients(reminder, region: region, prefix: tenant)
                  |> Enum.each(
                       fn participant ->
                         send_webinar_reminder_to(region, reminder, participant)
                         # Send async
                       end
                     )
                  # Mark reminder as sent
                  ComponentReminders.change_status_to(reminder, :sent, prefix: tenant)
                end
              )
         end
       )

    # start same gen servers using supervisor per client and check periodically state.
    # each process will be configured with tenant
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work() do
    interval = Lms.Utils.Cast.to_integer(Application.get_env(:jobs, :reminders_interval, 0))
    #Logger.critical "interval is #{interval}"
    #interval = 5000
    if is_integer(interval) and (interval > 0) do
      Process.send_after(self(), :work, interval)
    else
      Logger.critical("Reminder interval isn't configured or disabled, sending reminders will not happen")
    end
  end

  def start_schedulers() do
    # 1 process per client to separate conflicts and improve speed of processing
    Lms.Clients.list_clients()
    |> Enum.each(&(DynamicSupervisor.start_child(LmsJobs.Emails.Supervisor, {__MODULE__, &1})))
  end

  def send_webinar_reminder_to(%Region{} = region, %Reminder{} = reminder, %User{} = participant) do
    Logger.info("send reminder #{reminder.id} to #{participant.id} <#{participant.email}> at region #{region.id}")
    webinar = reminder.component.webinar
    EmailHandler.build_and_send(
      webinar,
      :reminder,
      region,
      recipient: participant,
      assigns: [
        user: participant,
        webinar: webinar
      ],
      uid: reminder.id,
      template: reminder.content_template
      #now: true
    )
  end
end