defmodule Lms.Emails.Container do
  @doc """
  Defines the Lms.Emails.Container struct.

    * `:email` - Bamboo email structure
    * `:kind` - a type of email ("user_registration", "reminder" etc)
    * `:opts` - additional options to send emails
    * `:env` - environment variables (e.g. current tenant, region or client to detect email provider etc)
    * `:resource` - reference to resource that is a reason of sending (User/Webinar/Client)
    * `:template` - template used for sending (internal phoenix or dynamic for rendering mjml/handlebars templates)
    * `:email_module` - module for rendering emails (if not presented - use default e.g. BackOffice.EmailView or from config.exs)

  """
  defstruct [
    email: nil,
    kind: nil,
    opts: [],
    env: nil,
    resource: nil,
    template: nil,
    email_module: nil
  ]
end