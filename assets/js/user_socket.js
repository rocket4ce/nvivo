// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// And connect to the path in "lib/nvivo_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the user. For
// example, imagine you have an authentication plug, `MyAuth`, which
// authenticates the session and assigns a `:current_user`. If the
// current user exists you can assign the user's token in the connection
// for use in the layout.
//
// In your "lib/nvivo_web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/nvivo_web/templates/layout/app.html.heex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/nvivo_web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect()

// Now that you are connected, you can join channels with a topic.
let channel = socket.channel("webrtc:signaling", {})

// Handle incoming WebRTC messages
channel.on("offer", payload => {
  console.log("Received offer:", payload)
  // Handle incoming offer from another peer
  handleIncomingOffer(payload.offer)
})

channel.on("answer", payload => {
  console.log("Received answer:", payload)
  // Handle incoming answer from another peer
  handleIncomingAnswer(payload.answer)
})

channel.on("ice_candidate", payload => {
  console.log("Received ICE candidate:", payload)
  // Handle incoming ICE candidate from another peer
  handleIncomingICECandidate(payload.candidate)
})

channel.join()
  .receive("ok", resp => { console.log("Joined WebRTC signaling channel successfully", resp) })
  .receive("error", resp => { console.log("Unable to join WebRTC signaling channel", resp) })

// Placeholder functions for WebRTC message handling
// These will be implemented in the main app
function handleIncomingOffer(offer) {
  console.log("TODO: Handle incoming offer", offer)
}

function handleIncomingAnswer(answer) {
  console.log("TODO: Handle incoming answer", answer)
}

function handleIncomingICECandidate(candidate) {
  console.log("TODO: Handle incoming ICE candidate", candidate)
}

export default socket
export { channel as webrtcChannel }
