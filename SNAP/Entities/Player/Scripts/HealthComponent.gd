class_name HealthComponent
extends Node

signal health_changed(current: float, max: float)
signal died

@export var max_health: float = 100.0
var health: float

const VALUE_CAP := 999.0

func _ready() -> void:
	health = max_health
	_clamp_values()
	health_changed.emit(health, max_health)

func take_damage(damage: int) -> void:
	health -= damage
	_clamp_values()
	
	health_changed.emit(health, max_health)
	
	if health <= 0:
		died.emit()

func add_health(heal: int) -> void:
	health += heal
	_clamp_values()
	
	health_changed.emit(health, max_health)

func get_percent() -> float:
	return health / max_health

func _clamp_values() -> void:
	max_health = min(max_health, VALUE_CAP)
	health = clamp(health, 0.0, max_health)
