extends CharacterBody3D

#region 
#Scripts
@export var photo_scorer: PhotoScorer
@onready var health_component: HealthComponent = $HealthComponent
@onready var stamina_component: StaminaComponent = $StaminaComponent
@onready var canvas_layer: CanvasLayer = $CanvasLayer

@export var network_position: Vector3
@export var network_rotation_y: float
@export var network_velocity: Vector3

#Varibles
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

@export_group("Photos and Stuff")
@export var max_photos: int = 5

var current_photo_amount: int = 0
var can_take_pic := true
var total_photo_score: float = 0.0

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

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if not is_multiplayer_authority():
		camera.current = false
		canvas_layer.visible = false
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera.current = true
	
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
	
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(die)
	stamina_component.stamina_changed.connect(_on_stamina_changed)
	
	_on_health_changed(health_component.health, health_component.max_health)
	_on_stamina_changed(stamina_component.stamina, stamina_component.max_stamina)
	
	current_photo_amount = max_photos
	
	photo_scorer.setup(camera, self, min_fov, max_fov)

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
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
	if not is_multiplayer_authority():
		var predicted_position = network_position + network_velocity * 0.05
		
		position = position.lerp(predicted_position, delta * 15.0)
		rotation.y = lerp_angle(rotation.y, network_rotation_y, delta * 15.0)
		return
	
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
	if not is_multiplayer_authority():
		return
	
	low_health_shake_timer -= delta
	
	var health_percent := health_component.get_percent()
	if health_percent <= 0.1 and low_health_shake_timer <= 0.0:
		camera_shake(2, 0.05, false)
		low_health_shake_timer = 1
	
	var can_sprint := (
		current_mode == player_mode.SCOUT
		and Input.is_action_pressed("sprint")
		and stamina_component.has_stamina()
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
		stamina_component.drain(delta)
	else:
		if current_mode != player_mode.CAMERA:
			var mult := crouch_stamina_regen_multiplier if is_crouching else 1.0
			stamina_component.regen(delta, mult)
	
	if not stamina_component.has_stamina():
		can_sprint = false
	
	move_and_slide()
	_apply_headbob(delta)
	_apply_fov(delta, speed)
	
	network_position = global_position
	network_rotation_y = rotation.y
	network_velocity = velocity
	
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

func _on_health_changed(current: float, max_amount: float) -> void:
	health_label.text = str(int(current))
	max_health_label.text = "/" + str(int(max_amount))
	reset_ui_color()

func _on_stamina_changed(current: float, max_amount: float) -> void:
	stamina_label.text = str(int(current))
	max_stamina_label.text = "/" + str(int(max_amount))

func take_damage(damage: int) -> void:
	health_component.take_damage(damage)

func add_health(heal: int) -> void:
	health_component.add_health(heal)

func take_picture():
	if !can_take_pic:
		return
	can_take_pic = false
	
	var monsters_in_photo = photo_scorer.get_monsters_in_frame()
	
	var score = photo_scorer.calculate_photo_score(monsters_in_photo)
	
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
	
	tween.tween_property(self, "camera_zoom_fov", shutter_fov, 0.055).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	tween.tween_property(self, "camera_zoom_fov", original_fov, 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

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
	var health_percent := health_component.get_percent()
	
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
