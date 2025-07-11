defmodule NvivoWeb.WebRTCChannel do
  use NvivoWeb, :channel

  @impl true
  def join("webrtc:signaling", _payload, socket) do
    {:ok, socket}
  end

  # Handle incoming WebRTC offers
  @impl true
  def handle_in("offer", %{"offer" => offer}, socket) do
    # Broadcast the offer to all other clients in this channel
    # In a real application, you might want to implement room-based signaling
    broadcast_from(socket, "offer", %{"offer" => offer})
    {:reply, {:ok, %{status: "offer_broadcasted"}}, socket}
  end

  # Handle incoming WebRTC answers
  @impl true
  def handle_in("answer", %{"answer" => answer}, socket) do
    broadcast_from(socket, "answer", %{"answer" => answer})
    {:reply, {:ok, %{status: "answer_broadcasted"}}, socket}
  end

  # Handle ICE candidates
  @impl true
  def handle_in("ice_candidate", %{"candidate" => candidate}, socket) do
    broadcast_from(socket, "ice_candidate", %{"candidate" => candidate})
    {:reply, {:ok, %{status: "candidate_broadcasted"}}, socket}
  end

  # Handle any other messages
  @impl true
  def handle_in(event, payload, socket) do
    IO.inspect({event, payload}, label: "Unhandled WebRTC event")
    {:noreply, socket}
  end
end
