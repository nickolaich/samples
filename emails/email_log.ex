defmodule Lms.Emails.EmailLog do
  @moduledoc """
    Module for optional logging sending of emails to the database.
    If client has billing activated, it can write with relation to :period and allows to calculate usage of emails later.
  """
  use Lms.Model
  use Lms.Service
  alias Lms.Emails.EmailLog
  require Logger
  import Ecto.Query

  schema "email_logs" do
    field :kind, :string
    field :resource_id, :string
    field :billing_period_id, :integer
    belongs_to :region, Region
    belongs_to :user, User

    field :uid, :string
    field :remote_uid, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(r, attrs) do
    r
    |> cast(Lms.Utils.Cast.to_string(attrs, :kind), [:kind, :resource_id, :billing_period_id, :uid, :remote_uid])
    |> validate_required([:kind])
  end

  @doc """
    Log sending of email
    :async - control how to write (same thread or with async task or supervised)
  """
  def log_record(region, user, kind, opts \\ [])
  def log_record(%Region{} = region, user, kind, opts) do
    case opts[:async] do
      true ->
        # Run supervised task w/o attaching to main process
        Supervisor.start_link(
          [
            {
              Task,
              fn ->
                log_record(region, user, kind, Keyword.drop(opts, [:async]))
              end
            }
          ],
          strategy: :one_for_one
        )

      :await ->
        # Run async task, but callee will need to implement handle_info (if it's live view) to handle task completion
        # Otherwise we will have an error
        _task = Task.async(
          fn ->
            if is_integer(opts[:delay]) do
              :timer.sleep(opts[:delay])
            end
            log_record(region, user, kind, Keyword.drop(opts, [:async]))
          end
        )
      _ ->
        attrs = %{kind: kind, resource_id: Lms.Utils.Cast.to_string(opts[:resource_id])}
                |> put_billing_period(opts[:period])
                |> Map.merge(
                     Enum.into(Keyword.take(opts, [:uid, :remote_uid]), %{})
                     |> Lms.Utils.Cast.to_string(:recursive)
                   )
                |> IO.inspect
        case changeset(%__MODULE__{}, attrs)
             |> put_assoc(:region, region)
             |> put_assoc(:user, user)
             |> insert_to_tenant(opts) do
          {:error, e} ->
            Logger.error("couldn't write to email log :#{kind}")
          ok -> ok
        end
    end

  end
  # Apply billing period if presented at options
  defp put_billing_period(map, p) do
    Map.put(
      map,
      :billing_period_id,
      (case p do
         %BillingPeriod{} = period -> period.id
         p when is_integer(p) -> p
         _ -> nil
       end)
    )
  end


  @doc """
    Filtering and reading emails.
    TODO:: better to move to service for reading, as a PoC is enough for now
  """
  # Region filter
  def query_by_region(query, region) when is_integer(region) do
    query
    |> where([e], e.region_id == ^region)
  end
  def query_by_region(query, %Region{} = region), do: query_by_region(query, region.id)
  def query_by_region(query, %{region: region}), do: query_by_region(query, region)
  def query_by_region(query, _), do: query

  # Billing period filter
  def query_by_billing_period(query, period) when is_integer(period) do
    query
    |> where([e], e.billing_period_id == ^period)
  end
  def query_by_billing_period(query, %BillingPeriod{} = period), do: query_by_billing_period(query, period.id)
  def query_by_billing_period(query, %{period: period}), do: query_by_billing_period(query, period)
  def query_by_billing_period(query, _), do: query

  # Resource ID filter filter
  def query_by_resource(query, resource) when is_binary(resource) or is_integer(resource) do
    query
    |> where([e], e.resource_id == ^Lms.Utils.Cast.to_string(resource))
  end

  def query_by_resource(query, %{__meta__: _} = resource), do: query_by_resource(query, resource.id)
  def query_by_resource(query, %{resource: resource}), do: query_by_resource(query, resource)
  def query_by_resource(query, _), do: query

  # User filter
  def query_by_user(query, user) when is_integer(user) do
    query
    |> where([e], e.user_id == ^user)
  end
  def query_by_user(query, %{user: user}) when is_list(user) do
    ids = Lms.Utils.Cast.list_to_ids(user)
    query
    |> where([e], e.user_id in ^ids)
  end
  def query_by_user(query, %User{} = user), do: query_by_user(query, user.id)
  def query_by_user(query, %{user: user}), do: query_by_user(query, user)
  def query_by_user(query, _), do: query

  # Apply type filter
  def query_by_kind(query, kind) when is_binary(kind) or is_atom(kind) do
    kind = Lms.Utils.Cast.to_string(kind)
    query
    |> where([e], e.kind == ^kind)
  end
  def query_by_kind(query, %{kind: kind}), do: query_by_kind(query, kind)
  def query_by_kind(query, _), do: query

  def query_by_uid(query, uid) when is_binary(uid) or is_atom(uid) or is_integer(uid) do
    uid = Lms.Utils.Cast.to_string(uid)
    query
    |> where([e], e.uid == ^uid)
  end
  def query_by_uid(query, %{uid: uid}), do: query_by_uid(query, uid)
  def query_by_uid(query, _), do: query

  def query_by_remote_uid(query, remote_uid)
      when is_binary(remote_uid) or is_atom(remote_uid) or is_integer(remote_uid) do
    remote_uid = Lms.Utils.Cast.to_string(remote_uid)
    query
    |> where([e], e.remote_uid == ^remote_uid)
  end
  def query_by_remote_uid(query, %{remote_uid: remote_uid}), do: query_by_remote_uid(query, remote_uid)
  def query_by_remote_uid(query, _), do: query

  def apply_filters(query, opts) do
    query
    |> query_by_region(opts)
    |> query_by_user(opts)
    |> query_by_kind(opts)
    |> query_by_resource(opts)
    |> query_by_uid(opts)
    |> query_by_remote_uid(opts)
    |> query_by_billing_period(opts)
  end

  def count_records(attrs \\ %{}, opts \\ []) do
    (from(e in EmailLog, select: count(e.id)))
    |> apply_filters(attrs)
    |> Repo.one(opts)
  end

  def list_records(attrs \\ %{}, opts \\ []) do
    (from(e in EmailLog, select: e))
    |> apply_filters(attrs)
    |> Repo.all(opts)
  end
  @doc """
    Read emails sent for specific  list of users by resource and type.
    For instance, we can read a list of "reminders" for specific %Webinar{} and list of users or single user
  """
  def user_emails(region, users, kind, resource, opts \\ []) do
    list_records(
      %{user: users, region: region, kind: kind, resource: resource}
    )
    |> Enum.map(
         fn r ->
           cond do
             opts[:short] -> %{id: r.id, inserted_at: r.inserted_at, kind: r.kind}
             is_list(opts[:cols]) -> Map.take(r, opts[:cols])
             true -> r
           end

         end
       )
    |> (fn list ->
      if !is_nil(opts[:uniq_by]) do
        list
        |> Enum.uniq_by(fn r -> Map.get(r, opts[:uniq_by]) end)
      else
        list
      end
        end).()
  end

end