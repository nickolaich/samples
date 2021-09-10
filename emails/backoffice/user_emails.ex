defmodule BackOffice.Emails.UserEmails do
  @moduledoc false
  use Bamboo.Phoenix, view: BackOffice.EmailView
  import Lms.Emails.Builder

  alias Lms.Users.User

  def build(%User{} = u, kind, opts) do
    new_email(
      to: {Lms.Utils.Formatter.User.full_name(u), u.email},
      subject: "New Password"
    )
    |> container(__MODULE__, kind, u, opts)
  end



end