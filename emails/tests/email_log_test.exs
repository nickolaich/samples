defmodule Lms.Emails.LogTest do
  use Lms.Case

  alias Lms.Emails.EmailLog
  alias Lms.Factories.{ClientFactory, UserFactory}
  alias Lms.Billing

  setup _ do

    client = ClientFactory.create_client()
    region = ClientFactory.create_region()
    user = UserFactory.create_user(%{email: "test-email1.com"})
    %{region: region, user: user, client: client}
  end

  test "get log records", %{region: region, user: user, client: client} do
    period1 = Billing.find_or_create(client, ~D[2021-01-31])
    period2 = Billing.find_or_create(client, ~D[2021-03-31])
    user2 = UserFactory.create_user(%{email: "test-email2.com"})
    res_id = UUID.uuid1()
    region2 = ClientFactory.create_region()
    assert 0 == EmailLog.count_records()
    assert 0 == EmailLog.count_records(%{period: period1, user: user, region: region})
    assert 0 == EmailLog.count_records(%{period: period2, user: user, region: region})
    EmailLog.log_record(region, user, :test_email, period: period1)
    EmailLog.log_record(region, user, :test_email, period: period1.id)
    EmailLog.log_record(region, user, :test_email, period: period1.id)
    EmailLog.log_record(region, user, :test_email, period: period2.id)
    # no period
    EmailLog.log_record(region, user, :test_email)
    # other region
    EmailLog.log_record(region, user, :custom)
    # other kind, other region
    EmailLog.log_record(region2, user, :test_email)
    EmailLog.log_record(region2, user, :test_email, resource_id: res_id)
    # Add a more for another user, w/o period, other kinds


    EmailLog.log_record(region, user2, :test_email, period: period1.id)
    EmailLog.log_record(region, user2, :test_email, period: period2.id)
    EmailLog.log_record(region, user2, :something, period: period1.id, uid: 77, remote_uid: "xx-yy-zz")
    EmailLog.log_record(region, user2, :something2, period: period2.id, uid: 77)
    EmailLog.log_record(region, user2, :custom, resource_id: res_id)

    # Check with user/period/region
    assert 3 == EmailLog.count_records(%{region: region, user: user, kind: :test_email, period: period1})
    assert 1 == EmailLog.count_records(%{region: region, user: user, kind: :test_email, period: period2})
    # w/o period
    assert 5 == EmailLog.count_records(%{region: region, user: user, kind: :test_email})
    # other region
    assert 2 == EmailLog.count_records(%{region: region2, user: user, kind: :test_email})
    # all for user by kind
    assert 7 == EmailLog.count_records(%{user: user, kind: :test_email})

    # For user 2
    assert 5 == EmailLog.count_records(%{user: user2})
    # With resource filter
    assert 2 == EmailLog.count_records(%{resource: res_id})
    assert 1 == EmailLog.count_records(%{user: user2, resource: res_id})

    # Uid filter
    assert 0 == EmailLog.count_records(%{uid: 10})
    assert 2 == EmailLog.count_records(%{uid: 77})

    # Uid filter
    assert 0 == EmailLog.count_records(%{remote_uid: "-"})
    assert 1 == EmailLog.count_records(%{remote_uid: "xx-yy-zz"})


  end


  test "async call", %{region: region, user: user} do
    %Task{} = task = EmailLog.log_record(region, user, :test_email, async: :await)
    {:ok, %Lms.Emails.EmailLog{}} = Task.await(task)
  end

end