defmodule Lms.Mailer do
  @docmodule """
    Mailer to delivery emails for users.
    Environment is a %Region structure to populate config and fetch default settings from, it could be also a %Client
    if tenant has shared config for all regions/dealers
    Resource is an custom sending: webinar/course/user etc. We can populate some specific settings or fetch recipient
  """
  alias Lms.Clients.Client
  alias Lms.Regions.Region
  alias Lms.Emails.EmailLog
  alias Lms.Emails.Container



  @doc """
    Function to delivery email at specific Client/Region environment
  """
  def deliver_in(email, environment, resource \\ nil, opts \\ [])
  def deliver_in(email, client_or_region, resource, opts) do
    # TODO:: need checking if limit of sending reached and return in response
    opts = prepare_opts(email, client_or_region, resource, opts)
    case build_email_config(client_or_region, opts) do
      %{adapter: :none} = config -> {:error, :not_configured_email_adapter}
      %{adapter: _} = config -> email
                                |> apply_settings_from(client_or_region)
                                |> apply_settings_from(resource)
                                |> apply_settings_from(opts)
                                |> deliver(config, opts)
                                |> log_sending(opts)
      _ -> {:error, :not_configured_client_or_region}
    end
  end



  # wrapper using email container object
  def deliver(%Container{} = c) do
    deliver_in(c.email, c.env, c.resource, c.opts)
  end

  # Deliver email
  def deliver(email, config, opts) do
    cond do
      opts[:build_only] == true -> email
      opts[:now] == true ->
        Lms.Emails.MailSender.deliver_now(email, config: config)
      true ->
        Lms.Emails.MailSender.deliver_later(email, config: config)
    end
  end

  @doc """
    Log sending emails if need
  """
  def log_sending(sent, opts) do
    case sent do
      %Bamboo.Email{} = email ->
        # Built only called (to create Bamboo.Email instance, usefull for testing) and we don't log it.
        {:built, email}
      {:ok, _email} = res ->
        # Record sending to log
        EmailLog.log_record(
          opts[:env],
          opts[:user],
          opts[:kind],
          resource_id: opts[:resource_id],
          async: true,
          prefix: opts[:prefix],
          period: Lms.Billing.find_or_create(opts[:env], nil),
          async_handler: fn t ->
            #IO.inspect "ASYNC HANDLER"
          end
        )
        # Inc usage in features limit storage
        Lms.Utils.Features.inc_mail_usage(opts[:env], opts[:usage_opts] || [])
        res
      _ -> sent
    end
  end



  @doc """
    Build email configuration based on client or region
    TODO:: client for now isn't supported (there is no shared client's config management tool, room for improvement)
    For region we read dynamic configuration. For now we support SendGrid and SmtpAdapters only.
  """
  def build_email_config(source_of_configuration, _opts \\ [])
  def build_email_config(%Client{} = _client, _opts) do
    #%{adapter: Bamboo.SendGridAdapter, api_key: client.get_provider().api_key}
    %{}
  end
  def build_email_config(%Region{} = region, _opts) do
    case Lms.Regions.get_provider(region, :mail) do
      %Lms.ServiceProvider{} = p ->
        base = %{adapter: p.api_handler}
        case p.api_handler do
          Bamboo.SendGridAdapter ->
            base
            |> Map.put(:api_key, p.settings.credentials.token.token)
          Bamboo.SMTPAdapter ->
            conf = p.settings.configuration.smtp
            cred = p.settings.credentials.user_password
            base
            |> Map.put(:server, conf.host)
            |> Map.put(:port, conf.port)
            |> Map.put(:username, cred.username)
            |> Map.put(:password, cred.password)
          _ ->
            base
        end
      _ -> %{}
    end

  end

  # Apply from region
  defp apply_settings_from(%Bamboo.Email{} = email, %Region{} = region) do
    # need something  in  region settings
    from = {region.settings.general.mail_from_name, region.settings.general.mail_from_address}
    Map.put(email, :from, from)
  end
  # From options
  defp apply_settings_from(%Bamboo.Email{} = email, opts) when is_list(opts) do
    email
  end
  # Use pattern matching or protocol???
  # Probably we will have custom from/headers per webinar/course
  defp apply_settings_from(%Bamboo.Email{} = email, _), do: email

  defp prepare_opts(_email, client_or_region, resource, opts) do
    opts
    |> Keyword.put(:env, client_or_region)
    |> Keyword.put(:resource_id, (if is_map(resource), do: Map.get(resource, :id), else: nil))
  end
end