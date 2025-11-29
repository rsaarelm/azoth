## Persistent player data

extends Node

# Character stats
var might := 0
var trickery := 0
var faith := 0
var deftness := 0

# Where does the player spawn at.
# This will get updated to the area and position of the latest checkpoint.
var spawn_area := "res://atlas/sprintmap.tscn"
var spawn_pos := Vector2i(62, 1)

var level:
	get:
		return might + trickery + faith + deftness

var health:
	get:
		# Health is derived from the base stats.
		return 30 + 5 * might + 4 * faith + 4 * deftness + 3 * trickery

var cash := 0

var abilities: Array[Ability] = [
	# TODO Replace hardcoded temporary test abilities with ones from character
	# build dynamics.
	preload("res://grimoire/armageddon.tres"),
	preload("res://grimoire/firebolt.tres"),
	]

## Get the player's mob node.
func mob():
	return get_tree().get_nodes_in_group("player").front()

## Instantiate a new player Mob.
func build() -> Mob:
	var player = preload("res://bestiary/player.tscn").instantiate()

	# Urgh, I guess I need this so far to align it to the cell center.
	player.position = Area.CELL / 2

	# Apply stats.
	player.health = health
	player.strength = 10 + might

	return player

## Level up the persistent player.
##
## The player mob must be reconstructed with `build` before the effects show
## up. Return false if you don't have money to level up.
func level_up() -> bool:
	var cost = Rules.level_up_cost(self.level + 1)
	if cash >= cost:
		cash -= cost
		# No stat selection yet, just pump up strength.
		might += 1
		return true
	return false
