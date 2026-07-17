@tool
extends MeshInstance3D
const size := 256.0

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

# Stubbed for later - structures, villages, foliage, environment go here
# once you've got models to place. Terrain shaping doesn't depend on them.
# @export_group("Structures")
# @export var structures: Array[StructureDefinition]
# @export var villages: Array[StructureDefinition]
#
# @export_group("Foliage")
# @export var foliage: Array[ScatterRule]
#
# @export_group("Environment")
# @export var light_color: Color
# @export var fog_color: Color
# @export var ambient_light_color: Color
# @export var fog_min_range: float
# @export var fog_max_range: float

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
