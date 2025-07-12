defmodule Nvivo.Chats.ChatRoom do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :description,
             :is_public,
             :max_participants,
             :room_code,
             :creator_id
           ]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_rooms" do
    field :name, :string
    field :description, :string
    field :is_public, :boolean, default: true
    field :max_participants, :integer, default: 10
    field :room_code, :string

    belongs_to :creator, Nvivo.Accounts.Users

    many_to_many :participants, Nvivo.Accounts.Users,
      join_through: "chat_room_participants",
      join_keys: [chat_room_id: :id, user_id: :id]

    has_many :messages, Nvivo.Chats.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat_room, attrs) do
    chat_room
    |> cast(attrs, [:name, :description, :is_public, :max_participants, :creator_id])
    |> validate_required([:name, :creator_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:max_participants, greater_than: 0, less_than_or_equal_to: 50)
    |> put_room_code()
    |> unique_constraint(:room_code)
  end

  defp put_room_code(changeset) do
    if get_field(changeset, :room_code) do
      changeset
    else
      put_change(changeset, :room_code, generate_room_code())
    end
  end

  defp generate_room_code do
    6
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
    |> String.upcase()
  end
end
