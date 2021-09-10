defmodule Lms.Emails.MailerConfigTest do
  use Lms.Case

  alias Lms.Factories.{ClientFactory}
  alias Lms.SystemProviders

  setup %{} do

    region = ClientFactory.create_region()

    %{region: region}
  end

  test " building configuration", %{region: region, tenant: tenant} do
    system_provider = SystemProviders.create_provider!(
      %{
        name: "M1",
        key: "m1",
        shared_configuration: true,
        type: :mail,
        api_handler: Elixir.Bamboo.TestAdapter,
        settings: %{
          type: "mail"
        }
      }
    )
    {:ok, provider} = Lms.Providers.activate(system_provider, [tenant: tenant])
    {:ok, %Lms.Regions.Region{} = r} = Lms.Regions.update!(
      region,
      %{
        settings: %{
          general: %{
            mail_provider_id: provider.id,
          }
        }
      }
    )
    %{adapter: Bamboo.TestAdapter} = Lms.Mailer.build_email_config(r)

    # Activate and select another provider
    system_provider = SystemProviders.create_provider!(
      %{
        name: "M2",
        key: "m2",
        shared_configuration: true,
        type: :mail,
        api_handler: Elixir.Bamboo.LocalAdapter,
        settings: %{
          type: "mail"
        }
      }
    )
    {:ok, provider} = Lms.Providers.activate(system_provider, [tenant: tenant])
    {:ok, %Lms.Regions.Region{} = r} = Lms.Regions.update!(
      region,
      %{
        settings: %{
          general: %{
            mail_provider_id: provider.id,
          }
        }
      }
    )

    %{adapter: Bamboo.LocalAdapter} = Lms.Mailer.build_email_config(r)
  end

  test " sendgrid configuration ", %{region: region, tenant: tenant} do
    system_provider = SystemProviders.create_provider!(
      %{
        name: "M1",
        key: "m1",
        shared_configuration: true,
        type: :mail,
        api_handler: Elixir.Bamboo.SendGridAdapter,
        credential_type: :token,
        settings: %{
          type: "mail"
        }
      }
    )
    {:ok, provider} = Lms.Providers.activate(
      system_provider,
      [
        tenant: tenant,
        credentials: %{
          token: "some-sendgrid-api-key"
        }
      ]
    )
    {:ok, %Lms.Regions.Region{} = r} = Lms.Regions.update!(
      region,
      %{
        settings: %{
          general: %{
            mail_provider_id: provider.id,
          }
        }
      }
    )

    %{adapter: Bamboo.SendGridAdapter, api_key: "some-sendgrid-api-key"} = Lms.Mailer.build_email_config(r)
  end

end