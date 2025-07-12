defmodule NvivoWeb.ChatRoomChannel do
  use NvivoWeb, :channel
  alias Nvivo.Chats

  @impl true
  def join("chat_room:" <> room_code, payload, socket) do
    case Chats.get_chat_room_by_code(room_code) do
      nil ->
        {:error, %{reason: "Room not found"}}

      room ->
        socket = assign(socket, :room, room)
        socket = assign(socket, :room_code, room_code)
        socket = assign(socket, :user_id, payload["user_id"])

        # Send recent messages to the new user
        messages = Chats.get_chat_room_messages(room.id)
        send(self(), {:after_join, messages})

        {:ok, %{room: room}, socket}
    end
  end

  @impl true
  def handle_info({:after_join, messages}, socket) do
    # Send recent messages to the newly joined user
    formatted_messages =
      Enum.map(messages, fn message ->
        %{
          id: message.id,
          content: message.content,
          user:
            if(message.user, do: %{id: message.user.id, email: message.user.email}, else: nil),
          timestamp: message.inserted_at
        }
      end)

    push(socket, "message_history", %{messages: formatted_messages})

    # Notify other users about the new participant
    broadcast_from!(socket, "user_joined", %{
      user_id: socket.assigns[:user_id] || "anonymous_#{:erlang.unique_integer()}",
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle chat messages
  @impl true
  def handle_in("new_message", %{"content" => content}, socket) do
    room = socket.assigns[:room]
    user_id = socket.assigns[:user_id]

    # Check if user is a guest (temporary user)
    is_guest = String.starts_with?(user_id || "", "guest_")

    if is_guest do
      # For guest users, just broadcast the message without saving to database
      broadcast!(socket, "new_message", %{
        id: "temp_#{System.unique_integer([:positive])}",
        content: content,
        user: %{id: user_id, email: "Guest User"},
        timestamp: DateTime.utc_now()
      })

      {:reply, {:ok, %{status: "message_sent"}}, socket}
    else
      # For registered users, save to database
      message_attrs = %{
        content: content,
        chat_room_id: room.id,
        user_id: user_id,
        message_type: "text"
      }

      case Chats.create_message(message_attrs) do
        {:ok, message} ->
          message = Nvivo.Repo.preload(message, :user)

          # Broadcast message to all participants
          broadcast!(socket, "new_message", %{
            id: message.id,
            content: message.content,
            user:
              if(message.user, do: %{id: message.user.id, email: message.user.email}, else: nil),
            timestamp: message.inserted_at
          })

          {:reply, {:ok, %{status: "message_sent"}}, socket}

        {:error, _changeset} ->
          {:reply, {:error, %{reason: "Failed to send message"}}, socket}
      end
    end
  end

  # Handle typing indicators
  @impl true
  def handle_in("typing_start", _payload, socket) do
    broadcast_from!(socket, "user_typing", %{
      user_id: socket.assigns[:user_id] || "anonymous",
      typing: true
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_stop", _payload, socket) do
    broadcast_from!(socket, "user_typing", %{
      user_id: socket.assigns[:user_id] || "anonymous",
      typing: false
    })

    {:noreply, socket}
  end
end
