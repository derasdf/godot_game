extends Node

@onready var main_menu = $CanvasLayer/main_menu
@onready var addres_entery = $CanvasLayer/main_menu/MarginContainer/VBoxContainer/addres_entery
@onready var health_bar = $CanvasLayer/hud/HealthBar
@onready var hud = $CanvasLayer/hud
@onready var hitrect = $CanvasLayer/hud/hitrect
@onready var lobby = $CanvasLayer/lobby
@onready var upgrade_picker = $CanvasLayer/upgrade_picker
@onready var win_loss = $CanvasLayer/hud/win_loss
@onready var win_timer = $Win_Timer
@onready var bg_canvas = $CanvasLayer/BG_canvas
@onready var upgrades = $CanvasLayer/upgrade_picker/MarginContainer/VBoxContainer/upgrades
@onready var shield_cooldown = $CanvasLayer/hud/MarginContainer/HSplitContainer/shield_cooldown
@onready var reloading = $CanvasLayer/hud/MarginContainer/HSplitContainer/reloading

var packed_upgrades = [
	"enrage",
	"thiccening",
	"pisser"
]

const Player = preload("res://scenes/character.tscn")
const PORT = 1337
var enet_peer = ENetMultiplayerPeer.new()
var connected_peer_ids = []
var amount_ready := 0
var local_player
var seeed = "sneed"

func _ready():
	seed(hash(seeed))
	
func game_start():
	#lobby.hide()
	bg_canvas.hide()
	hud.show()	

func _unhandled_input(_event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_b_pressed():
	main_menu.hide()
	#lobby.show()
	
	enet_peer.create_server(PORT)
	
	if enet_peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Connection Failed")
		return
	
	multiplayer.multiplayer_peer = enet_peer
	#multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_connected.connect(
		func(new_peer_id):
			rpc("add_newly_connected_player_character", new_peer_id)
			#rpc_id(new_peer_id, "add_previously_connected_player_characters", connected_peer_ids)
			add_player(new_peer_id)
	)
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.server_disconnected.connect(server_delete)
	add_player(1)
	#lobby.add_player(1,str(1))
	
	game_start()

	
func server_delete():
	pass	

@rpc	
func add_newly_connected_player_character(new_peer_id):
	add_player(new_peer_id)

func _on_join_b_pressed():
	main_menu.hide()
	#lobby.show()
	enet_peer.create_client("localhost", PORT)#address_entry.text
	multiplayer.multiplayer_peer = enet_peer
	#lobby.rpc("set_player_name", str(local_player))
	game_start()
	#seed(hash(seeed))
	
func add_player(peer_id):
	connected_peer_ids.append(peer_id)
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
		player.block_emit.connect(update_block_bar)
		player.reloading_emit.connect(update_reloading_bar)
	if peer_id == multiplayer.get_unique_id():	
		local_player = player

func remove_player(peer_id):
	var player_id = get_node_or_null(str(peer_id))
	if player_id:
		player_id.queue_free()
		
func update_block_bar(time_percent):	
	shield_cooldown.value = time_percent

func update_reloading_bar(time_percent):	
	reloading.value = time_percent
	
func update_health_bar(health_value):
	health_bar.value = health_value
	if health_value <= 0:
		hitrect.visible = true
		win_loss.visible = true
		win_loss.text  = "L"
		win_timer.start()
		rpc("game_stop")

	else:
		hitrect.visible = true
		await get_tree().create_timer(0.2).timeout
		hitrect.visible = false


func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
	
@rpc("any_peer")
func game_stop():
		win_loss.visible = true
		win_loss.text  = "W"
		win_timer.start()


var up_scene= []
func _on_win_timer_timeout():

	win_timer.stop()
	hitrect.visible = false
	win_loss.visible = false
	hud.hide()
	bg_canvas.show()
	
	for i in range(3):
		var x = randi() % packed_upgrades.size()
		up_scene.append(load("res://powerups/"+packed_upgrades[x]+".tscn").instantiate())
		upgrades.add_child(up_scene[i])
	upgrade_picker.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	#remove_player(player.name)


func _on_choiche_1_button_up():
	up_scene[0].rpc("execute", local_player)
	upgrade_picker.hide()
	continue_game()
	#wait_queue.rpc()
	

func _on_choiche_2_button_up():
	up_scene[1].rpc("execute",  local_player)
	upgrade_picker.hide()
	continue_game()
	#wait_queue.rpc()


func _on_choiche_3_button_up():
	up_scene[2].rpc("execute", local_player)
	upgrade_picker.hide()
	continue_game()
	#wait_queue.rpc()
	
@rpc("call_local")	
func wait_queue():
	amount_ready += 1
	if amount_ready == connected_peer_ids.size():
		continue_game()
	
func continue_game():
	for i in range(3):	
		up_scene[i].queue_free()
	up_scene.clear()
	bg_canvas.hide()
	health_bar.value = local_player.HEALTH_MAX
	local_player.HEALTH = local_player.HEALTH_MAX
	local_player.ammo_mag = local_player.ammo_mag_max
	local_player.position = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	local_player.is_dead = false
	seed(hash(seeed))
	#add_player(multiplayer.get_unique_id())
	hud.show()	

