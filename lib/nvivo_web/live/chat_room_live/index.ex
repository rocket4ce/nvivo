defmodule NvivoWeb.ChatRoomLive.Index do
  use NvivoWeb, :live_view

  alias Nvivo.Chats
  alias Nvivo.Chats.ChatRoom

  @impl true
  def mount(_params, _session, socket) do
    chat_rooms = Chats.list_public_chat_rooms()

    {:ok,
     socket
     |> assign(:chat_rooms, chat_rooms)
     |> assign(:page_title, "Chat Rooms")
     |> assign(:show_modal, false)
     |> assign(:changeset, Chats.change_chat_room(%ChatRoom{}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Chat Rooms")
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Chat Room")
    |> assign(:show_modal, true)
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"chat_room" => chat_room_params}, socket) do
    current_user = socket.assigns[:current_users]

    changeset =
      %ChatRoom{}
      |> ChatRoom.changeset(
        if current_user do
          Map.put(chat_room_params, "creator_id", current_user.id)
        else
          chat_room_params
        end
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"chat_room" => chat_room_params}, socket) do
    current_user = socket.assigns[:current_users]

    if current_user do
      chat_room_params = Map.put(chat_room_params, "creator_id", current_user.id)

      case Chats.create_chat_room(chat_room_params) do
        {:ok, chat_room} ->
          {:noreply,
           socket
           |> put_flash(:info, "Chat room created successfully!")
           |> push_navigate(to: ~p"/chat_rooms/#{chat_room.room_code}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be logged in to create a chat room")
       |> assign(:show_modal, false)}
    end
  end

  @impl true
  def handle_event("join_room", %{"room_code" => room_code}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/chat_rooms/#{room_code}")}
  end

  @impl true
  def handle_event("join_by_code", %{"room_code" => room_code}, socket) do
    case Chats.get_chat_room_by_code(room_code) do
      nil ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      _room ->
        {:noreply, push_navigate(socket, to: ~p"/chat_rooms/#{room_code}")}
    end
  end
end
