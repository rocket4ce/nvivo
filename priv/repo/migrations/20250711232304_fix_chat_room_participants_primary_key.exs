defmodule Nvivo.Repo.Migrations.FixChatRoomParticipantsPrimaryKey do
  use Ecto.Migration

  def up do
    # Drop the existing table and recreate it with composite primary key
    drop table(:chat_room_participants)

    create table(:chat_room_participants, primary_key: false) do
      add :chat_room_id, references(:chat_rooms, on_delete: :delete_all, type: :binary_id),
        null: false,
        primary_key: true

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id),
        null: false,
        primary_key: true

      add :joined_at, :utc_datetime, null: false, default: fragment("now()")

      timestamps(type: :utc_datetime)
    end

    create index(:chat_room_participants, [:chat_room_id])
    create index(:chat_room_participants, [:user_id])
  end

  def down do
    # Recreate the original table structure
    drop table(:chat_room_participants)

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
