class_name StaminaComponent
extends Node

signal stamina_changed(current: float, max: float)

@export var max_stamina: float = 100.0
@export var drain_rate: float = 10.0
@export var regen_rate: float = 10.0
@export var regen_delay: float = 1.0

var stamina: float
var _regen_timer: float = 0.0

const VALUE_CAP := 999.0

func _ready() -> void:
	stamina = max_stamina
	_clamp_values()
	stamina_changed.emit(stamina, max_stamina)

func drain(delta: float) -> void:
	stamina -= drain_rate * delta
	_clamp_values()
	_regen_timer = regen_delay
	stamina_changed.emit(stamina, max_stamina)

func regen(delta: float, multiplier: float = 1.0) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return
	
	stamina += regen_rate * multiplier * delta
	_clamp_values()
	stamina_changed.emit(stamina, max_stamina)

func has_stamina() -> bool:
	return stamina > 0.0

func _clamp_values() -> void:
	max_stamina = min(max_stamina, VALUE_CAP)
	stamina = clamp(stamina, 0.0, max_stamina)
