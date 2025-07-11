// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
import "./user_socket.js"
import { webrtcChannel } from "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// WebRTC setup wrapped in async function
async function setupWebRTC() {
  const pc = new RTCPeerConnection({
    iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
  })
  const localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
  for (const track of localStream.getTracks()) {
    pc.addTrack(track, localStream);
  }
  const offer = await pc.createOffer();
  // offer == { type: "offer", sdp: "<SDP here>"}
  await pc.setLocalDescription(offer);
  const json = JSON.stringify(offer);

  // Send offer through Phoenix channel
  webrtcChannel.push("offer", { offer: json })
    .receive("ok", resp => console.log("Offer sent successfully", resp))
    .receive("error", resp => console.log("Failed to send offer", resp))
}

// Initialize WebRTC when the page loads
setupWebRTC().catch(console.error);