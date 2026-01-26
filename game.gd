extends Node
## Global access game singleton.

## Cached current area.
## Do not set from outside Game.
var _area: Area = null

## State variable for abilities being aimed.
var aim_ability: Ability = null:
	set(value):
		get_tree().current_scene.aim_ability = value

## Things that go in a save game.
var state := SaveState.new()

#region Time management

var is_paused := true

## Toggle variable for pausing, we want actual pause switch to happen at
## Game._process and nowhere else to control when the other _process calls see
## the game as running.
var pause_requested = null


func _process(_delta: float) -> void:
	if !is_paused:
		# Unless the leader is doing a long move, pause a running game right
		# again.
		if leader() and !leader().has_goal():
			is_paused = true

	# Always listen to toggling the pause. If the player isn't acting, the
	# toggle serves as a "pass turn" command.
	if Input.is_action_just_pressed("toggle_pause") and pause_requested == null:
		is_paused = !is_paused

	# Apply deferred pause request.
	match pause_requested:
		null:
			# No change requested
			pass
		true:
			is_paused = true
			pause_requested = null
		false:
			is_paused = false
			pause_requested = null


## Start running logic after player turn
func start_running():
	pause_requested = false


## Start running logic after player turn
func stop_running():
	pause_requested = true
#endregion

#region Game loop control

## Reset levels and respawn player to last checkpoint.
##
## If `retain_player` is true, the player's injuries and status effects are
## sustained.
func restart():
	# Restarting is baked into GameScreen's initialization routine, so we just
	# reload the scene here.
	get_tree().change_scene_to_file("res://game_screen.tscn")


func player_rests(altar_pos: Vector2i):
	var player = leader()

	var altar_location = player.area.get_location(altar_pos)

	if altar_location != state.last_altar_location:
		# Make changes permanent when you successfully reach a new altar.
		make_soft_kills_permanent()
	else:
		# Respawn enemies if you just circle back to the same altar.
		respawn_soft_kills()

	state.last_altar_location = altar_location
	state.spawn_location = _area.get_location(player.cell)

	# Make sure the hook runs before making a save game.
	if _area:
		on_area_exited(_area)

	Save.write(state)

	# Show transition screen.
	get_tree().change_scene_to_file("res://resting.tscn")
	await get_tree().create_timer(1.0).timeout

	restart()


func player_died():
	var player = leader()

	# Drop your cash on death.
	Game.msg("You died.")
	if state.cash > 0:
		state.corpse_cash_location = _area.get_location(player.cell)
		state.corpse_cash_amount = state.cash
		Game.msg("You dropped " + str(state.cash) + "$.")

	state.cash = 0

	if _area:
		on_area_exited(_area)

	# Respawn enemies when you die.
	respawn_soft_kills()
	Save.write(state)

	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file("res://you_died.tscn")
	await get_tree().create_timer(1.0).timeout
	restart()


## Load a new area and place the player in the given pos.
##
## If player is unspecified, pull out the existing player.
func load_area(scene_path: String, player_pos: Vector2i, player: Mob = null):
	var frame = get_tree().current_scene.find_child("AreaFrame", true, false)
	frame.load_area(scene_path, player_pos, player)


func respawn_soft_kills():
	for a in state.areas:
		state.areas[a].soft_kills.clear()


## Make all soft deletions permanent, they'll stay dead even when you rest.
func make_soft_kills_permanent():
	for a in state.areas:
		state.areas[a].finalize_soft_kills()


func retire():
	Save.delete()
	state = SaveState.new()

#endregion

#region Area management
func get_area_state(a: Area = null) -> AreaState:
	var area_path = _area.scene_file_path
	if a:
		area_path = a.scene_file_path
	if not state.areas.has(area_path):
		state.areas[area_path] = AreaState.new()
	return state.areas[area_path]


## Apply changes made previously during the game to the area being entered.
func on_area_entered(a: Area):
	# XXX: There's a glitch with the joystick's repeat where the player often
	# moves an extra step immediately after entering a new area. Add the delay
	# here to avoid that.
	Joystick.delay()

	_area = a

	# Apply saved changes to area.
	var area_state = get_area_state()
	area_state.apply_to(_area)

	# If there's a live cash drop in this area, spawn that.

	# NB. This must be done after running despawns so the corpse drop won't
	# get cleared even if it happens to be in the same cell as an item
	# despawn.

	var area_path = _area.scene_file_path
	if state.corpse_cash_location and \
	area_path == state.corpse_cash_location.area:
		var pos = state.corpse_cash_location.cell
		var item = ItemNode.new(
			Item.make_coins(
				state.corpse_cash_amount,
			),
		)
		item.drop(pos)

	# Light up the active altar.
	# If current altar is on this area and there's a valid altar tile in the position,
	# turn the tile into ACTIVE_ALTAR.
	if state.last_altar_location and \
	state.last_altar_location.area == area_path:
		var altar_pos = state.last_altar_location.cell
		a.make_altar_lit(altar_pos)


func on_area_exited(a: Area):
	# Save fog of war memory for the area.
	var area_state = get_area_state(a)
	area_state.map_memory = a.dump_fog()

#endregion

#region Game rules
## Get the current leader mob (directly controlled player character).
## This may be different than the main player character if a minion NPC
## is temporarily assigned to lead the team.
func leader() -> Mob:
	var nodes = get_tree().get_nodes_in_group("player")
	if nodes:
		return nodes.front()
	return null


func build_player() -> Mob:
	var player = preload("res://bestiary/player.tscn").instantiate()

	# Align to cell center.
	player.position = Area.CELL / 2

	# Apply stats.
	# We probably want to do more here in the future.
	player.health = state.player_stats.health
	player.strength = 10 + state.player_stats.might

	return player


func area() -> Area:
	return _area


func add_cash(amount: int) -> void:
	assert(amount >= 0)
	state.cash += amount


func player_cash() -> int:
	return state.cash


func player_level() -> int:
	return state.player_stats.level


func level_up() -> bool:
	var cost = Rules.level_up_cost(player_level() + 1)
	if state.cash >= cost:
		state.cash -= cost
		# No stat selection yet, just pump up strength.
		state.player_stats.might += 1
		return true
	return false


func player_abilities() -> Array:
	# TODO An actual system for tracking abilities, using a hardcoded list for
	# now
	return [
		preload("res://grimoire/armageddon.tres"),
		preload("res://grimoire/firebolt.tres"),
	]

#endregion

#region Hooks

func on_enemy_killed(enemy: Mob):
	var area_state = get_area_state()
	if enemy.has_trait(Mob.CreatureTrait.NO_RESPAWN):
		# Permanently delete a boss enemy.
		area_state.kills[enemy.spawn_origin] = enemy.display_name
	else:
		# Temporarily delete a normal enemy.
		area_state.soft_kills[enemy.spawn_origin] = enemy.display_name


func on_item_picked_up(mob: Mob, item: ItemNode):
	assert(mob.is_player()) # Only player is allowed to pick up items.
	# Once you grab it, it's gone for good.
	get_area_state().loots[item.spawn_origin] = item.display_name


func on_cash_picked_up(_mob: Mob, item: ItemNode):
	state.cash += item.count

	var origin_location = _area.get_location(item.spawn_origin)

	## If we pick the corpse cash drop, stop spawning it.
	if state.corpse_cash_location == origin_location:
		Game.msg("You recover your silver.")
		state.corpse_cash_location = null

#endregion

#region UI
func msg(text: String) -> void:
	get_tree().current_scene.msg(text)


func confirm(message: String) -> bool:
	return await get_tree().current_scene.confirm(message)

# TODO: An async aiming function that can be called from UI logic and aborted,
# no need to commit to consuming a resource before the aiming is finished.

#endregion
