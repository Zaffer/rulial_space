extends Node

# TODO: Consider cleaning up peer_connections entries after signaling is complete,
# since they're only needed for WebRTC handshake, not ongoing mesh communication

# Simplified signals - only what we actually need beyond built-in ones
signal connection_established
signal connection_failed
signal invite_token_ready(token: String)
signal response_token_ready(token: String)

# Core WebRTC components
var webrtc_multiplayer: WebRTCMultiplayerPeer
var my_peer_id: int

# Signaling data for each peer
var peer_signaling_data: Dictionary = {}  # peer_id -> {connection: WebRTCPeerConnection, session: {type, sdp, ice_candidates}}

# Remote player management
var remote_players: Dictionary = {}  # peer_id -> RemotePlayer

func _ready():
	webrtc_multiplayer = WebRTCMultiplayerPeer.new()
	
	# Connect multiplayer signals - they won't fire until multiplayer_peer is set
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(_delta):
	# Poll all peer connections
	for peer_id in peer_signaling_data.keys():
		var peer_data = peer_signaling_data[peer_id]
		peer_data.connection.poll()
		
		# Debug: Check connection state
		var state = peer_data.connection.get_connection_state()
		if state == WebRTCPeerConnection.STATE_CONNECTED:
			# Only log once when connection becomes ready
			if not peer_data.has("logged_connected"):
				print("WebRTC peer connection established for peer: ", peer_id)
				peer_data["logged_connected"] = true

# Create an invite token for another peer to join the mesh
func create_peer_invite_token():
	# Initialize mesh network if not already started
	if not is_mesh_connected():
		my_peer_id = _generate_mesh_peer_id()
		webrtc_multiplayer.create_mesh(my_peer_id)
		multiplayer.multiplayer_peer = webrtc_multiplayer
		# Don't emit connection_established here - wait for actual peer connections
	
	# Generate peer ID for the new connection
	var new_peer_id = _generate_mesh_peer_id()
	
	# Create peer connection for signaling
	var peer_connection = _create_peer_connection()
	
	# Store peer signaling data
	peer_signaling_data[new_peer_id] = {
		"connection": peer_connection,
		"session": {"type": "", "sdp": "", "ice_candidates": []}
	}
	
	# Connect signals for this specific peer
	peer_connection.session_description_created.connect(_on_session_created.bind(new_peer_id))
	peer_connection.ice_candidate_created.connect(_on_ice_candidate_created.bind(new_peer_id))
	
	# Create negotiated data channel BEFORE adding to mesh (like in working direct-WebRTC manager)
	peer_connection.create_data_channel("gamedata", {"negotiated": true, "id": 1})
	
	# Add to mesh network BEFORE creating offer - this sets up data channels
	webrtc_multiplayer.add_peer(peer_connection, new_peer_id)
	
	# Create offer
	peer_connection.create_offer()

# Join the mesh using an invite token
func join_mesh_with_token(invite_token: String):
	print("Joining mesh with invite token...")
	
	# Decode the token
	var token_data = _decode_token(invite_token)
	if not token_data:
		print("Error: Invalid mesh invite token")
		connection_failed.emit()
		return
	
	print("Token decoded, assigned peer_id: ", token_data.get("peer_id"))
	
	# Set up our mesh with the ID from the token (this is the ID assigned to us by the inviter)
	my_peer_id = int(token_data.get("peer_id"))  # Convert to int
	if not my_peer_id:
		print("Error: No peer_id found in token")
		connection_failed.emit()
		return
	
	print("Creating mesh with my_peer_id: ", my_peer_id)
	webrtc_multiplayer.create_mesh(my_peer_id)
	multiplayer.multiplayer_peer = webrtc_multiplayer
	
	# Don't emit connection_established here - wait for actual peer connections
	
	# Get the inviting peer's ID from token
	var inviting_peer_id = int(token_data.get("sender_id"))  # Convert to int
	if not inviting_peer_id or inviting_peer_id == 0:
		print("Error: Invalid sender_id in token: ", inviting_peer_id)
		print("This usually means the inviting peer had an invalid peer ID when creating the token")
		connection_failed.emit()
		return
	
	print("Connecting to inviting peer: ", inviting_peer_id)
	

	
	# Create peer connection to the inviting peer
	var peer_connection = _create_peer_connection()
	
	# Store peer signaling data
	peer_signaling_data[inviting_peer_id] = {
		"connection": peer_connection,
		"session": {"type": "", "sdp": "", "ice_candidates": []}
	}
	
	peer_connection.session_description_created.connect(_on_session_created.bind(inviting_peer_id))
	peer_connection.ice_candidate_created.connect(_on_ice_candidate_created.bind(inviting_peer_id))
	
	# Create negotiated data channel BEFORE setting remote description (like in working direct-WebRTC manager)
	peer_connection.create_data_channel("gamedata", {"negotiated": true, "id": 1})
	
	# Add to mesh BEFORE setting remote description (peer must be in STATE_NEW)
	webrtc_multiplayer.add_peer(peer_connection, inviting_peer_id)
	
	# Set remote description from token
	peer_connection.set_remote_description(token_data.type, token_data.sdp)
	
	# Add ICE candidates from token
	for candidate in token_data.ice_candidates:
		peer_connection.add_ice_candidate(candidate.media, candidate.index, candidate.name)
	
	# Answer will be automatically generated when set_remote_description() is called above
	# The session_description_created signal will be emitted with type "answer"
	print("Answer should be generated automatically now...")

# Complete mesh connection with response token
func complete_mesh_connection_with_token(response_token: String):
	print("Completing mesh connection with response token...")
	
	# Decode response token
	var token_data = _decode_token(response_token)
	if not token_data:
		print("Error: Invalid mesh response token")
		connection_failed.emit()
		return
	
	print("Response token decoded, type: ", token_data.get("type"))
	
	# Find the peer connection for this response
	var expected_peer_id = int(token_data.get("sender_id", 0))  # The peer who sent the answer (convert to int)
	
	print("Looking for peer connection with ID: ", expected_peer_id)
	print("Available peer connections: ", peer_signaling_data.keys())
	
	if not peer_signaling_data.has(expected_peer_id):
		print("Error: No peer connection found for peer ID: ", expected_peer_id)
		connection_failed.emit()
		return
	
	var peer_connection = peer_signaling_data[expected_peer_id].connection
	print("Found peer connection, setting remote description...")
	
	# Set remote description (answer) to complete connection
	peer_connection.set_remote_description(token_data.type, token_data.sdp)
	
	# Add ICE candidates
	for candidate in token_data.ice_candidates:
		peer_connection.add_ice_candidate(candidate.media, candidate.index, candidate.name)
	
	print("Mesh connection setup completed for peer: ", expected_peer_id)
	
	# Do not emit connection_established here - this is just completing the signaling
	# The actual peer connection will trigger _on_peer_connected when ready
	


# Helper to create peer connection
func _create_peer_connection() -> WebRTCPeerConnection:
	var peer = WebRTCPeerConnection.new()
	peer.initialize({
		"iceServers": [
			{"urls": ["stun:stun.l.google.com:19302"]}
		]
	})
	return peer

# Called when session description is created
func _on_session_created(type: String, sdp: String, peer_id: int):
	print("Session created - type: ", type, " for peer: ", peer_id)
	
	# Find the peer connection and set local description
	if not peer_signaling_data.has(peer_id):
		print("Error: No peer connection found for peer ID: ", peer_id)
		connection_failed.emit()
		return
	
	print("Setting local description and storing session data...")
	# Store session data for this specific peer
	peer_signaling_data[peer_id].connection.set_local_description(type, sdp)
	peer_signaling_data[peer_id].session["type"] = type
	peer_signaling_data[peer_id].session["sdp"] = sdp
	
	print("Waiting for ICE candidates...")
	# Wait for ICE candidates, then generate token
	await get_tree().create_timer(2.0).timeout
	_generate_token(peer_id)

# Called when ICE candidate is created
func _on_ice_candidate_created(media: String, index: int, candidate_name: String, peer_id: int):
	# Add ICE candidate to this peer's session data
	if peer_signaling_data.has(peer_id):
		peer_signaling_data[peer_id].session["ice_candidates"].append({"media": media, "index": index, "name": candidate_name})

# Generate token from session data
func _generate_token(peer_id: int):
	if not peer_signaling_data.has(peer_id):
		print("Error: No session data found for peer ID: ", peer_id)
		return
	
	var session_data = peer_signaling_data[peer_id].session
	var token_data = {
		"type": session_data.type,
		"sdp": session_data.sdp,
		"ice_candidates": session_data.ice_candidates
	}
	
	# For offer tokens, peer_id is the target, sender_id is us
	# For answer tokens, peer_id is who we're responding to, sender_id is us
	if session_data.type == "offer":
		token_data["peer_id"] = peer_id  # Target peer should use this ID
		token_data["sender_id"] = my_peer_id  # We are sending the offer
		print("Creating offer token - my_peer_id: ", my_peer_id, ", target peer_id: ", peer_id)
	else:  # answer
		token_data["peer_id"] = peer_id  # Who we're responding to
		token_data["sender_id"] = my_peer_id  # We are sending the answer
		print("Creating answer token - my_peer_id: ", my_peer_id, ", responding to peer_id: ", peer_id)
	

	
	var json_string = JSON.stringify(token_data)
	var token = Marshalls.utf8_to_base64(json_string)
	
	if session_data.type == "offer":
		invite_token_ready.emit(token)
	else:
		response_token_ready.emit(token)

# Decode base64 token to dictionary
func _decode_token(token: String) -> Dictionary:
	var json_string = Marshalls.base64_to_utf8(token)
	if json_string == "":
		return {}
	
	var data = JSON.parse_string(json_string)
	if not data:
		return {}
	
	return data

# Send player data to all mesh peers using RPC
func send_player_data(position: Vector3, rotation: Vector3):
	if multiplayer.multiplayer_peer:
		_receive_player_data.rpc(position, rotation)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_player_data(position: Vector3, rotation: Vector3):
	var sender_id = multiplayer.get_remote_sender_id()
	# Only handle data from remote peers
	if sender_id != 0:
		# Update remote player position
		if remote_players.has(sender_id):
			remote_players[sender_id].update_position(position, rotation)
			
		# Update or create remote player
		if not remote_players.has(sender_id):
			_create_remote_player(sender_id)


# Signal handlers - handle remote player management directly
func _on_peer_connected(peer_id: int):
	print("!!! MESH PEER CONNECTED EVENT: ", peer_id, " !!!")
	print("Total peers now: ", get_mesh_peers().size())
	print("All connected peers: ", get_mesh_peers())
	
	# Create remote player directly when peer connects
	_create_remote_player(peer_id)

func _on_peer_disconnected(peer_id: int):
	print("!!! MESH PEER DISCONNECTED EVENT: ", peer_id, " !!!")
	
	# Clean up remote player directly when peer disconnects
	_remove_remote_player(peer_id)

# Clean up mesh network
func stop_mesh():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
	if webrtc_multiplayer:
		webrtc_multiplayer.close()
		webrtc_multiplayer = WebRTCMultiplayerPeer.new()
	
	# Close all peer connections
	for peer_data in peer_signaling_data.values():
		peer_data.connection.close()
	peer_signaling_data.clear()
	
	# Clean up all remote players
	for peer_id in remote_players.keys():
		_remove_remote_player(peer_id)

# Get list of connected mesh peers
func get_mesh_peers() -> Array:
	if not multiplayer.multiplayer_peer:
		return []
	return multiplayer.get_peers()

# Get WebRTC connection state for a specific peer
func get_peer_connection_state(peer_id: int) -> int:
	if peer_signaling_data.has(peer_id):
		return peer_signaling_data[peer_id].connection.get_connection_state()
	return WebRTCPeerConnection.STATE_NEW

# Get all peer connection states for display
func get_all_peer_connection_states() -> Dictionary:
	var states = {}
	for peer_id in peer_signaling_data.keys():
		states[peer_id] = peer_signaling_data[peer_id].connection.get_connection_state()
	return states

# Convert WebRTC state enum to readable string
static func connection_state_to_string(state: int) -> String:
	match state:
		WebRTCPeerConnection.STATE_NEW:
			return "🟡 New"
		WebRTCPeerConnection.STATE_CONNECTING:
			return "🟡 Connecting"
		WebRTCPeerConnection.STATE_CONNECTED:
			return "🟢 Connected"
		WebRTCPeerConnection.STATE_DISCONNECTED:
			return "🔴 Disconnected"
		WebRTCPeerConnection.STATE_FAILED:
			return "❌ Failed"
		WebRTCPeerConnection.STATE_CLOSED:
			return "⚫ Closed"
		_:
			return "❓ Unknown"

# Check if mesh is connected
func is_mesh_connected() -> bool:
	return multiplayer.multiplayer_peer != null and webrtc_multiplayer != null and my_peer_id != 0

# Helper functions for mesh peer ID management
func _generate_mesh_peer_id() -> int:
	# Generate a random peer ID for mesh
	var peer_id = randi() % 1000 + 1

	return peer_id

# Helper functions for remote player management
func _create_remote_player(peer_id: int):
	# Create remote player instance
	var remote_player = preload("res://multiplayer/remote_player.gd").new()
	remote_players[peer_id] = remote_player
	
	# Add to scene (assuming this manager is in the main scene)
	get_tree().current_scene.add_child(remote_player)
	print("Created remote player for peer: ", peer_id)

func _remove_remote_player(peer_id: int):
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
		print("Removed remote player for peer: ", peer_id)
