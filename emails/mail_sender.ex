defmodule Lms.Emails.MailSender do
  @moduledoc """
    Wrapper for sending emails. Right now implements Bamboo.Mailer, but as entry point for any emails could be modified.
    TODO:: need to add some kind of behaviour for required methods
  """
  use Bamboo.Mailer, otp_app: :lms_core



end