extends CharacterBody2D

const SPEED := 500.0

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _physics_process(delta: float) -> void:
	# First check if we have authority over this player
	if not is_multiplayer_authority():
		return
	
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED
	
	move_and_slide()
