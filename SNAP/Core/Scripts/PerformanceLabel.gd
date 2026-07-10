extends Label

var showing: bool = false

func _ready() -> void:
	self.visible = false
	showing = false

func _process(_delta):
	if Input.is_action_just_pressed("TEMP_SHOW_PERFORMANCE"):
		if !showing:
			showing = true
			self.visible = true
		elif showing:
			showing = false
			self.visible = false
	
	
	var fps = Engine.get_frames_per_second()
	var frame_time = 1000.0 / fps if fps > 0 else 0
	
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
	
	var memory_static = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
	var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphan_nodes = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vertices = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	
	text = """
-------- DIAGNOSTICS --------

PERFORMANCE
FPS: %s
Frame Time: %.2f ms
Process Time: %.2f ms
Physics Time: %.2f ms

RENDERING
Draw Calls: %s
Primitives: %s

SCENE
Objects: %s
Nodes: %s
Orphan Nodes: %s

MEMORY
Static Memory: %.2f MB

ENGINE
Time Scale: %.2f
Physics Ticks: %s
""" % [
		fps,
		frame_time,
		process_time,
		physics_time,
		draw_calls,
		vertices,
		object_count,
		node_count,
		orphan_nodes,
		memory_static,
		Engine.time_scale,
		Engine.physics_ticks_per_second
	]
