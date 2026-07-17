class_name BiomeProfile
extends Resource

@export var biome_id: String
@export var display_name: String

@export_group("Base")
@export var base_enabled: bool = true
@export_range(0.0, 64.0, 0.5) var base_amplitude: float = 4.0
@export_range(0.0001, 0.1, 0.0001) var base_frequency: float = 0.01

@export_group("Rolling Hills")
@export var hills_enabled: bool = false
@export_range(0.0, 64.0, 0.5) var hills_amplitude: float = 3.0
@export_range(0.0001, 0.1, 0.0001) var hills_frequency: float = 0.03

@export_group("Mountains")
@export var mountains_enabled: bool = false
@export_range(0.0, 128.0, 0.5) var mountains_amplitude: float = 32.0
@export_range(0.0001, 0.1, 0.0001) var mountains_frequency: float = 0.008

@export_group("Crevasses")
@export var crevasses_enabled: bool = false
@export_range(0.0, 64.0, 0.5) var crevasses_amplitude: float = 16.0
@export_range(0.0001, 0.1, 0.0001) var crevasses_frequency: float = 0.02

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
