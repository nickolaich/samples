defmodule Lms.Emails.TestEmails do
  @moduledoc false
  import Bamboo.Email


  def custom(to, opts \\ []) do
    new_email(
      to: to,
      from: opts[:from],
      subject: opts[:subject],
      html_body: opts[:html],
      text_body: opts[:text]
    )
  end

end