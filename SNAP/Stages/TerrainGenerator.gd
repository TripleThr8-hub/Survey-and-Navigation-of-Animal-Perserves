@tool
extends MeshInstance3D
const size := 256.0

@export_group("Structures")
## One entry per structure type - click + to add another, then fill in
## its Identity/Placement/Distribution/Terrain/Overlap Rules.
@export var structures: Array[StructureDefinition]:
	set(new_structures):
		structures = new_structures
		_rescatter()

# Same idea as Structures above, but meshes only (no collision) - for
# pure decoration like grass, small rocks, background trees. Click + to
# add another mesh slot.
@export_group("Foliage")
@export var foliage_meshes: Array[Mesh] = []:
	set(new_meshes):
		foliage_meshes = new_meshes
		_rescatter()

## Base probability an eligible cell spawns an instance (0-1)
@export_range(0.0, 1.0, 0.01) var foliage_density := 0.1
## Grid spacing for candidate points - smaller = denser possible packing, more cost
@export_range(0.5, 32.0, 0.5) var foliage_cell_size := 4.0
@export var foliage_min_height := -1000.0
@export var foliage_max_height := 1000.0
@export_range(0.0, 90.0, 1.0) var foliage_min_slope_deg := 0.0
@export_range(0.0, 90.0, 1.0) var foliage_max_slope_deg := 45.0
@export var foliage_scale_range := Vector2(0.8, 1.2)
@export var foliage_random_y_rotation := true

@export var biome_id: String
@export var display_name: String

# Each category now has a min/max range instead of a fixed number. The
# actual value used each generation is rolled randomly from that range,
# seeded off world_seed - so the same biome (same categories active,
# same rough character) still looks meaningfully different every time
# Host is clicked, instead of just shifting the same shapes around.
@export_group("Base")
@export var base_enabled: bool = true
@export var base_amplitude_range := Vector2(2.0, 6.0)
@export var base_frequency_range := Vector2(0.005, 0.02)

@export_group("Rolling Hills")
@export var hills_enabled: bool = false
@export var hills_amplitude_range := Vector2(2.0, 5.0)
@export var hills_frequency_range := Vector2(0.02, 0.04)

@export_group("Mountains")
@export var mountains_enabled: bool = false
@export var mountains_amplitude_range := Vector2(16.0, 48.0)
@export var mountains_frequency_range := Vector2(0.004, 0.012)

@export_group("Crevasses")
@export var crevasses_enabled: bool = false
@export var crevasses_amplitude_range := Vector2(8.0, 24.0)
@export var crevasses_frequency_range := Vector2(0.012, 0.03)

# Stubbed for later - villages, environment go here once you've got
# models/design ready. Terrain shaping doesn't depend on them.
# @export_group("Villages")
# @export var villages: Array[StructureDefinition]
#
# @export_group("Environment")
# @export var light_color: Color
# @export var fog_color: Color
# @export var ambient_light_color: Color
# @export var fog_min_range: float
# @export var fog_max_range: float

@export_group("Other Stuff")
@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		update_mesh()

@export var world_seed := 0:
	set(new_seed):
		world_seed = new_seed
		_randomize_parameters()
		_update_noise_seeds()
		update_mesh()

## Quick global multiplier for overall scale tuning, on top of each category's own amplitude.
@export_range(0.1, 4.0, 0.1) var height_multiplier := 1.0:
	set(new_mult):
		height_multiplier = new_mult
		update_mesh()

# Rolled once per world_seed from the ranges above - these are what
# get_height() actually reads, not the exported ranges directly.
var _base_amplitude := 0.0
var _base_frequency := 0.0
var _hills_amplitude := 0.0
var _hills_frequency := 0.0
var _mountains_amplitude := 0.0
var _mountains_frequency := 0.0
var _crevasses_amplitude := 0.0
var _crevasses_frequency := 0.0

# One internal noise generator per landform category. Seeds refresh
# whenever world_seed changes; frequency is read fresh each call so a
# rerolled frequency takes effect the next time the mesh rebuilds.
var _base_noise := FastNoiseLite.new()
var _hills_noise := FastNoiseLite.new()
var _mountains_noise := FastNoiseLite.new()
var _crevasses_noise := FastNoiseLite.new()

func _ready() -> void:
	_randomize_parameters()
	_update_noise_seeds()
	update_mesh()

func _randomize_parameters() -> void:
	# Each category gets its own RNG stream (offset from world_seed) so
	# rerolling one category's range doesn't shift the others' results.
	var rng := RandomNumberGenerator.new()

	rng.seed = world_seed
	_base_amplitude = rng.randf_range(base_amplitude_range.x, base_amplitude_range.y)
	_base_frequency = rng.randf_range(base_frequency_range.x, base_frequency_range.y)

	rng.seed = world_seed + 100
	_hills_amplitude = rng.randf_range(hills_amplitude_range.x, hills_amplitude_range.y)
	_hills_frequency = rng.randf_range(hills_frequency_range.x, hills_frequency_range.y)

	rng.seed = world_seed + 200
	_mountains_amplitude = rng.randf_range(mountains_amplitude_range.x, mountains_amplitude_range.y)
	_mountains_frequency = rng.randf_range(mountains_frequency_range.x, mountains_frequency_range.y)

	rng.seed = world_seed + 300
	_crevasses_amplitude = rng.randf_range(crevasses_amplitude_range.x, crevasses_amplitude_range.y)
	_crevasses_frequency = rng.randf_range(crevasses_frequency_range.x, crevasses_frequency_range.y)

func _update_noise_seeds() -> void:
	# Offset each category's seed so Base/Hills/Mountains/Crevasses don't
	# all produce identical bumps when they share the same world_seed.
	_base_noise.seed = world_seed
	_hills_noise.seed = world_seed + 1
	_mountains_noise.seed = world_seed + 2
	_crevasses_noise.seed = world_seed + 3

func get_height(x: float, y: float) -> float:
	var h := 0.0
	if base_enabled:
		_base_noise.frequency = _base_frequency
		h += _base_noise.get_noise_2d(x, y) * _base_amplitude
	if hills_enabled:
		_hills_noise.frequency = _hills_frequency
		h += _hills_noise.get_noise_2d(x, y) * _hills_amplitude
	if mountains_enabled:
		_mountains_noise.frequency = _mountains_frequency
		h += _mountains_noise.get_noise_2d(x, y) * _mountains_amplitude
	if crevasses_enabled:
		_crevasses_noise.frequency = _crevasses_frequency
		h += _crevasses_noise.get_noise_2d(x, y) * _crevasses_amplitude
	return h * height_multiplier

func get_normal(x: float, y: float) -> Vector3:
	var epsilon := size / resolution
	var normal := Vector3(
		(get_height(x + epsilon, y) - get_height(x - epsilon, y)) / (2.0 * epsilon),
		1,
		(get_height(x, y + epsilon) - get_height(x, y - epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()

func update_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.subdivide_depth = resolution
	plane.subdivide_width = resolution
	plane.size = Vector2(size, size)

	var plane_arrays = plane.get_mesh_arrays()
	var vertex_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array: PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array: PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]

	for i: int in vertex_array.size():
		var vertex := vertex_array[i]
		vertex.y = get_height(vertex.x, vertex.z)
		var normal := get_normal(vertex.x, vertex.z)
		var tangent := normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh

	_update_collision(array_mesh)
	_rescatter()

func _update_collision(source_mesh: ArrayMesh) -> void:
	# Skip in the editor - collision data is only needed at runtime, and
	# generating it here embeds a large trimesh shape into the .tscn on
	# every save while you're just previewing terrain shapes.
	if Engine.is_editor_hint():
		return
	var static_body := get_node_or_null("StaticBody3D")
	if not static_body:
		return
	var collision_shape: CollisionShape3D = static_body.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		return
	collision_shape.shape = source_mesh.create_trimesh_shape()

func _rescatter() -> void:
	for child in get_children():
		if child.name.begins_with("Foliage_") or child.name.begins_with("Structure_"):
			remove_child(child)
			child.queue_free()

	for i in foliage_meshes.size():
		var m := foliage_meshes[i]
		if m:
			_scatter_mesh(m, i)

	# Shared across all structure definitions so Overlap Rules can check
	# distance against structures placed by *other* definitions too, not
	# just repeats of the same one.
	var placed_positions: Array[Vector3] = []
	for i in structures.size():
		var def := structures[i]
		if def and def.enabled and def.scene:
			_scatter_structure(def, i, placed_positions)

func _scatter_structure(def: StructureDefinition, index: int, placed_positions: Array[Vector3]) -> void:
	# Same deterministic-per-slot seeding as foliage, offset further so
	# structures and foliage never roll the same sequence of positions.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(world_seed, index + 5000))

	var half := size / 2.0
	var count := 0

	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var px := x + rng.randf_range(0.0, def.cell_size)
			var pz := z + rng.randf_range(0.0, def.cell_size)

			if px < half and pz < half and rng.randf() <= def.density:
				var h := get_height(px, pz)
				if h >= def.min_height and h <= def.max_height:
					var normal := get_normal(px, pz)
					var slope_deg := rad_to_deg(acos(normal.dot(Vector3.UP)))
					if slope_deg >= def.min_slope_deg and slope_deg <= def.max_slope_deg:
						var candidate := Vector3(px, h + def.height_offset, pz)
						if _far_enough(candidate, placed_positions, def.min_distance_to_others):
							var instance := def.scene.instantiate()
							add_child(instance)
							if instance is Node3D:
								instance.position = candidate
								if def.random_y_rotation:
									instance.rotation.y = rng.randf_range(0.0, TAU)
								var s := rng.randf_range(def.scale_range.x, def.scale_range.y)
								instance.scale = Vector3(s, s, s)
							instance.name = "Structure_%s_%d" % [def.structure_id, count]
							count += 1
							if Engine.is_editor_hint():
								instance.owner = get_tree().edited_scene_root
							placed_positions.append(candidate)
			z += def.cell_size
		x += def.cell_size

func _far_enough(candidate: Vector3, placed_positions: Array[Vector3], min_distance: float) -> bool:
	if min_distance <= 0.0:
		return true
	for p in placed_positions:
		if candidate.distance_to(p) < min_distance:
			return false
	return true

func _scatter_mesh(m: Mesh, index: int) -> void:
	# Distinct deterministic RNG stream per mesh slot, seeded off world_seed.
	# Same world_seed -> same terrain -> same scatter, on every machine.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(world_seed, index + 1000))

	var half := size / 2.0
	var transforms: Array[Transform3D] = []

	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var px := x + rng.randf_range(0.0, foliage_cell_size)
			var pz := z + rng.randf_range(0.0, foliage_cell_size)

			if px < half and pz < half and rng.randf() <= foliage_density:
				var h := get_height(px, pz)
				if h >= foliage_min_height and h <= foliage_max_height:
					var normal := get_normal(px, pz)
					var slope_deg := rad_to_deg(acos(normal.dot(Vector3.UP)))
					if slope_deg >= foliage_min_slope_deg and slope_deg <= foliage_max_slope_deg:
						var t := Transform3D(Basis(), Vector3(px, h, pz))
						if foliage_random_y_rotation:
							t = t.rotated_local(Vector3.UP, rng.randf_range(0.0, TAU))
						var s := rng.randf_range(foliage_scale_range.x, foliage_scale_range.y)
						t = t.scaled_local(Vector3(s, s, s))
						transforms.append(t)
			z += foliage_cell_size
		x += foliage_cell_size

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Foliage_%d" % index
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	add_child(mmi)
	if Engine.is_editor_hint():
		mmi.owner = get_tree().edited_scene_root
