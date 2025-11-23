## Ranged attack ability.
class_name Blast extends Ability

@export var damage: int = 5

func use(caster: Mob, target: Vector2i) -> void:
	var mob = Game.area().mob_at(target)

	if mob:
		mob.take_damage(damage)
	else:
		Game.msg("The blast hits nothing.")
