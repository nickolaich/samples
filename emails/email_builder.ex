defmodule Lms.Emails.Builder do
  alias Lms.Emails.Container, as: EmailContainer
  require Logger

  @doc """
  	Build a container to use it for sending emails later.
    Container is a wrapper of options for parsing/rendering (different engines) and
    sending (different sending providers: sendgrid/mailchimp)
  """
  def container(bamboo_email, email_module, kind, recipient, opts) do
    resource = opts[:resource]
    %EmailContainer{
      email: bamboo_email,
      email_module: email_module,
      kind: kind,
      opts: merge_options(
        default_options(email_module),
        Keyword.drop(opts, [:resource, :env])
        |> Keyword.put(:kind, kind)
          # for logging
        |> Keyword.put(:user, recipient)
      ),
      env: opts[:env],
      resource: resource,
      template: opts[:template] || kind
    }
    |> apply_settings()
  end

  def env_opts(region_or_client) do
    [env: region_or_client, prefix: Lms.Utils.Tenant.get_tenant_from_model(region_or_client)]
  end


  defp merge_options(defaults, opts) do
    Keyword.merge(defaults, opts)
  end

  defp default_options(email_module) do
    # Test for phoenix if function on mail handler exported
    # there is something like that use Bamboo.Phoenix, view: BackOffice.EmailView
    [phoenix: function_exported?(email_module, :render, 3), layout: :email]
  end

  defp apply_settings(%EmailContainer{} = c) do
    is_phoenix = Keyword.get(c.opts, :phoenix, false)
    email = Enum.reduce(
      c.opts,
      c.email,
      fn {option, value}, acc ->
        cond do
          (option == :layout) and is_phoenix ->
            Bamboo.Phoenix.put_layout(acc, {Keyword.get(c.opts, :layout_view, BackOffice.LayoutView), value})
          true -> acc
        end
      end
    )
    Map.put(c, :email, email)
  end

  @doc """
    Render container if needs. It analyse :template variable from container's struct.
    %{key: key, region: region} - attempts to fetch a default template from "content_templates" table.
          (there is special module to create dynamic templates based on MJML and handlebars)


    Cms.ContentBuilder is responsible for parsing dynamic templates (mjml) and replacing handlebars tags from bindings.
    By default phoenix templates used. The name prepared is the same as "kind". For "user-registered" in template we will
    try to find and render "user-registered.html.eex" and "user-registered.txt.eex" for text version
  """
  def render_if_need(%EmailContainer{} = c) do
    # TODO:: change to cond and add support of %Cms.ContentTemplate{} as template and render it
    case c.template do
      %{key: key, region: region} ->
        # detect default template
        case Cms.ContentTemplates.get_default(key, region, prefix: Ecto.get_meta(region, :prefix)) do
          %Cms.ContentTemplate{} = t ->
            Map.put(c, :template, t)
            |> render_if_need()
          _ ->
            # set kind to default to send default email if exists
            Map.put(c, :template, c.kind)
            |> render_if_need()
        end
      %Cms.ContentTemplate{} = t ->
        # Transfer assigns from opts to email and drop them
        {bindings, opts} = Cms.ContentBuilder.prepare_bindings_and_options(
          Keyword.get(c.opts, :assigns, []),
          c.opts
        )
        email = Keyword.get(opts, :assigns, [])
                #|> Keyword.put(:host, ClientWeb.Endpoint.url())
                |> Enum.reduce(c.email, &(Bamboo.Phoenix.assign(&2, elem(&1, 0), elem(&1, 1))))
                |> (fn e ->
          case Cms.ContentBuilder.parse_source(c.template, bindings, opts) do
            {:ok, body} -> Map.put(e, :html_body, body)
            _ ->
              Log.warn "error parsing content template #{c.email_module}::#{c.kind}::#{c.template.id}"
              e
          end
                    end).()
                |> (fn e ->
          case Cms.ContentBuilder.parse_source(t.subject, bindings, opts) do
            {:ok, subject} -> Map.put(e, :subject, subject)
            _ ->
              Log.warn "error parsing subject template #{c.email_module}::#{c.kind}::#{c.template.id}"
              e
          end
                    end).()
        Map.put(c, :email, email)
        |> Map.put(:opts, Keyword.drop(opts, [:assigns]))
      _ -> cond do
             c.opts[:phoenix] == true and !is_nil(c.template) ->
               # Transfer assigns from opts to email and drop them
               email = Keyword.get(c.opts, :assigns, [])
                       #|> Keyword.put(:host, ClientWeb.Endpoint.url())
                       |> Enum.reduce(c.email, &(Bamboo.Phoenix.assign(&2, elem(&1, 0), elem(&1, 1))))
                       |> c.email_module.render(c.template)
               Map.put(c, :email, email)
               |> Map.put(:opts, Keyword.drop(c.opts, [:assigns]))
             true ->
               Log.warn "nothing to render #{c.email_module}::#{c.kind}"
               c
           end
    end
  end

end