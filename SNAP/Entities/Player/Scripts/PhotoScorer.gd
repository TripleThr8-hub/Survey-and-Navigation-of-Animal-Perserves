class_name PhotoScorer
extends Resource

var camera: Camera3D
var exclude_node: Node
var min_fov: float
var max_fov: float

var photographed_monsters: Dictionary = {}


func setup(_camera: Camera3D, _exclude_node: Node, _min_fov: float, _max_fov: float):
	camera = _camera
	exclude_node = _exclude_node
	min_fov = _min_fov
	max_fov = _max_fov

func is_monster_visible(monster: Node3D) -> bool:
	var points = monster.get_node("PhotoPoints").get_children()
	
	for point in points:
		if is_photo_point_visible(point, monster):
			return true
	
	return false
 
func calculate_photo_score(monsters: Array) -> int:
	var total_score: float = 0.0
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
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
		var space_state := camera.get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			camera.global_position,
			photo_point.global_position
		)
		query.exclude = [exclude_node]
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
	
	for monster in exclude_node.get_tree().get_nodes_in_group("monsters"):
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
	var viewport_size := camera.get_viewport().get_visible_rect().size
	
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x:
		return false
	if screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return false
	
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, point.global_position)
	query.exclude = [exclude_node]
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
	
	var viewport_size := camera.get_viewport().get_visible_rect().size
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
