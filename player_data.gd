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
var last_altar_pos := Vector2i(-1, -1)

var inventory := ItemCollection.new()

# Nullable equipment item slots
var cloak_slot = null
var head_slot = null
var amulet_slot = null

var right_hand_slot = null
var body_slot = null
var left_hand_slot = null

var right_ring_slot = null
var left_ring_slot = null

var cash := 0

## Position where player died and dropped their money.
##
## Either {} or { area, pos, amount }
var corpse_cash_drop = {}

## Memory of explored maps, contains save images from Fog objects. Indexes are area resource paths.
var map_memory: Dictionary = {}

# INVARIANT: You must have at most a single entity, item or mob, spawn per
# cell, since blocklists currently only store locations.

## Spawn points that should no longer be active. Indexes are area resource paths.
var perma_deleted_spawns: Dictionary = {}

## Spawn points that are deactivated for the current run but will reactivate on rest or death.
var soft_deleted_spawns: Dictionary = {}

# There's a planned system for rollbacks on items that needs a third blocklist,
# items that have been picked up but will be removed from your inventory and
# restored to the world if you die and become permanent if you rest. No point
# adding it yet since it also needs a ledger of picked-up and used items.

var abilities: Array[Ability] = [
	# TODO Replace hardcoded temporary test abilities with ones from character
	# build dynamics.
	preload("res://grimoire/armageddon.tres"),
	preload("res://grimoire/firebolt.tres"),
	]

var level:
	get:
		return might + trickery + faith + deftness

var health:
	get:
		# Health is derived from the base stats.
		return 30 + 5 * might + 4 * faith + 4 * deftness + 3 * trickery

func _ready():
	if save_exists():
		load_game()
	else:
		clear()

func clear():
	# Reset all player data.
	# NB. This function must be kept in sync with all the defined fields in PlayerData
	might = 0
	trickery = 0
	faith = 0
	deftness = 0

	cash = 0
	corpse_cash_drop = {}

	spawn_area = "res://atlas/northlands.tscn"
	spawn_pos = Vector2i(57, 36)
	last_altar_pos = Vector2i(57, 35)

	inventory = ItemCollection.new()

	map_memory.clear()
	perma_deleted_spawns.clear()
	soft_deleted_spawns.clear()

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

			corpse_cash_drop = self.corpse_cash_drop,

			inventory = self.inventory.save(),

			# Current location.
			area = spawn_area,
			pos = var_to_str(spawn_pos),
			last_altar_pos = var_to_str(last_altar_pos),
		},

		map_memory = self.map_memory,
		kill_list = self.perma_deleted_spawns,
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
	corpse_cash_drop = player.corpse_cash_drop

	inventory = ItemCollection.load(player.inventory)

	spawn_area = player.area
	spawn_pos = str_to_var(player.pos)
	last_altar_pos = str_to_var(player.last_altar_pos)

	map_memory = save.map_memory

	perma_deleted_spawns = save.kill_list
	soft_deleted_spawns.clear()

	Game.restart()

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

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Delete the current character's save file.
func retire():
	if save_exists():
		DirAccess.remove_absolute(SAVE_PATH)
	clear()

func on_area_entered(area: Area):
	var area_path = area.scene_file_path

	if area_path in map_memory:
		# Load fog of war memory for the area.
		area.fog = Fog.load(map_memory[area_path])

	# Unspawn blocked things.
	if area_path in perma_deleted_spawns:
		for x in perma_deleted_spawns[area_path]:
			var cell = Util.int_to_cell(x)
			area.clear_cell(cell)

	if area_path in soft_deleted_spawns:
		for x in soft_deleted_spawns[area_path]:
			var cell = Util.int_to_cell(x)
			area.clear_cell(cell)

	# If corpse_cash_drop has "area" field that is this area, spawn the cash drop.

	# NB. This must be done after the deleted spawns are cleared so the corpse
	# drop won't get cleared if it happens to be in the same cell as a deleted
	# spawn.
	if corpse_cash_drop.has("area") and corpse_cash_drop.area == area_path:
		var item = Item.make_coins(corpse_cash_drop.amount)
		item.drop(Util.int_to_cell(corpse_cash_drop.pos))

func on_area_exited(area: Area):
	var area_path = area.scene_file_path
	# Save fog of war memory for the area.
	if area.fog:
		map_memory[area_path] = area.fog.save()

func on_enemy_killed(enemy: Mob):
	var area = enemy.area.scene_file_path
	var pos = Util.cell_to_int(enemy.spawn_origin)
	if enemy.has_trait(Mob.CreatureTrait.NO_RESPAWN):
		# Permanently delete a boss enemy.
		perma_deleted_spawns.get_or_add(area, []).append(pos)
	else:
		# Temporarily delete a normal enemy.
		soft_deleted_spawns.get_or_add(area, []).append(pos)
	pass

func on_item_picked_up(_mob: Mob, item: Item):
	var area = _mob.area.scene_file_path
	var origin = Util.cell_to_int(item.spawn_origin)
	# Once you grab it, it's gone for good.
	perma_deleted_spawns.get_or_add(area, []).append(origin)


func on_cash_picked_up(_mob: Mob, item: Item):
	self.cash += item.count

	## If we pick the corpse cash drop, stop spawning it.
	var area = _mob.area.scene_file_path
	if corpse_cash_drop.has("area") and corpse_cash_drop.area == area \
			and Util.int_to_cell(corpse_cash_drop.pos) == item.cell:
		Game.msg("You recover your silver.")
		corpse_cash_drop = {}

func respawn_soft_deleted_spawns():
	soft_deleted_spawns.clear()

## Make all soft deletions permanent, they'll stay dead even when you rest.
func make_soft_deletions_permanent():
	for area in soft_deleted_spawns.keys():
		perma_deleted_spawns.get_or_add(area, []).append_array(
			soft_deleted_spawns[area])
	soft_deleted_spawns.clear()

func drop_cash(area: Area, pos: Vector2i, amount: int):
	assert(amount >= 0)

	if amount == 0:
		corpse_cash_drop = {}
	else:
		corpse_cash_drop = {
			area = area.scene_file_path,
			pos = Util.cell_to_int(pos),
			amount = amount,
		}
