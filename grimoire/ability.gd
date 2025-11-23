class_name Ability
extends Resource

## Base class for abilities the mobs can use.

@export var display_name := "Unnamed Ability"

## How far can the ability reach. If 0, the ability is not targeted.
@export_range(0, 100, 1) var range: int = 0

@export var icon: Texture2D

## Method that specfies what happens when the ability is used.
func use(caster: Mob, target: Vector2i) -> void:
	assert(false, "Ability.use is an abstract method")

func needs_aiming() -> bool:
	return range > 0
