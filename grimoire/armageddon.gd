## Kill everything ability
class_name Armageddon extends Ability

@export var damage: int = 9999

func use(caster: Mob, _target: Vector2i) -> void:
	# Deal damage to all mobs that are not the caster.
	for mob in caster.get_tree().get_nodes_in_group("mob"):
		if mob != caster:
			mob.take_damage(damage)
