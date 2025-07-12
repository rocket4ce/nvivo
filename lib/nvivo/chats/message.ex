defmodule Nvivo.Chats.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:id, :content, :message_type, :metadata, :chat_room_id, :user_id, :inserted_at]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    # text, system, webrtc_signal
    field :message_type, :string, default: "text"
    field :metadata, :map, default: %{}

    belongs_to :chat_room, Nvivo.Chats.ChatRoom
    # optional for anonymous users
    belongs_to :user, Nvivo.Accounts.Users

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :metadata, :chat_room_id, :user_id])
    |> validate_required([:content, :chat_room_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> validate_inclusion(:message_type, ["text", "system", "webrtc_signal"])
  end
end
