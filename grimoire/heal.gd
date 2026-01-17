## Ability to heal yourself.
class_name Heal extends Ability

@export var power: int = 10

func use(caster: Mob, _target: Vector2i) -> void:
	caster.wounds = max(0, caster.wounds - power)
