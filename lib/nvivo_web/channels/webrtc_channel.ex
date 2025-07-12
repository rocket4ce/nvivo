defmodule NvivoWeb.WebRTCChannel do
  use NvivoWeb, :channel
  alias Nvivo.Chats

  @impl true
  def join("webrtc:room:" <> room_code, payload, socket) do
    case Chats.get_chat_room_by_code(room_code) do
      nil ->
        {:error, %{reason: "Room not found"}}

      room ->
        socket = assign(socket, :room, room)
        socket = assign(socket, :room_code, room_code)
        socket = assign(socket, :user_id, payload["user_id"])

        # Send existing participants to the new user
        participants = get_channel_participants(room_code)
        send(self(), {:after_join, participants})

        # Create a serializable room object
        room_data = %{
          id: room.id,
          name: room.name,
          description: room.description,
          is_public: room.is_public,
          max_participants: room.max_participants,
          room_code: room.room_code,
          creator_id: room.creator_id
        }

        {:ok, %{room: room_data, participants: participants}, socket}
    end
  end

  @impl true
  def join("webrtc:signaling", _payload, socket) do
    # Legacy support for the old signaling channel
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, participants}, socket) do
    # Notify the new user about existing participants
    push(socket, "participants_list", %{participants: participants})

    # Notify other participants about the new user
    broadcast_from!(socket, "user_joined", %{
      user_id: socket.assigns[:user_id] || "anonymous_#{:erlang.unique_integer()}",
      timestamp: DateTime.utc_now()
    })

    {:noreply, socket}
  end

  # Handle WebRTC signaling messages
  @impl true
  def handle_in("offer", %{"offer" => offer, "target_user_id" => target_user_id}, socket) do
    broadcast_from!(socket, "offer", %{
      "offer" => offer,
      "from_user_id" => socket.assigns[:user_id] || "anonymous",
      "target_user_id" => target_user_id
    })

    {:reply, {:ok, %{status: "offer_sent"}}, socket}
  end

  @impl true
  def handle_in("answer", %{"answer" => answer, "target_user_id" => target_user_id}, socket) do
    broadcast_from!(socket, "answer", %{
      "answer" => answer,
      "from_user_id" => socket.assigns[:user_id] || "anonymous",
      "target_user_id" => target_user_id
    })

    {:reply, {:ok, %{status: "answer_sent"}}, socket}
  end

  @impl true
  def handle_in(
        "ice_candidate",
        %{"candidate" => candidate, "target_user_id" => target_user_id},
        socket
      ) do
    broadcast_from!(socket, "ice_candidate", %{
      "candidate" => candidate,
      "from_user_id" => socket.assigns[:user_id] || "anonymous",
      "target_user_id" => target_user_id
    })

    {:reply, {:ok, %{status: "candidate_sent"}}, socket}
  end

  # Handle chat messages
  @impl true
  def handle_in("chat_message", %{"message" => content}, socket) do
    room = socket.assigns[:room]
    user_id = socket.assigns[:user_id]

    # Save message to database
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
        broadcast!(socket, "chat_message", %{
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

  # Handle user media state changes (muted/unmuted)
  @impl true
  def handle_in("media_state", %{"audio" => audio, "video" => video}, socket) do
    broadcast_from!(socket, "user_media_state", %{
      user_id: socket.assigns[:user_id] || "anonymous",
      audio: audio,
      video: video
    })

    {:noreply, socket}
  end

  # Handle any other messages
  @impl true
  def handle_in(event, payload, socket) do
    IO.inspect({event, payload}, label: "Unhandled WebRTC event")
    {:noreply, socket}
  end

  # Handle user disconnection
  @impl true
  def terminate(reason, socket) do
    # Convert reason to a serializable string
    reason_string =
      case reason do
        :normal -> "normal"
        :shutdown -> "disconnected"
        {:shutdown, _} -> "disconnected"
        _ -> "unknown"
      end

    # Notify other participants about the user leaving
    broadcast_from!(socket, "user_left", %{
      user_id: socket.assigns[:user_id] || "anonymous",
      reason: reason_string,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    :ok
  end

  # Private functions
  defp get_channel_participants(_room_code) do
    # Get all connected users from the Phoenix.PubSub presence system
    # _topic = "webrtc:room:#{room_code}"

    # For now, return empty list. In production, you would use Phoenix.Presence
    # to track connected users
    []
  end
end
