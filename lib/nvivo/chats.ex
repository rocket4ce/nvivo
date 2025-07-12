defmodule Nvivo.Chats do
  @moduledoc """
  The Chats context.
  """

  import Ecto.Query, warn: false
  alias Nvivo.Repo

  alias Nvivo.Chats.ChatRoom
  alias Nvivo.Chats.Message
  alias Nvivo.Accounts.Users

  @doc """
  Returns the list of chat rooms.
  """
  def list_chat_rooms do
    Repo.all(ChatRoom)
    |> Repo.preload([:creator, :participants])
  end

  @doc """
  Returns the list of public chat rooms.
  """
  def list_public_chat_rooms do
    ChatRoom
    |> where([c], c.is_public == true)
    |> Repo.all()
    |> Repo.preload([:creator, :participants])
  end

  @doc """
  Gets a single chat room.
  """
  def get_chat_room!(id),
    do: Repo.get!(ChatRoom, id) |> Repo.preload([:creator, :participants, :messages])

  @doc """
  Gets a chat room by room code.
  """
  def get_chat_room_by_code(room_code) do
    ChatRoom
    |> where([c], c.room_code == ^room_code)
    |> Repo.one()
    |> case do
      nil -> nil
      room -> Repo.preload(room, [:creator, :participants, :messages])
    end
  end

  @doc """
  Creates a chat room.
  """
  def create_chat_room(attrs \\ %{}) do
    %ChatRoom{}
    |> ChatRoom.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a chat room.
  """
  def update_chat_room(%ChatRoom{} = chat_room, attrs) do
    chat_room
    |> ChatRoom.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a chat room.
  """
  def delete_chat_room(%ChatRoom{} = chat_room) do
    Repo.delete(chat_room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking chat room changes.
  """
  def change_chat_room(%ChatRoom{} = chat_room, attrs \\ %{}) do
    ChatRoom.changeset(chat_room, attrs)
  end

  @doc """
  Adds a user to a chat room.
  """
  def join_chat_room(%ChatRoom{} = chat_room, %Users{} = user) do
    chat_room
    |> Repo.preload(:participants)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:participants, [user | chat_room.participants])
    |> Repo.update()
  end

  @doc """
  Removes a user from a chat room.
  """
  def leave_chat_room(%ChatRoom{} = chat_room, %Users{} = user) do
    chat_room
    |> Repo.preload(:participants)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(
      :participants,
      Enum.reject(chat_room.participants, &(&1.id == user.id))
    )
    |> Repo.update()
  end

  @doc """
  Creates a message in a chat room.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets messages for a chat room.
  """
  def get_chat_room_messages(chat_room_id) do
    Message
    |> where([m], m.chat_room_id == ^chat_room_id)
    |> order_by([m], asc: m.inserted_at)
    # Limit to last 100 messages
    |> limit(100)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Checks if a user can join a chat room.
  """
  def can_join_chat_room?(%ChatRoom{} = chat_room, %Users{} = user) do
    participant_count = length(chat_room.participants)
    user_already_joined = Enum.any?(chat_room.participants, &(&1.id == user.id))

    !user_already_joined and participant_count < chat_room.max_participants
  end

  @doc """
  Checks if a user is in a chat room.
  """
  def user_in_chat_room?(%ChatRoom{} = chat_room, %Users{} = user) do
    Enum.any?(chat_room.participants, &(&1.id == user.id))
  end
end
