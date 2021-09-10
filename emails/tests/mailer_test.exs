defmodule Lms.Emails.MailerTest do
  use Lms.Case
  use Bamboo.Test
  alias Lms.Factories.{ClientFactory}


  setup %{tenant: _tenant} do
    region = ClientFactory.create_region()
    ClientFactory.setup_test_mailer(region)
  end

  test " test build only ", %{region: region} do
    {:built, email} = Lms.Emails.TestEmails.custom("user@email.com", subject: "Subj")
                      |> Lms.Mailer.deliver_in(region, nil, build_only: true)
    refute_delivered_email email
  end


  test " test sending in not configured region " do
    region = ClientFactory.create_region()
    # we will have empty config
    assert %{} == Lms.Mailer.build_email_config(region)
    {:error, _} = Lms.Emails.TestEmails.custom("user@email.com", subject: "Subj")
                  |> Lms.Mailer.deliver_in(region, nil, now: true, kind: :some_email)
  end


end