extends Node

var is_initialized := false

func _ready() -> void:
	var init_response: Dictionary = Steam.steamInitEx(480, true)
	print("Did Steam initialize?: %s" % init_response)

	if init_response["status"] == 0:
		is_initialized = true
	else:
		is_initialized = false
		push_error("Failed to initialize Steam. Status: %s, Verbose: %s" % [init_response["status"], init_response["verbal"]])

func _process(_delta: float) -> void:
	Steam.run_callbacks()
