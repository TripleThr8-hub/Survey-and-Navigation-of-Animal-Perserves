class_name StructureDefinition
extends Resource

@export_group("Identity")
@export var enabled: bool = true
@export var structure_id: String
@export var scene: PackedScene

@export_group("Placement")
@export var random_y_rotation: bool = true
@export var scale_range := Vector2(0.9, 1.1)
## Nudges instances up/down from the sampled ground height - use this if
## the structure's mesh pivot isn't at its base, so it sinks into or
## floats above the terrain.
@export var height_offset: float = 0.0

@export_group("Distribution")
## Base probability an eligible cell spawns an instance (0-1)
@export_range(0.0, 1.0, 0.01) var density := 0.05
## Grid spacing for candidate points - smaller = denser possible packing, more cost
@export_range(0.5, 32.0, 0.5) var cell_size := 8.0

@export_group("Terrain")
@export var min_height := -1000.0
@export var max_height := 1000.0
@export_range(0.0, 90.0, 1.0) var min_slope_deg := 0.0
@export_range(0.0, 90.0, 1.0) var max_slope_deg := 30.0

@export_group("Overlap Rules")
## Minimum distance from any other already-placed structure
## (any type, not just this one) - keeps trees from spawning inside rocks, etc.
@export_range(0.0, 64.0, 0.5) var min_distance_to_others := 4.0
