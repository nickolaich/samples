defmodule BackOffice.Emails.WebinarEmails do
  @moduledoc false
  use Bamboo.Phoenix, view: BackOffice.Email.WebinarView
  import Lms.Emails.Builder

  alias Lms.Users.User
  alias Lms.Webinars.Webinar


  def build(%User{} = u, %Webinar{} = w, kind, opts) do
    new_email(
      to: {Lms.Utils.Formatter.User.user_full_name(u), u.email}
    )
    |> container(__MODULE__, kind, u, opts |> Keyword.put(:resource, w))
  end



end