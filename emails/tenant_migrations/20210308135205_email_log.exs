defmodule Lms.Repo.Migrations.EmailLog do
  use Ecto.Migration

  def change do
    create table "email_logs" do
      add :region_id, references(:regions, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nilify_all)
      add :billing_period_id, :integer
      add :kind, :string
      add :resource_id, :string
      timestamps(type: :timestamptz)
    end

    create index("email_logs", [:billing_period_id], comment: "Needs to calculate limit usage")
  end
end
