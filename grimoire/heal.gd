## Ability to heal yourself.
class_name Heal extends Ability

@export var heal_amount: int = 10

func use(caster: Mob, target: Vector2i) -> void:
	# TODO: Implement proper healing logic.
	caster.health += heal_amount
