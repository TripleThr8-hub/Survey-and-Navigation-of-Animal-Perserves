extends Node3D
const PLAYER_CONTROLLER = preload("res://Entities/Player/player.tscn")
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var terrain: MeshInstance3D = $Terrain

var players: Array[CharacterBody3D]
var bird_activated: bool = false
var world_seed: int = 0

@export var world_environment: WorldEnvironment

@export var map_half_size := 224.0

@export var fog_start_distance := 150.0

@export var normal_fog_density := 0.05
@export var max_fog_density := 1.0

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.lobby_entered.connect(func(): canvas_layer.hide())

func _process(delta):
	if players.is_empty():
		return
	
	# Find the local player
	var local_player : CharacterBody3D = null
	
	for player in players:
		if player.is_multiplayer_authority():
			local_player = player
			break
	
	if local_player == null:
		return
	
	update_border_fog(local_player)

func on_host_created() -> void:
	# Host decides the terrain seed for this session, once.
	world_seed = randi()
	terrain.world_seed = world_seed

	spawn_player(multiplayer.get_unique_id())
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(despawn_player)

func _on_peer_connected(peer_id: int) -> void:
	# Give the new peer the seed before/with their player spawn,
	# so anyone joining mid-session still gets identical terrain.
	rpc_id(peer_id, "receive_world_seed", world_seed)
	spawn_player(peer_id)

@rpc("authority", "reliable")
func receive_world_seed(seed_value: int) -> void:
	world_seed = seed_value
	terrain.world_seed = seed_value # setter chain regenerates mesh + scatter locally

func spawn_player(peer_id: int) -> void:
	var new_player := PLAYER_CONTROLLER.instantiate() as CharacterBody3D
	new_player.name = str(peer_id)
	add_child(new_player, true)
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

func update_border_fog(player: CharacterBody3D):
	
	var edge_distance = max(
		abs(player.global_position.x),
		abs(player.global_position.z)
	)
	
	var t = inverse_lerp(
		fog_start_distance,
		map_half_size,
		edge_distance
	)
	
	t = clamp(t, 0.0, 1.0)
	
	# Smooth curve
	t = t * t
	
	world_environment.environment.volumetric_fog_density = lerp(
		normal_fog_density,
		max_fog_density,
		t
	)
