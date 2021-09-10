defmodule Lms.Repo.Migrations.ExtendEmailLogs do
  use Ecto.Migration

  def change do
    alter table "email_logs" do
      add :uid, :string
      add :remote_uid, :string
    end
  end
end
