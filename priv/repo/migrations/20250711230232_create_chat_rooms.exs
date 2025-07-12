defmodule Nvivo.Repo.Migrations.CreateChatRooms do
  use Ecto.Migration

  def change do
    create table(:chat_rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :is_public, :boolean, default: true, null: false
      add :max_participants, :integer, default: 10, null: false
      add :room_code, :string, null: false
      add :creator_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chat_rooms, [:room_code])
    create index(:chat_rooms, [:creator_id])
    create index(:chat_rooms, [:is_public])
  end
end
