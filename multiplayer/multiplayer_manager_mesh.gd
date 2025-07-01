extends Node

# TODO: Consider cleaning up peer_connections entries after signaling is complete,
# since they're only needed for WebRTC handshake, not ongoing mesh communication

# Simplified signals - only what we actually need beyond built-in ones
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
	
	# Also poll the mesh multiplayer peer
	if webrtc_multiplayer:
		webrtc_multiplayer.poll()

# Create an invite token for another peer to join the mesh
func create_peer_invite_token():
	# Initialize mesh network if not already started
	if not is_mesh_connected():
		my_peer_id = 1  # Server always has ID 1
		webrtc_multiplayer.create_server()  # Use server mode for automatic peer discovery
		multiplayer.multiplayer_peer = webrtc_multiplayer
	
	# Generate peer ID for the new connection (clients use IDs > 1)
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
	
	# Let WebRTCMultiplayerPeer create the required data channels automatically
	# According to Godot docs: "Three channels will be created for reliable, unreliable, and ordered transport"
	# Don't create channels manually - add_peer() will handle this
	
	# Add to mesh network BEFORE creating offer - this sets up data channels
	webrtc_multiplayer.add_peer(peer_connection, new_peer_id)
	
	# Create offer
	peer_connection.create_offer()

# Join the mesh using an invite token
func join_mesh_with_token(invite_token: String):
	# Decode the token
	var token_data = _decode_token(invite_token)
	if not token_data:
		print("Error: Invalid mesh invite token")
		connection_failed.emit()
		return
	
	# Set up our client with the ID from the token
	my_peer_id = int(token_data.get("peer_id"))
	if not my_peer_id or my_peer_id <= 1:  # Client IDs must be > 1
		print("Error: Invalid peer_id in token (must be > 1 for clients)")
		connection_failed.emit()
		return
	
	webrtc_multiplayer.create_client(my_peer_id)  # Use client mode for automatic peer discovery
	multiplayer.multiplayer_peer = webrtc_multiplayer
	
	# Get the server's ID (always 1) - this is who we connect to
	var server_peer_id = 1  # In client/server mode, we only connect to the server
	
	# Create peer connection to the server
	var peer_connection = _create_peer_connection()
	
	# Store peer signaling data for the server connection
	peer_signaling_data[server_peer_id] = {
		"connection": peer_connection,
		"session": {"type": "", "sdp": "", "ice_candidates": []}
	}
	
	peer_connection.session_description_created.connect(_on_session_created.bind(server_peer_id))
	peer_connection.ice_candidate_created.connect(_on_ice_candidate_created.bind(server_peer_id))
	
	# In client mode, we only add the server peer (ID 1)
	# The MultiplayerAPI will handle discovery of other clients automatically
	webrtc_multiplayer.add_peer(peer_connection, server_peer_id)
	
	# Set remote description from token
	peer_connection.set_remote_description(token_data.type, token_data.sdp)
	
	# Add ICE candidates from token
	for candidate in token_data.ice_candidates:
		peer_connection.add_ice_candidate(candidate.media, candidate.index, candidate.name)

# Complete mesh connection with response token
func complete_mesh_connection_with_token(response_token: String):
	# Decode response token
	var token_data = _decode_token(response_token)
	if not token_data:
		print("Error: Invalid mesh response token")
		connection_failed.emit()
		return
	
	# Find the peer connection for this response
	var expected_peer_id = int(token_data.get("sender_id", 0))  # The peer who sent the answer (convert to int)
	
	if not peer_signaling_data.has(expected_peer_id):
		print("Error: No peer connection found for peer ID: ", expected_peer_id)
		connection_failed.emit()
		return
	
	var peer_connection = peer_signaling_data[expected_peer_id].connection
	
	# Set remote description (answer) to complete connection
	peer_connection.set_remote_description(token_data.type, token_data.sdp)
	
	# Add ICE candidates
	for candidate in token_data.ice_candidates:
		peer_connection.add_ice_candidate(candidate.media, candidate.index, candidate.name)
	


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
	# Find the peer connection and set local description
	if not peer_signaling_data.has(peer_id):
		print("Error: No peer connection found for peer ID: ", peer_id)
		connection_failed.emit()
		return
	
	# Store session data for this specific peer
	peer_signaling_data[peer_id].connection.set_local_description(type, sdp)
	peer_signaling_data[peer_id].session["type"] = type
	peer_signaling_data[peer_id].session["sdp"] = sdp
	
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
	else:  # answer
		token_data["peer_id"] = peer_id  # Who we're responding to
		token_data["sender_id"] = my_peer_id  # We are sending the answer
	
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
	# Create remote player directly when peer connects
	# With server relay, all peer discovery is handled automatically by MultiplayerAPI
	_create_remote_player(peer_id)

func _on_peer_disconnected(peer_id: int):
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

# Helper functions for client peer ID management
func _generate_mesh_peer_id() -> int:
	# Generate client peer ID (must be > 1, server is always 1)
	var peer_id = randi() % 1000 + 2  # Start from 2 to avoid server ID
	return peer_id

# Helper functions for remote player management
func _create_remote_player(peer_id: int):
	# Create remote player instance
	var remote_player = preload("res://multiplayer/remote_player.gd").new()
	remote_players[peer_id] = remote_player
	
	# Add to scene (assuming this manager is in the main scene)
	get_tree().current_scene.add_child(remote_player)

func _remove_remote_player(peer_id: int):
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
