defmodule BackOffice.Emails.Handler do
  @docmodule """
    It's email handler helper: allows quickly build and send emails.
    Example:
      ```
        EmailHandler.build_and_send(
            webinar,
            :enrollment_approved,
            region,
            recipient: user,
            assigns: [
              user: user,
              webinar: webinar
            ]
          )
      ```
  """
  alias Lms.{Emails, Mailer}
  alias Lms.Users.User
  alias Lms.Webinars.Webinar
  alias Lms.Courses.Course
  alias Lms.Conferences.Conference
  alias BackOffice.Emails.{UserEmails, WebinarEmails, ConferenceEmails}
  alias Lms.Emails.Container, as: EmailContainer
  alias Lms.Emails.Builder, as: EmailBuilder


  @doc """
    Build Lms.Emails.Container struct.
    Based on recipient_or_target we use mailer module to generate email.
    # TODO:: need to resolve BackOffice. ClientWeb has it's own Email.Handler that wraps email creation
  """
  def build(recipient_or_target, kind, region_or_client, opts \\ [])
  def build(%User{} = recipient, kind, region_or_client, opts) do
    UserEmails.build(
      recipient,
      kind,
      opts
      |> Keyword.merge(EmailBuilder.env_opts(region_or_client))
    )
  end

  def build(%Webinar{} = webinar, kind, region_or_client, opts) do
    WebinarEmails.build(
      opts[:recipient],
      webinar,
      kind,
      opts #|> Keyword.put(:resource, webinar)
      |> Keyword.merge(EmailBuilder.env_opts(region_or_client))
    )
  end

  @doc """
    Wrapper for building and immidately sending email
  """
  def build_and_send(recipient, kind, region_or_client, opts \\ []) do
    build(recipient, kind, region_or_client, opts)
    |> Lms.Emails.Builder.render_if_need()
    |> send()
  end


  @doc """
    Wrapper to LmsCore Mailer. Could be modified any time per client/region
  """
  def send(%EmailContainer{} = container) do
    Mailer.deliver(container)
  end




end