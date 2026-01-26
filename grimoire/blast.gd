## Ranged attack ability.
class_name Blast
extends Ability

@export var power: int = 5


func use(_caster: Mob, target: Vector2i) -> void:
	var mob = Game.area().mob_at(target)

	if mob:
		mob.take_damage(power)
	else:
		Game.msg("The blast hits nothing.")
