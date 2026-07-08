extends CharacterBody3D

enum monster_state {
	IDLE,
	EATING,
	SLEEPING,
	ATTACKING
}

enum rarity {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY
}

enum animal_type {
	MAMMAL,
	REPTILE,
	BIRD,
	ARACHNID
}

@export var current_animal_type: animal_type = animal_type.MAMMAL
@export var current_state := monster_state.IDLE

@export var current_rarity: rarity = rarity.COMMON

func _ready() -> void:
	current_rarity = roll_rairity()

func get_rarity_multiplier() -> float:
	match current_rarity:
		rarity.COMMON:
			return 1.0
		rarity.UNCOMMON:
			return 1.2
		rarity.RARE:
			return 1.7
		rarity.LEGENDARY:
			return 2.5
	return 1.0

func roll_rairity() -> rarity:
	var roll := randf()
	
	if roll < 0.60:
		return rarity.COMMON
	elif roll < 0.85:
		return rarity.UNCOMMON
	elif roll < 0.97:
		return rarity.RARE
	else:
		return rarity.LEGENDARY
