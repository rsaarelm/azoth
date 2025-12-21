## Persistent player data

extends Node

const SAVE_PATH := "user://savegame.json"

# Character stats
var might := 0
var trickery := 0
var faith := 0
var deftness := 0

# Where does the player spawn at.
# This will get updated to the area and position of the latest checkpoint.
var spawn_area: String
var spawn_pos: Vector2i

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

func _ready():
	if save_exists():
		load_game()
	else:
		clear()

func clear():
	# Reset all player data.
	might = 0
	trickery = 0
	faith = 0
	deftness = 0

	cash = 0

	spawn_area = "res://atlas/sprintmap.tscn"
	spawn_pos = Vector2i(62, 1)

## Get the player's mob node.
func mob():
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes:
		return nodes.front()
	else:
		return null

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

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	var save_dict := {
		player = {
			# Stats
			might = self.might,
			trickery = self.trickery,
			faith = self.faith,
			deftness = self.deftness,

			cash = self.cash,

			# Current location.
			area = spawn_area,
			pos = var_to_str(spawn_pos),
		}
	}

	file.store_line(JSON.stringify(save_dict))

func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_line())
	var save := json.get_data() as Dictionary

	var player = save.player

	might = player.might
	trickery = player.trickery
	faith = player.faith
	deftness = player.deftness

	cash = player.cash

	spawn_area = player.area
	spawn_pos = str_to_var(player.pos)

	Game.restart()

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Delete the current character's save file.
func retire():
	if save_exists():
		DirAccess.remove_absolute(SAVE_PATH)
	clear()
