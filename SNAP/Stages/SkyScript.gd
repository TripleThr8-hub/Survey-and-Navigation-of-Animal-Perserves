extends MeshInstance3D

## Height above the player to keep the sky plane
@export var sky_height: float = 100.0

var target_player: Node3D = null

func _process(_delta: float) -> void:
	if not is_instance_valid(target_player):
		_find_local_player()
		return

	global_position.x = target_player.global_position.x
	global_position.z = target_player.global_position.z
	global_position.y = target_player.global_position.y + sky_height


func _find_local_player() -> void:
	# Adjust the group name / node path to match how your players are set up
	for player in get_tree().get_nodes_in_group("players"):
		if player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority():
			target_player = player
			return
