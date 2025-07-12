// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// Bring in Phoenix channels client library:
import {Socket} from "phoenix"

// And connect to the path in "lib/nvivo_web/endpoint.ex". We pass the
// token for authentication. Read below how it should be used.
let socket = new Socket("/socket", {params: {token: window.userToken}})

// Finally, connect to the socket:
socket.connect()

// Chat Room Management
class ChatRoomManager {
  constructor() {
    this.webrtcChannel = null
    this.chatChannel = null
    this.localStream = null
    this.peerConnections = new Map()
    this.isVideoEnabled = true
    this.isAudioEnabled = true
    this.currentRoomCode = null
    this.currentUserId = null
  }

  // Join a chat room
  joinRoom(roomCode, userId) {
    this.currentRoomCode = roomCode
    this.currentUserId = userId

    // Join WebRTC channel for video/audio
    this.webrtcChannel = socket.channel(`webrtc:room:${roomCode}`, {user_id: userId})
    this.setupWebRTCHandlers()
    this.webrtcChannel.join()
      .receive("ok", resp => {
        console.log("Joined WebRTC channel successfully", resp)
        this.setupLocalMedia()
      })
      .receive("error", resp => { console.log("Unable to join WebRTC channel", resp) })

    // Join chat channel for text messages
    this.chatChannel = socket.channel(`chat_room:${roomCode}`, {user_id: userId})
    this.setupChatHandlers()
    this.chatChannel.join()
      .receive("ok", resp => { console.log("Joined chat channel successfully", resp) })
      .receive("error", resp => { console.log("Unable to join chat channel", resp) })
  }

  // Setup WebRTC event handlers
  setupWebRTCHandlers() {
    this.webrtcChannel.on("user_joined", payload => {
      console.log("User joined:", payload)
      this.createPeerConnection(payload.user_id)
      // Create offer for the new user only if we have local stream
      if (this.localStream) {
        this.createOffer(payload.user_id)
      }
    })

    this.webrtcChannel.on("user_left", payload => {
      console.log("User left:", payload)
      this.handleUserDisconnected(payload.user_id)
    })

    this.webrtcChannel.on("participants_list", payload => {
      console.log("Participants list received:", payload)
      // Create connections for existing participants
      if (payload.participants && payload.participants.length > 0) {
        payload.participants.forEach(userId => {
          if (userId !== this.currentUserId) {
            this.createPeerConnection(userId)
            if (this.localStream) {
              this.createOffer(userId)
            }
          }
        })
      }
    })

    this.webrtcChannel.on("offer", payload => {
      console.log("Received offer:", payload)
      this.handleOffer(payload)
    })

    this.webrtcChannel.on("answer", payload => {
      console.log("Received answer:", payload)
      this.handleAnswer(payload)
    })

    this.webrtcChannel.on("ice_candidate", payload => {
      console.log("Received ICE candidate:", payload)
      this.handleICECandidate(payload)
    })

    this.webrtcChannel.on("user_media_state", payload => {
      console.log("User media state changed:", payload)
      this.updateUserMediaState(payload)
    })
  }

  // Setup chat event handlers
  setupChatHandlers() {
    this.chatChannel.on("message_history", payload => {
      console.log("Received message history:", payload)
      this.displayMessageHistory(payload.messages)
    })

    this.chatChannel.on("new_message", payload => {
      console.log("Received new message:", payload)
      this.displayMessage(payload)
    })

    this.chatChannel.on("user_joined", payload => {
      console.log("User joined chat:", payload)

      // Format user display name for join message
      let userName = 'A user'
      if (payload.user_id) {
        if (payload.user_id.startsWith('guest_')) {
          const guestId = payload.user_id.slice(-8)
          userName = `Guest ${guestId}`
        } else {
          userName = `User ${payload.user_id.slice(0, 8)}...`
        }
      }

      this.displaySystemMessage(`${userName} joined the room`)
    })

    this.chatChannel.on("user_typing", payload => {
      console.log("User typing:", payload)
      this.updateTypingIndicator(payload)
    })
  }

  // Setup local media (camera and microphone)
  async setupLocalMedia() {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: true
      })

      // Set up local video thumbnail
      const localVideo = document.getElementById('local-video')
      if (localVideo) {
        localVideo.srcObject = this.localStream
      }

      // Set up main video with local stream initially
      const mainVideoElement = document.getElementById('main-video-element')
      if (mainVideoElement) {
        mainVideoElement.srcObject = this.localStream
        mainVideoElement.muted = true // Mute main video when showing local stream
      }

      // Add tracks to all existing peer connections
      this.peerConnections.forEach(pc => {
        this.localStream.getTracks().forEach(track => {
          pc.addTrack(track, this.localStream)
        })
      })

      // Create offers for all existing peer connections now that we have media
      this.peerConnections.forEach((pc, userId) => {
        this.createOffer(userId)
      })

      console.log("Local media setup complete")
    } catch (error) {
      console.error("Error accessing media devices:", error)
      this.displaySystemMessage("Could not access camera/microphone")
    }
  }

  // Create a new peer connection
  createPeerConnection(userId) {
    if (this.peerConnections.has(userId)) {
      return this.peerConnections.get(userId)
    }

    const pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
    })

    // Add local stream tracks
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => {
        pc.addTrack(track, this.localStream)
      })
    }

    // Handle remote stream
    pc.ontrack = (event) => {
      console.log("Received remote track:", event)
      this.handleRemoteStream(userId, event.streams[0])
    }

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.webrtcChannel.push("ice_candidate", {
          candidate: event.candidate,
          target_user_id: userId
        })
      }
    }

    this.peerConnections.set(userId, pc)
    return pc
  }

  // Handle incoming offer
  async handleOffer(payload) {
    const { offer, from_user_id } = payload
    const pc = this.createPeerConnection(from_user_id)

    try {
      await pc.setRemoteDescription(JSON.parse(offer))
      const answer = await pc.createAnswer()
      await pc.setLocalDescription(answer)

      this.webrtcChannel.push("answer", {
        answer: JSON.stringify(answer),
        target_user_id: from_user_id
      })
    } catch (error) {
      console.error("Error handling offer:", error)
    }
  }

  // Handle incoming answer
  async handleAnswer(payload) {
    const { answer, from_user_id } = payload
    const pc = this.peerConnections.get(from_user_id)

    if (pc) {
      try {
        await pc.setRemoteDescription(JSON.parse(answer))
      } catch (error) {
        console.error("Error handling answer:", error)
      }
    }
  }

  // Handle ICE candidate
  async handleICECandidate(payload) {
    const { candidate, from_user_id } = payload
    const pc = this.peerConnections.get(from_user_id)

    if (pc) {
      try {
        await pc.addIceCandidate(candidate)
      } catch (error) {
        console.error("Error adding ICE candidate:", error)
      }
    }
  }

  // Handle remote video stream
  handleRemoteStream(userId, stream) {
    console.log(`Setting up remote stream for user ${userId}`)

    // Remove any existing container for this user first
    let existingContainer = document.getElementById(`video-${userId}`)
    if (existingContainer) {
      existingContainer.remove()
    }

    // Create thumbnail video container with responsive classes
    const videoContainer = document.createElement('div')
    videoContainer.id = `video-${userId}`
    videoContainer.className = 'relative bg-gray-800 rounded-lg overflow-hidden cursor-pointer hover:ring-2 hover:ring-blue-500 transition-all flex-shrink-0'
    videoContainer.setAttribute('onclick', `switchToMainVideo('${userId}')`)

    const video = document.createElement('video')
    video.autoplay = true
    video.playsInline = true
    video.muted = false // Remote videos should have audio
    video.srcObject = stream
    video.className = 'w-20 h-14 sm:w-32 sm:h-24 object-cover'

    const label = document.createElement('div')
    label.className = 'absolute bottom-0.5 left-0.5 sm:bottom-1 sm:left-1 bg-black bg-opacity-60 text-white px-1 sm:px-2 py-0.5 rounded text-xs'

    // Format user display name for label
    let displayName = `User ${userId}`
    if (userId.startsWith('guest_')) {
      const guestId = userId.slice(-8) // Last 8 characters
      displayName = `Guest ${guestId}`
    }
    label.textContent = displayName

    videoContainer.appendChild(video)
    videoContainer.appendChild(label)

    const remoteVideosContainer = document.getElementById('remote-videos-container')
    if (remoteVideosContainer) {
      remoteVideosContainer.appendChild(videoContainer)
    }

    // If this is the first remote user, show them in the main video
    if (this.peerConnections.size === 1) {
      this.switchToMainVideo(userId)
    }

    // Update participant count for both mobile and desktop
    this.updateParticipantCount()
  }

  // Switch video to main view
  switchToMainVideo(videoId) {
    const mainVideoElement = document.getElementById('main-video-element')
    const mainVideoLabel = document.getElementById('main-video-label')

    if (videoId === 'local') {
      const localVideo = document.getElementById('local-video')
      if (localVideo && localVideo.srcObject) {
        mainVideoElement.srcObject = localVideo.srcObject
        mainVideoElement.muted = true // Mute local video to avoid feedback
        mainVideoLabel.textContent = 'You'
      }
    } else {
      const remoteVideo = document.getElementById(`video-${videoId}`)
      if (remoteVideo) {
        const video = remoteVideo.querySelector('video')
        if (video && video.srcObject) {
          mainVideoElement.srcObject = video.srcObject
          mainVideoElement.muted = false // Enable audio for remote videos
          mainVideoLabel.textContent = `User ${videoId}`
        }
      }
    }
  }

  // Send chat message
  sendMessage(content) {
    if (this.chatChannel && content.trim()) {
      this.chatChannel.push("new_message", { content })
        .receive("error", resp => console.log("Failed to send message", resp))
    }
  }

  // Display message in chat
  displayMessage(message) {
    const chatMessages = document.getElementById('chat-messages')
    if (!chatMessages) return

    const messageElement = document.createElement('div')

    // Determine if message is from current user
    const isOwnMessage = message.user && (
      message.user.id === this.userId ||
      (message.user.id && message.user.id.startsWith('guest_') && message.user.id === this.userId)
    )

    messageElement.className = `chat-message ${isOwnMessage ? 'own' : 'other'}`

    const time = new Date(message.timestamp).toLocaleTimeString()

    // Format user display name
    let userName = 'Unknown User'
    if (message.user) {
      if (message.user.id && message.user.id.startsWith('guest_')) {
        // For guest users, show a friendly name
        const guestId = message.user.id.slice(-8) // Last 8 characters
        userName = `Guest ${guestId}`
      } else if (message.user.email) {
        // For registered users, show email (first part)
        userName = message.user.email.split('@')[0]
      } else {
        userName = 'Guest User'
      }
    }

    messageElement.innerHTML = `
      <div class="text-xs text-gray-300 mb-1">${userName} • ${time}</div>
      <div class="text-white">${this.escapeHtml(message.content)}</div>
    `

    chatMessages.appendChild(messageElement)
    chatMessages.scrollTop = chatMessages.scrollHeight
  }

  // Display message history
  displayMessageHistory(messages) {
    messages.forEach(message => this.displayMessage(message))
  }

  // Display system message
  displaySystemMessage(content) {
    const chatMessages = document.getElementById('chat-messages')
    if (!chatMessages) return

    const messageElement = document.createElement('div')
    messageElement.className = 'system-message text-center text-gray-500 text-sm my-2'
    messageElement.textContent = content

    chatMessages.appendChild(messageElement)
    chatMessages.scrollTop = chatMessages.scrollHeight
  }

  // Update typing indicator
  updateTypingIndicator(payload) {
    const chatMessages = document.getElementById('chat-messages')
    if (!chatMessages) return

    // Remove existing typing indicator
    const existingIndicator = document.getElementById('typing-indicator')
    if (existingIndicator) {
      existingIndicator.remove()
    }

    // Only show typing indicator if user is typing and it's not the current user
    if (payload.typing && payload.user_id && payload.user_id !== this.userId) {
      const typingElement = document.createElement('div')
      typingElement.id = 'typing-indicator'
      typingElement.className = 'typing-indicator text-gray-400 text-sm italic p-2 border-l-2 border-blue-500'

      // Format user display name
      const userDisplay = payload.user_id.startsWith('guest_')
        ? `Guest ${payload.user_id.slice(-8)}`
        : `User ${payload.user_id.slice(0, 8)}...`

      typingElement.textContent = `${userDisplay} is typing...`

      chatMessages.appendChild(typingElement)
      chatMessages.scrollTop = chatMessages.scrollHeight

      // Auto-remove typing indicator after 3 seconds
      setTimeout(() => {
        const indicator = document.getElementById('typing-indicator')
        if (indicator) {
          indicator.remove()
        }
      }, 3000)
    }
  }

  // Toggle video
  toggleVideo() {
    if (this.localStream) {
      const videoTrack = this.localStream.getVideoTracks()[0]
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled
        this.isVideoEnabled = videoTrack.enabled

        this.webrtcChannel.push("media_state", {
          audio: this.isAudioEnabled,
          video: this.isVideoEnabled
        })

        this.updateVideoButton()
      }
    }
  }

  // Toggle audio
  toggleAudio() {
    if (this.localStream) {
      const audioTrack = this.localStream.getAudioTracks()[0]
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled
        this.isAudioEnabled = audioTrack.enabled

        this.webrtcChannel.push("media_state", {
          audio: this.isAudioEnabled,
          video: this.isVideoEnabled
        })

        this.updateAudioButton()
      }
    }
  }

  // Update button states
  updateVideoButton() {
    const button = document.getElementById('toggle-video')
    if (button) {
      if (this.isVideoEnabled) {
        button.classList.remove('bg-red-600', 'hover:bg-red-700')
        button.classList.add('bg-blue-600', 'hover:bg-blue-700')
      } else {
        button.classList.remove('bg-blue-600', 'hover:bg-blue-700')
        button.classList.add('bg-red-600', 'hover:bg-red-700')
      }
    }
  }

  updateAudioButton() {
    const button = document.getElementById('toggle-audio')
    if (button) {
      if (this.isAudioEnabled) {
        button.classList.remove('bg-red-600', 'hover:bg-red-700')
        button.classList.add('bg-green-600', 'hover:bg-green-700')
      } else {
        button.classList.remove('bg-green-600', 'hover:bg-green-700')
        button.classList.add('bg-red-600', 'hover:bg-red-700')
      }
    }
  }

  // Utility function to escape HTML
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Create WebRTC offer
  async createOffer(userId) {
    const pc = this.peerConnections.get(userId)
    if (!pc) return

    try {
      const offer = await pc.createOffer()
      await pc.setLocalDescription(offer)

      this.webrtcChannel.push("offer", {
        offer: JSON.stringify(offer),
        target_user_id: userId
      })

      console.log(`Offer created for user ${userId}`)
    } catch (error) {
      console.error("Error creating offer:", error)
    }
  }

  // Handle user disconnection
  handleUserDisconnected(userId) {
    console.log(`Handling disconnection for user ${userId}`)

    // Close peer connection
    const pc = this.peerConnections.get(userId)
    if (pc) {
      pc.close()
      this.peerConnections.delete(userId)
    }

    // Check if the disconnected user is currently in main video
    const mainVideoElement = document.getElementById('main-video-element')
    const mainVideoLabel = document.getElementById('main-video-label')
    const disconnectedVideo = document.getElementById(`video-${userId}`)

    if (disconnectedVideo && mainVideoElement) {
      const disconnectedVideoElement = disconnectedVideo.querySelector('video')
      if (disconnectedVideoElement && mainVideoElement.srcObject === disconnectedVideoElement.srcObject) {
        // Switch main video back to local video
        const localVideo = document.getElementById('local-video')
        if (localVideo && localVideo.srcObject) {
          mainVideoElement.srcObject = localVideo.srcObject
          mainVideoElement.muted = true
          if (mainVideoLabel) {
            mainVideoLabel.textContent = 'You'
          }
        }
      }
    }

    // Remove video element from thumbnails
    if (disconnectedVideo) {
      disconnectedVideo.remove()
    }

    // Update participant count
    this.updateParticipantCount()

    console.log(`Successfully cleaned up user ${userId}`)
  }

  // Update participant count display
  updateParticipantCount() {
    const count = this.peerConnections.size + 1 // +1 for local user

    // Update desktop participant count
    const participantCountElement = document.getElementById('participant-count')
    if (participantCountElement) {
      participantCountElement.textContent = count
    }

    // Update mobile participant count
    const participantCountMobileElement = document.getElementById('participant-count-mobile')
    if (participantCountMobileElement) {
      participantCountMobileElement.textContent = count
    }
  }

  // Toggle video
  toggleVideo() {
    if (this.localStream) {
      const videoTrack = this.localStream.getVideoTracks()[0]
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled
        this.isVideoEnabled = videoTrack.enabled

        // Update button state
        const videoButton = document.getElementById('toggle-video')
        if (videoButton) {
          videoButton.classList.toggle('btn-active', !this.isVideoEnabled)
          videoButton.classList.toggle('btn-inactive', !this.isVideoEnabled)
        }

        // Update local video visibility
        const localVideo = document.getElementById('local-video')
        if (localVideo) {
          localVideo.style.display = this.isVideoEnabled ? 'block' : 'none'
        }

        // Notify other users
        this.webrtcChannel.push("media_state", {
          audio: this.isAudioEnabled,
          video: this.isVideoEnabled
        })
      }
    }
  }

  // Toggle audio
  toggleAudio() {
    if (this.localStream) {
      const audioTrack = this.localStream.getAudioTracks()[0]
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled
        this.isAudioEnabled = audioTrack.enabled

        // Update button state
        const audioButton = document.getElementById('toggle-audio')
        if (audioButton) {
          audioButton.classList.toggle('btn-active', !this.isAudioEnabled)
          audioButton.classList.toggle('btn-inactive', !this.isAudioEnabled)
        }

        // Notify other users
        this.webrtcChannel.push("media_state", {
          audio: this.isAudioEnabled,
          video: this.isVideoEnabled
        })
      }
    }
  }

  // Toggle chat sidebar
  toggleChat() {
    const chatSidebar = document.getElementById('chat-sidebar')
    if (chatSidebar) {
      chatSidebar.classList.toggle('hidden')
    }
  }

  // Leave room
  leaveRoom() {
    // Close all peer connections
    this.peerConnections.forEach(pc => pc.close())
    this.peerConnections.clear()

    // Stop local stream
    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop())
      this.localStream = null
    }

    // Leave channels
    if (this.webrtcChannel) {
      this.webrtcChannel.leave()
      this.webrtcChannel = null
    }

    if (this.chatChannel) {
      this.chatChannel.leave()
      this.chatChannel = null
    }
  }
}

// Export for use in other files
window.ChatRoomManager = ChatRoomManager

// Make switchToMainVideo globally accessible
window.switchToMainVideo = function(videoId) {
  if (window.currentChatManager) {
    window.currentChatManager.switchToMainVideo(videoId)
  }
}

export default socket
