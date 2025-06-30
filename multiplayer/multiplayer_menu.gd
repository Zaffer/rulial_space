extends Control

class_name CustomMultiplayerMenu

var multiplayer_manager: Node
var is_menu_open: bool = false
var connected_peers: Dictionary = {}  # peer_id -> peer_data

# UI references
@onready var close_btn: Button = $Panel/MarginContainer/VBoxContainer/MenuButtonsContainer/CloseBtn

# Invite/Response section
@onready var paste_invite_btn: Button = $Panel/MarginContainer/VBoxContainer/ConnectSection/InviteSection/InviteButtonsContainer/PasteInviteBtn
@onready var create_invite_btn: Button = $Panel/MarginContainer/VBoxContainer/ConnectSection/InviteSection/InviteButtonsContainer/CreateInviteBtn
@onready var invite_token_field: TextEdit = $Panel/MarginContainer/VBoxContainer/ConnectSection/InviteSection/InviteTokenField

@onready var response_token_field: TextEdit = $Panel/MarginContainer/VBoxContainer/ConnectSection/ResponseSection/ResponseTokenField
@onready var copy_response_btn: Button = $Panel/MarginContainer/VBoxContainer/ConnectSection/ResponseSection/ResponseButtonsContainer/CopyResponseBtn
@onready var paste_response_btn: Button = $Panel/MarginContainer/VBoxContainer/ConnectSection/ResponseSection/ResponseButtonsContainer/PasteResponseBtn
@onready var clear_tokens_btn: Button = $Panel/MarginContainer/VBoxContainer/ConnectSection/ResponseSection/ClearTokensBtn

# Connections list
@onready var connections_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ConnectionsSection/ConnectionsList
@onready var no_connections_label: Label = $Panel/MarginContainer/VBoxContainer/ConnectionsSection/ConnectionsList/NoConnectionsLabel

func _ready():
	visible = false
	_connect_signals()

func _connect_signals():
	# UI signals
	close_btn.pressed.connect(toggle_menu)
	paste_invite_btn.pressed.connect(_on_paste_invite_pressed)
	create_invite_btn.pressed.connect(_on_create_invite_pressed)
	copy_response_btn.pressed.connect(_on_copy_response_pressed)
	paste_response_btn.pressed.connect(_on_paste_response_pressed)
	clear_tokens_btn.pressed.connect(_on_clear_tokens_pressed)

func setup_multiplayer_manager(manager: Node):
	multiplayer_manager = manager
	# Connect to multiplayer manager signals
	multiplayer_manager.invite_token_ready.connect(_on_invite_token_ready)
	multiplayer_manager.response_token_ready.connect(_on_response_token_ready)
	multiplayer_manager.connection_established.connect(_on_connection_established)
	multiplayer_manager.connection_failed.connect(_on_connection_failed)
	multiplayer_manager.peer_joined.connect(_on_peer_joined)
	multiplayer_manager.peer_left.connect(_on_peer_left)

func toggle_menu():
	is_menu_open = !is_menu_open
	visible = is_menu_open
	
	if is_menu_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_update_connections_display()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# === UI EVENT HANDLERS ===

func _on_paste_invite_pressed():
	var clipboard_text = DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.length() > 0:
		invite_token_field.text = clipboard_text
		
		# If this is a valid invite, start generating response immediately
		if _is_valid_invite_token(clipboard_text):
			paste_invite_btn.disabled = true
			create_invite_btn.disabled = true
			paste_invite_btn.text = "⏳ Generating Response..."
			multiplayer_manager.join_mesh_with_token(clipboard_text)

func _on_create_invite_pressed():
	# If button shows "Copy Invite", copy it
	if create_invite_btn.text == "Copy Invite 📋":
		DisplayServer.clipboard_set(invite_token_field.text)
		create_invite_btn.text = "✅ Copied!"
		await get_tree().create_timer(1.0).timeout
		create_invite_btn.text = "Copy Invite 📋"
		return
	
	# Otherwise create new invite
	create_invite_btn.disabled = true
	paste_invite_btn.disabled = true
	create_invite_btn.text = "⏳ Generating Invite..."
	
	# Manager will start mesh automatically if needed
	multiplayer_manager.create_peer_invite_token()

func _on_copy_response_pressed():
	DisplayServer.clipboard_set(response_token_field.text)
	copy_response_btn.text = "✅ Copied!"
	await get_tree().create_timer(1.0).timeout
	copy_response_btn.text = "Copy Response 📤"

func _on_paste_response_pressed():
	var clipboard_text = DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.length() > 0 and _is_valid_response_token(clipboard_text):
		response_token_field.text = clipboard_text
		paste_response_btn.disabled = true
		copy_response_btn.disabled = true
		paste_response_btn.text = "⏳ Connecting..."
		multiplayer_manager.complete_mesh_connection_with_token(clipboard_text)
	else:
		paste_response_btn.text = "❌ Invalid Token"
		await get_tree().create_timer(1.0).timeout
		paste_response_btn.text = "Paste Response 📥"

func _on_clear_tokens_pressed():
	invite_token_field.text = ""
	response_token_field.text = ""
	# Reset all buttons to default state
	create_invite_btn.text = "Create Invite 📤"
	create_invite_btn.disabled = false
	paste_invite_btn.text = "Paste Invite 📥"
	paste_invite_btn.disabled = false
	copy_response_btn.disabled = true
	paste_response_btn.disabled = false

# === MULTIPLAYER SIGNAL HANDLERS ===

func _on_invite_token_ready(token: String):
	invite_token_field.text = token
	create_invite_btn.text = "Copy Invite 📋"
	create_invite_btn.disabled = false
	paste_invite_btn.disabled = true

func _on_response_token_ready(token: String):
	response_token_field.text = token
	paste_invite_btn.text = "✅ Response Ready!"
	copy_response_btn.disabled = false
	await get_tree().create_timer(1.5).timeout
	paste_invite_btn.text = "Paste Invite 📥"
	paste_invite_btn.disabled = true
	create_invite_btn.disabled = true

func _on_connection_established():
	paste_response_btn.text = "✅ Connected!"
	await get_tree().create_timer(1.5).timeout
	paste_response_btn.text = "Paste Response 📥"
	paste_response_btn.disabled = false
	copy_response_btn.disabled = false

func _on_connection_failed():
	create_invite_btn.text = "❌ Failed"
	paste_invite_btn.text = "❌ Failed" 
	paste_response_btn.text = "❌ Failed"
	await get_tree().create_timer(1.5).timeout
	# Reset to default states
	create_invite_btn.text = "Create Invite 📤"
	create_invite_btn.disabled = false
	paste_invite_btn.text = "Paste Invite 📥"
	paste_invite_btn.disabled = false
	paste_response_btn.text = "Paste Response 📥"
	paste_response_btn.disabled = false

func _on_peer_joined(peer_id: int):
	connected_peers[peer_id] = {"id": peer_id, "status": "🟢 Connected"}
	_update_connections_display()

func _on_peer_left(peer_id: int):
	connected_peers.erase(peer_id)
	_update_connections_display()

func _is_valid_invite_token(token: String) -> bool:
	var json_string = Marshalls.base64_to_utf8(token)
	if json_string == "":
		return false
	
	var data = JSON.parse_string(json_string)
	return data != null and data.has("type") and data.has("sdp") and data.type == "offer"

func _is_valid_response_token(token: String) -> bool:
	var json_string = Marshalls.base64_to_utf8(token)
	if json_string == "":
		return false
	
	var data = JSON.parse_string(json_string)
	return data != null and data.has("type") and data.has("sdp") and data.type == "answer"

func _update_connections_display():
	# Clear existing connection displays (except the "No connections" label)
	var children = connections_list.get_children()
	for child in children:
		if child != no_connections_label:
			child.queue_free()
	
	# Show/hide "No connections" label
	no_connections_label.visible = connected_peers.is_empty()
	
	# Add connection entries
	for peer_id in connected_peers:
		var peer_data = connected_peers[peer_id]
		_create_connection_entry(peer_data)

func _create_connection_entry(peer_data: Dictionary):
	var entry = HBoxContainer.new()
	
	# Peer info label
	var info_label = Label.new()
	info_label.text = "Peer " + str(peer_data.id) + " - " + peer_data.status
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_child(info_label)
	
	# Status indicator
	var status_label = Label.new()
	status_label.text = "🟢" if peer_data.status == "Connected" else "🔴"
	entry.add_child(status_label)
	
	connections_list.add_child(entry)
