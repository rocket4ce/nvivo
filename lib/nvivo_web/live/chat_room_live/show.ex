defmodule NvivoWeb.ChatRoomLive.Show do
  use NvivoWeb, :live_view

  alias Nvivo.Chats

  @impl true
  def mount(%{"room_code" => room_code}, _session, socket) do
    case Chats.get_chat_room_by_code(room_code) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Room not found")
         |> push_navigate(to: ~p"/chat_rooms")}

      room ->
        # TODO: Auto-join logic will be added later
        # if connected?(socket) do
        #   # Join the room if user is logged in
        #   current_user = socket.assigns[:current_users]

        #   if current_user && Chats.can_join_chat_room?(room, current_user) do
        #     Chats.join_chat_room(room, current_user)
        #   end
        # end

        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:room_code, room_code)
         |> assign(:messages, [])
         |> assign(:new_message, "")
         |> assign(:participants, [])
         |> assign(:user_media_states, %{})
         |> assign(:page_title, "Room: #{room.name}")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      # The actual message sending will be handled by JavaScript and Phoenix channels
      {:noreply, assign(socket, :new_message, "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_video", _params, socket) do
    # This will be handled by JavaScript
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_audio", _params, socket) do
    # This will be handled by JavaScript
    {:noreply, socket}
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat_rooms")}
  end
end
