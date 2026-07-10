extends Node3D
const PLAYER_CONTROLLER = preload("res://Entities/Player/player.tscn")
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var players: Array[CharacterBody3D]

var bird_activated: bool = false

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.lobby_entered.connect(func(): canvas_layer.hide())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Bird-activation"):
		if bird_activated:
			$WorldObjects/Bird.visible = false
			bird_activated = false
		elif !bird_activated:
			$WorldObjects/Bird.visible = true
			bird_activated = true

func on_host_created() -> void:
	#Spawn the server player
	spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(spawn_player)

#The server spawns the player that just connected
func spawn_player(peer_id: int) -> void:
	var new_player := PLAYER_CONTROLLER.instantiate() as CharacterBody3D
	new_player.name = str(peer_id)
	add_child(new_player)
	initialize_player(new_player)

func despawn_player(peer_id: int) -> void:
	var player_node := get_node_or_null(str(peer_id))
	if player_node:
		players.erase(player_node)
		player_node.queue_free()

func initialize_player(player: CharacterBody3D) -> void:
	player.position = $Spawnpoint.position
	for other in players:
		player.add_collision_exception_with(other)
	players.append(player)

func _on_host_pressed() -> void:
	Networking.host_lobby()
	canvas_layer.hide()

func _on_multiplayer_spawner_spawned(node: Node) -> void:
	if node is CharacterBody3D:
		initialize_player(node)
