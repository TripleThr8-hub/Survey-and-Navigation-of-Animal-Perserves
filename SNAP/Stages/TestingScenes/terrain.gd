@tool
extends MeshInstance3D
const size := 256.0

@export_range(4, 256, 4) var resolution := 32:
	set(new_resolution):
		resolution = new_resolution
		update_mesh()

@export var biome_pool: Array[BiomeProfile]:
	set(new_pool):
		biome_pool = new_pool
		_pick_biome()
		update_mesh()

@export var world_seed := 0:
	set(new_seed):
		world_seed = new_seed
		_pick_biome()
		update_mesh()

## Quick global multiplier for overall scale tuning, on top of each category's own amplitude.
@export_range(0.1, 4.0, 0.1) var height_multiplier := 1.0:
	set(new_mult):
		height_multiplier = new_mult
		update_mesh()

var active_biome: BiomeProfile

# One internal noise generator per landform category. Frequency/seed get
# refreshed whenever the active biome or world_seed changes, so no noise
# resources need to be dragged around in the inspector - it's all driven
# by the plain numbers on BiomeProfile, matching the reference script.
var _base_noise := FastNoiseLite.new()
var _hills_noise := FastNoiseLite.new()
var _mountains_noise := FastNoiseLite.new()
var _crevasses_noise := FastNoiseLite.new()

func _pick_biome() -> void:
	if biome_pool.is_empty():
		active_biome = null
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	active_biome = biome_pool[rng.randi() % biome_pool.size()]

	if not active_biome:
		return

	# Offset each category's seed so Base/Hills/Mountains/Crevasses don't
	# all produce identical bumps when they share the same world_seed.
	_base_noise.seed = world_seed
	_base_noise.frequency = active_biome.base_frequency

	_hills_noise.seed = world_seed + 1
	_hills_noise.frequency = active_biome.hills_frequency

	_mountains_noise.seed = world_seed + 2
	_mountains_noise.frequency = active_biome.mountains_frequency

	_crevasses_noise.seed = world_seed + 3
	_crevasses_noise.frequency = active_biome.crevasses_frequency

func get_height(x: float, y: float) -> float:
	if not active_biome:
		return 0.0
	var h := 0.0
	if active_biome.base_enabled:
		h += _base_noise.get_noise_2d(x, y) * active_biome.base_amplitude
	if active_biome.hills_enabled:
		h += _hills_noise.get_noise_2d(x, y) * active_biome.hills_amplitude
	if active_biome.mountains_enabled:
		h += _mountains_noise.get_noise_2d(x, y) * active_biome.mountains_amplitude
	if active_biome.crevasses_enabled:
		h += _crevasses_noise.get_noise_2d(x, y) * active_biome.crevasses_amplitude
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
		var normal := Vector3.UP
		var tangent := Vector3.RIGHT
		if active_biome:
			vertex.y = get_height(vertex.x, vertex.z)
			normal = get_normal(vertex.x, vertex.z)
			tangent = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4 * i] = tangent.x
		tangent_array[4 * i + 1] = tangent.y
		tangent_array[4 * i + 2] = tangent.z

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	mesh = array_mesh

	_update_collision(array_mesh)

func _update_collision(source_mesh: ArrayMesh) -> void:
	var static_body := get_node_or_null("StaticBody3D")
	if not static_body:
		return
	var collision_shape: CollisionShape3D = static_body.get_node_or_null("CollisionShape3D")
	if not collision_shape:
		return
	collision_shape.shape = source_mesh.create_trimesh_shape()
