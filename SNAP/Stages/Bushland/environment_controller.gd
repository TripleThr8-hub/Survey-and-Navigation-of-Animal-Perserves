extends WorldEnvironment

@export_group("Fog")
@export var fog_enabled := true
@export var fog_color := Color("08080dff")
@export var fog_density := 0.006

@export_group("Lighting")
@export var ambient_light := Color(0.15, 0.15, 0.2)

func _ready():
	apply_environment()

func apply_environment():
	if environment == null:
		environment = Environment.new()
	
	environment.fog_enabled = fog_enabled
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient_light
