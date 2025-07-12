defmodule Nvivo.Repo.Migrations.CreateChatRoomParticipants do
  use Ecto.Migration

  def change do
    create table(:chat_room_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :chat_room_id, references(:chat_rooms, on_delete: :delete_all, type: :binary_id),
        null: false

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :joined_at, :utc_datetime, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_room_participants, [:chat_room_id, :user_id])
    create index(:chat_room_participants, [:chat_room_id])
    create index(:chat_room_participants, [:user_id])
  end
end
