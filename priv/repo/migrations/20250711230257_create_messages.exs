defmodule Nvivo.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :message_type, :string, default: "text", null: false
      add :metadata, :map, default: %{}

      add :chat_room_id, references(:chat_rooms, on_delete: :delete_all, type: :binary_id),
        null: false

      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:chat_room_id])
    create index(:messages, [:user_id])
    create index(:messages, [:inserted_at])
  end
end
