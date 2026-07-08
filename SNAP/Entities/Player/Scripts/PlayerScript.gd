extends CharacterBody3D

#region Variables
@export_group("Movement")
@export var move_speed: float = 3.5
@export var sprint_speed: float = 7.0
@export var jump_force: float = 8.5
@export_range(0.001, 0.01, 0.0001) var mouse_sensitivity: float = 0.005

@export var fall_multiplier: float = 2.5
@export var ascend_multiplier: float = 2.0

@export_group("Crouch")
@export var crouch_speed_multiplier := 0.45
@export var crouch_stamina_regen_multiplier := 2.0
@export var standing_height := 0.6
@export var crouching_height := -0.5

var is_crouching := false

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 10.0
@export var stamina_regen_rate: float = 10.0
@export var stamina_delay: float = 1.0

var stamina: float
var stamina_timer: float = 0.0

@export_group("Health")
@export var max_health: float = 100.0

var health: float

@export_group("Photos and Stuff")
@export var max_photos: int = 5

var current_photo_amount: int = 0
var can_take_pic := true
var total_photo_score: float = 0.0
var photographed_monsters: Dictionary = {}

@export_category("Camera Feel Good")
@export_group("FOV")
@export var base_fov: float = 75.0
@export var fov_change: float = 1.5

@export_group("Bob")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.1
@export var bob_fade_speed: float = 8.0

var t_bob: float = 0.0
var bob_intensity: float = 0.0
var original_cam_pos: Vector3
var original_pivot_pos: Vector3

@export_group("Sway")
@export var sway_amount := 0.0
@export var sway_target := 0.0
@export var sway_strength := 0.0015
@export var sway_max := 0.05
@export var sway_return_speed := 8.0
@export var camera_lag_speed := 12.0

@export var camera_move_speed := 1.0
@export var camera_sensitivity_divider := 2.0

var target_yaw: float = 0.0
var current_yaw: float = 0.0

var target_pitch: float = 0.0
var current_pitch: float = 0.0

var target_fov: float

var camera_zoom_fov: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

@export_category("UI Stuff")

@export_group("Scout")
@export var stamina_label: Label
@export var health_label: Label
@export var max_stamina_label: Label
@export var max_health_label: Label
@export var scout_ui: Control

@export_group("Camera")
@export var photo_amount_label: Label
@export var camera_ui: Control
@export var gear_texture: Sprite2D
@export var camera_flash: ColorRect

var shake_tween: Tween

@export_group("Pupup")
@export var popup_packed_scene: PackedScene
@export var popup_container: Control

@export_group("UI Elements")
@export var gear_rotation_speed: float = .1
@export var min_fov := 30.0
@export var max_fov := 75.0

var gear_rotation_current := 0.0
var gear_rotation_target := 0.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var vertical_rotation: float = 0.0

var low_health_shake_timer := 0.0

enum player_mode {SCOUT, CAMERA}
var current_mode: player_mode = player_mode.SCOUT
#endregion

func _ready() -> void:
	scout_ui.modulate = Color("ffb347")
	camera_ui.modulate = Color("6aaae6")
	camera_flash.visible = true
	camera_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	camera_flash.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	original_cam_pos = camera.position
	original_pivot_pos = camera_pivot.position
	camera.fov = base_fov
	update_player_ui()
	
	target_yaw = rotation.y
	current_yaw = rotation.y
	
	target_pitch = 0.0
	current_pitch = 0.0
	
	target_fov = base_fov
	
	camera_zoom_fov = base_fov
	
	stamina = max_stamina
	health = max_health
	current_photo_amount = max_photos

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sensitivity := mouse_sensitivity
		
		if current_mode == player_mode.CAMERA:
			sensitivity /= camera_sensitivity_divider
		
		target_yaw -= event.relative.x * sensitivity
		
		target_pitch -= event.relative.y * sensitivity
		target_pitch = clampf(target_pitch, -PI / 2.0, PI / 2.0)
		
		sway_target = clamp(
			-event.relative.x * sway_strength,
			-sway_max,
			sway_max
		)
	
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event.is_action_pressed("mode_change"):
		if current_mode == player_mode.SCOUT:
			current_mode = player_mode.CAMERA
			target_fov = camera_zoom_fov
			gear_rotation_current = 0.0
			gear_rotation_target = 0.0
		else:
			current_mode = player_mode.SCOUT
			target_fov = base_fov
			camera_zoom_fov = base_fov
			gear_rotation_current = 0.0
			gear_rotation_target = 0.0
		update_player_ui()
	
	if event is InputEventMouseButton and current_mode == player_mode.CAMERA:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom_fov  = clampf(camera_zoom_fov - 5.0, 30.0, base_fov)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom_fov  = clampf(camera_zoom_fov + 5.0, 30.0, base_fov)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if current_photo_amount > 0:
				take_picture()
			else:
				camera_shake(2, 0.02, true)
	
	if event.is_action_pressed("crouch"):
		is_crouching = true
	
	if event.is_action_released("crouch"):
		is_crouching = false
	
	if event.is_action_pressed("test_damage"):
		take_damage(10)
	
	if event.is_action_pressed("test_heal"):
		add_health(10)

func _process(delta: float) -> void:
	current_yaw = lerp_angle(
		current_yaw,
		target_yaw,
		delta * camera_lag_speed
	)
	
	current_pitch = lerp(
		current_pitch,
		target_pitch,
		delta * camera_lag_speed
	)
	
	rotation.y = current_yaw
	camera_pivot.rotation.x = current_pitch
	
	sway_amount = lerp(sway_amount, sway_target, delta * 15.0)
	sway_target = lerp(sway_target, 0.0, delta * sway_return_speed)
	camera.rotation.z = sway_amount
	
	var target_height := standing_height
	
	if is_crouching:
		target_height = crouching_height
	
	camera_pivot.position.y = lerp(
		camera_pivot.position.y,
		target_height,
		delta * 10
	)
	
	if current_mode == player_mode.CAMERA:
		target_fov = camera_zoom_fov
		
		var zoom_t := inverse_lerp(max_fov, min_fov, camera_zoom_fov)
		gear_rotation_target = zoom_t * TAU * 0.5
		
		gear_rotation_current = lerp(
			gear_rotation_current,
			gear_rotation_target,
			delta * 10.0
		)
		
		gear_texture.rotation = gear_rotation_current

func _physics_process(delta: float) -> void:
	if max_health > 999: #MIGHT NEED TO CHANGE IN THE FUTURE FOR PERFORMANCE
		max_health = 999
	if health > 999:
		health = 999
	
	if max_stamina > 999:
		max_stamina = 999
	if stamina > 999:
		stamina = 999
	
	var health_percent := health / max_health
	low_health_shake_timer -= delta
	
	if health_percent <= 0.1 and low_health_shake_timer <= 0.0:
		camera_shake(2, 0.05, false)
		low_health_shake_timer = 1
	
	var can_sprint := (
		current_mode == player_mode.SCOUT
		and Input.is_action_pressed("sprint")
		and stamina > 0.0
	)
	
	var speed: float
	if current_mode == player_mode.CAMERA:
		speed = camera_move_speed
	else:
		speed = sprint_speed if can_sprint else move_speed
	
	if is_crouching and current_mode == player_mode.SCOUT:
		speed *= crouch_speed_multiplier
	
	# Gravity with better feeling fall curve
	if not is_on_floor():
		var multiplier := fall_multiplier if velocity.y < 0.0 else ascend_multiplier
		velocity.y -= gravity * multiplier * delta
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
	
	# Movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis.x * input_dir.x + transform.basis.z * input_dir.y).normalized()
	
	if is_on_floor():
		velocity.x = direction.x * speed if direction else move_toward(velocity.x, 0.0, speed)
		velocity.z = direction.z * speed if direction else move_toward(velocity.z, 0.0, speed)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 4.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 4.0)
	
	if can_sprint and direction != Vector3.ZERO:
		stamina -= stamina_drain_rate * delta
		stamina = max(stamina, 0.0)
		stamina_timer = stamina_delay
	else:
		if stamina_timer > 0.0:
			stamina_timer -= delta
		else:
			if current_mode != player_mode.CAMERA:
				var regen_rate := stamina_regen_rate
				
				if is_crouching:
					regen_rate *= crouch_stamina_regen_multiplier
				
				stamina += regen_rate * delta
				stamina = min(stamina, max_stamina)
	
	if stamina <= 0.0:
		can_sprint = false
	
	move_and_slide()
	_apply_headbob(delta)
	_apply_fov(delta, speed)
	
	stamina_label.text = str(int(stamina))
	health_label.text = str(int(health))
	max_stamina_label.text = "/" + str(int(max_stamina))
	max_health_label.text = "/" + str(int(max_health))
	
	photo_amount_label.text = str(current_photo_amount) + " Photos Left"

func _apply_headbob(delta: float) -> void:
	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var target_intensity: float = 1.0 if (is_on_floor() and flat_speed > 0.05) else 0.0
	bob_intensity = lerp(bob_intensity, target_intensity, delta * bob_fade_speed)
	
	t_bob += delta * flat_speed
	camera.position = original_cam_pos + Vector3(
		cos(t_bob * bob_frequency * 0.5) * bob_amplitude * bob_intensity,
		sin(t_bob * bob_frequency) * bob_amplitude * bob_intensity,
		0.0
	)

func _apply_fov(delta: float, current_speed: float) -> void:
	var flat_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_fov := base_fov + fov_change * clampf(flat_speed, 0.0, current_speed)
	if current_mode != player_mode.CAMERA:
		target_fov = lerp(target_fov, speed_fov, delta * 2.0)
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

func update_player_ui():
	scout_ui.visible = current_mode == player_mode.SCOUT
	camera_ui.visible = current_mode == player_mode.CAMERA

func take_damage(damage: int) -> void:
	health -= damage
	health = max(health, 0)
	
	reset_ui_color()
	
	if health <= 0:
		die()

func add_health(heal: int) -> void:
	health += heal
	
	if health >= max_health:
		health = max_health
	
	reset_ui_color()

func take_picture():
	if !can_take_pic:
		return
	can_take_pic = false
	
	var monsters_in_photo = get_monsters_in_frame()
	
	var score = calculate_photo_score(monsters_in_photo)
	
	camera_shutter_animation()
	camera_flash_screen()
	show_photo_popup(score)
	
	await get_tree().create_timer(.2).timeout
	
	total_photo_score += score
	current_photo_amount -= 1
	
	can_take_pic = true

func camera_flash_screen():
	camera_flash.visible = true
	camera_flash.color = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	
	tween.tween_property(camera_flash, "color:a", 1.0, 0.02)
	tween.tween_property(camera_flash, "color:a", 0.0, 0.15)
	
	
	await tween.finished
	camera_flash.visible = false

func camera_shutter_animation():
	var original_fov := camera_zoom_fov
	
	var punch_amount := original_fov * 0.07
	var shutter_fov := original_fov - punch_amount
	
	var tween := create_tween()
	
	tween.tween_property(self, "camera_zoom_fov", shutter_fov, 0.055) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	tween.tween_property(self, "camera_zoom_fov", original_fov, 0.2) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func is_monster_visible(monster: Node3D) -> bool:
	var points = monster.get_node("PhotoPoints").get_children()
	
	for point in points:
		if is_photo_point_visible(point, monster):
			return true
	
	return false
 
func calculate_photo_score(monsters: Array) -> int:
	var total_score: float = 0.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	
	for monster in monsters:
		if not is_instance_valid(monster):
			continue
		
		var photo_point: Node3D = get_best_photo_point(monster)
		
		if photo_point == null:
			continue
		
		# --- HARD GATE 1: behind camera ---
		var to_point := photo_point.global_position - camera.global_position
		var forward := -camera.global_transform.basis.z
		if forward.dot(to_point.normalized()) < 0.15:
			continue
		
		# --- HARD GATE 2: outside viewport ---
		var screen_pos: Vector2 = camera.unproject_position(photo_point.global_position)
		if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
			continue
		
		# --- HARD GATE 3: occluded by geometry ---
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position,
			photo_point.global_position
		)
		query.exclude = [self]
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit["collider"] != monster and not hit["collider"].is_in_group("monsters") and not hit["collider"].is_ancestor_of(monster):
				continue
		
		var times_shot: int = photographed_monsters.get(monster, 0)
		var repeat_multiplier: float = pow(0.75, times_shot)
		photographed_monsters[monster] = times_shot + 1
		
		# --- SOFT METRIC: centering (0 → 1) ---
		var center_point = monster.get_node("PhotoPoints/Center")
		var animal_screen_pos = camera.unproject_position(center_point.global_position)
		
		var offset: Vector2 = animal_screen_pos - viewport_center
		var max_dist: float = viewport_center.length()  # corner distance
		var center_score: float = 1.0 - clampf(offset.length() / max_dist, 0.0, 1.0)
		# Mild curve — rewards center without brutally punishing slight offsets
		center_score = pow(center_score, 1.8)
		
		# --- SOFT METRIC: distance (0 → 1) ---
		# Sweet spot around 5–12 units. Falls off steeply beyond 25, gently below 3.
		var dist: float = camera.global_position.distance_to(monster.get_node("PhotoPoints/Center").global_position)
		var distance_score: float
		if dist < 1.0:
			distance_score = 0.0 # Too close
		elif dist <= 8.0:
			distance_score = smoothstep(1.0, 8.0, dist) # Ramps up nicely
		else:
			distance_score = 1.0 - clampf((dist - 8.0) / 20.0, 0.0, 1.0)
			distance_score = pow(distance_score, 1.5)
		
		# --- SOFT METRIC: zoom (0 → 1) ---
		# More zoom = higher bonus, but only if the monster is actually framed
		var zoom_score: float = inverse_lerp(max_fov, min_fov, camera.fov)
		zoom_score = clampf(zoom_score, 0.0, 1.0)
		
		# --- COMBINE (weighted) ---
		var visibility_score := 1.0
		
		match monster.current_animal_type:
			monster.animal_type.MAMMAL:
				visibility_score = calculate_mammal_visibility(monster)
			monster.animal_type.REPTILE:
				visibility_score = calculate_reptile_visibility(monster)
			monster.animal_type.BIRD:
				visibility_score = calculate_bird_visibility(monster)
			monster.animal_type.ARACHNID:
				pass
		
		var shot_score: float = (
			center_score * 0.5 +
			distance_score * 0.3 +
			zoom_score * 0.2 
		) * 100.0
		
		shot_score *= visibility_score
		
		var rarity_multiplier: float = 1.0
		
		if monster.has_method("get_rarity_multiplier"):
			rarity_multiplier = monster.get_rarity_multiplier()
		
		shot_score *= rarity_multiplier
		
		var state_score: float = 0.0
		match monster.current_state:
			monster.monster_state.IDLE:
				state_score = 0
			monster.monster_state.EATING:
				state_score = 100
			monster.monster_state.SLEEPING:
				state_score = 50
			monster.monster_state.ATTACKING:
				state_score = 200
		
		var final_score = (shot_score + state_score) * repeat_multiplier
		total_score += final_score
	
	return int(total_score)

func calculate_mammal_visibility(monster: Node3D) -> float:
	var points = monster.get_node("PhotoPoints").get_children()
	
	var total_weight := 0.0
	var visible_weight := 0.0
	
	var weights = {
		"Head": 40,
		"Chest": 25,
		"Center": 20,
		"Hip": 10,
		"FrontRightLeg": 2,
		"FrontLeftLeg": 2,
		"BackRightLeg": 2,
		"BackLeftLeg": 2,
		"TailBase": 3,
		"TailTip": 3
	}
	
	for point in points:
		if weights.has(point.name):
			total_weight += weights[point.name]
			var am_visible = is_photo_point_visible(point, monster)
			if am_visible:
				visible_weight += weights[point.name]
	
	if total_weight == 0:
		return 0.0
	
	return visible_weight / total_weight

func calculate_reptile_visibility(monster: Node3D) -> float:
	var points = monster.get_node("PhotoPoints").get_children()
	
	var total_weight := 0.0
	var visible_weight := 0.0
	
	var weights = {
		"Head": 40,
		"Chest": 20,
		"Center": 15,
		"Hip": 10,
		"TailBase": 10,
		"TailTip": 5
	}
	
	for point in points:
		if weights.has(point.name):
			total_weight += weights[point.name]
			var am_visible = is_photo_point_visible(point, monster)
			if am_visible:
				visible_weight += weights[point.name]
	
	if total_weight == 0:
		return 0.0
	
	return visible_weight / total_weight

func calculate_bird_visibility(monster: Node3D) -> float:
	var points = monster.get_node("PhotoPoints").get_children()
	
	var total_weight := 0.0
	var visible_weight := 0.0
	
	var weights = {
		"Head": 30,
		"Chest": 20,
		"Center": 15,
		"Hip": 10,
		"RightWing": 15,
		"LeftWing": 15,
		"RightLeg": 3,
		"LeftLeg": 3,
		"TailBase": 5,
		"TailTip": 4
	}
	
	for point in points:
		if weights.has(point.name):
			total_weight += weights[point.name]
			var am_visible = is_photo_point_visible(point, monster)
			if am_visible:
				visible_weight += weights[point.name]
	
	if total_weight == 0:
		return 0.0
	
	return visible_weight / total_weight

func get_monsters_in_frame() -> Array:
	var visible_monsters: Array = []
	
	for monster in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(monster):
			continue
		
		if is_monster_visible(monster):
			visible_monsters.append(monster)
	
	return visible_monsters

func is_photo_point_visible(point: Node3D, monster: Node3D) -> bool:
	var to_point := point.global_position - camera.global_position
	var forward := -camera.global_transform.basis.z
	
	if forward.dot(to_point.normalized()) < 0.15:
		return false
	
	var screen_pos := camera.unproject_position(point.global_position)
	var viewport_size := get_viewport().get_visible_rect().size
	
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x:
		return false
	if screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return false
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point.global_position)
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	
	if not hit.is_empty():
		var collider = hit["collider"]
		if collider != monster \
		and not collider.is_in_group("monsters") \
		and not collider.is_ancestor_of(monster):
			return false
	
	return true

func get_best_photo_point(monster: Node3D) -> Node3D:
	var points = monster.get_node("PhotoPoints").get_children()
	
	var best_point: Node3D = null
	var best_score := -1.0
	
	var viewport_size := get_viewport().get_visible_rect().size
	var viewport_center := viewport_size * 0.5
	
	for point in points:
		if not is_photo_point_visible(point, monster):
			continue
		
		var screen_pos := camera.unproject_position(point.global_position)
		
		var offset = screen_pos.distance_to(viewport_center)
		var center_score = 1.0 - clampf(offset / viewport_center.length(), 0.0, 1.0)
		
		if center_score > best_score:
			best_score = center_score
			best_point = point
	
	return best_point

func show_photo_popup(score: int):
	var popup = popup_packed_scene.instantiate()
	popup_container.add_child(popup)
	
	popup.position = Vector2(600 + randf_range(-35, 35), 250 + randf_range(-35, 35))
	popup.setup(score)

func camera_shake(strength: int, step: float, no_photo: bool):
	if shake_tween:
		shake_tween.kill()
	
	var ui := get_current_ui()
	
	ui.position = Vector2.ZERO
	shake_tween = create_tween()
	
	var origin := Vector2.ZERO
	
	if no_photo:
		camera_ui.modulate = Color("c93830ff")
	
	for i in 7:
		var offset := Vector2(
			randi_range(-strength, strength),
			randi_range(-strength, strength)
		)
		shake_tween.tween_property(ui, "position", origin + offset, step)
	
	shake_tween.tween_property(ui, "position", origin, step)
	
	if no_photo:
		await shake_tween.finished
		reset_ui_color()

func get_current_ui() -> Control:
	return scout_ui if current_mode == player_mode.SCOUT else camera_ui

func reset_ui_color():
	var health_percent := health / max_health
	
	if health_percent <= 0.1:
		scout_ui.modulate = Color("c93830ff")
		camera_ui.modulate = Color("6544a7ff")
	elif health_percent <= 0.3:
		scout_ui.modulate = Color("ff8748ff")
		camera_ui.modulate = Color("5d76cfff")
	else:
		scout_ui.modulate = Color("ffb347ff")
		camera_ui.modulate = Color("6aaae6")

func die():
	print("The player will die here frfr")
