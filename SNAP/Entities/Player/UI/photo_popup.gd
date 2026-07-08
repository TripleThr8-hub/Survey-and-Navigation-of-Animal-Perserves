extends Control

@onready var label: Label = $Label

func setup(score: int):
	label.text = "+%d" % score
	
	modulate.a = 1.0
	
	var origin := position
	var tween = create_tween()
	
	tween.parallel().tween_property(self, "position:y", position.y -50, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	
	var shake_offsets := [3, -5, 4, -3, 2, -1, 0]
	var step := 0.06 
	
	for x in shake_offsets:
		tween.parallel().tween_property(self,"position:x", origin.x + x, step).set_delay(shake_offsets.find(x) * step)
	
	await tween.finished
	queue_free()
