## Kill everything ability
class_name Armageddon
extends Ability

@export var power: int = 9999


func use(caster: Mob, _target: Vector2i) -> void:
	# Deal damage to all mobs that are not the caster.
	if !await Game.confirm("Really kill everyone?"):
		return
	for mob in caster.get_tree().get_nodes_in_group("mob"):
		if mob != caster:
			mob.take_damage(power)
	Game.msg("Kaboom.")
