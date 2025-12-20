extends Node

## Cached current area.
## Do not set from outside Game.
var _area: Area = null

## State variable for abilities being aimed.
var aim_ability: Ability = null:
	set(value):
		get_tree().current_scene.aim_ability = value

#region Global time and state management

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

## Reset levels and respawn player to last checkpoint.
##
## If `retain_player` is true, the player's injuries and status effects are
## sustained.
func restart():
	# Restarting is baked into GameScreen's initialization routine, so we just
	# reload the scene here.
	get_tree().change_scene_to_file("res://game_screen.tscn")

func player_rests():
	var player = Player.mob()
	Player.spawn_area = player.area.scene_file_path
	assert(Player.spawn_area, "Invalid area: No scene file path")
	Player.spawn_pos = player.cell

	# Show transition screen.
	get_tree().change_scene_to_file("res://resting.tscn")
	await get_tree().create_timer(1.0).timeout

	Game.restart()

func player_died():
	# TODO: Generate a recoverable cash pile at the spot you died or on the
	# enemy that killed you.

	# Lose your cash as punishment for dying.
	Game.msg("You died.")
	if Player.cash > 0:
		Game.msg("You lost " + str(Player.cash) + "$.")
	Player.cash = 0

	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file("res://you_died.tscn")
	await get_tree().create_timer(1.0).timeout
	restart()

## Load a new area and place the player in the given pos.
##
## If player is unspecified, pull out the existing player.
func load_area(scene_path: String, player_pos: Vector2i, player: Mob = null):
	if not player:
		# Get existing player entity.
		player = Player.mob()
		assert(player)

	# If player is in a container, detach it from that first.
	if player.get_parent():
		player.get_parent().remove_child(player)

	var view = get_tree().current_scene.find_child("GameView", true, false)
	assert(view, "XXX: load_area assumes it's in GameView")

	# Remove existing area if there is one.
	for child in view.get_children():
		child.queue_free()

	# Load the new area
	_area = load(scene_path).instantiate()
	view.add_child(_area)

	# Add player
	player.cell = player_pos
	_area.add_child(player)
#endregion

func msg(text: String) -> void:
	get_tree().current_scene.msg(text)

func confirm(message: String) -> bool:
	return await get_tree().current_scene.confirm(message)

## Get the current leader mob (directly controlled player character).
## This may be different than the main player character if a minion NPC
## is temporarily assigned to lead the team.
func leader() -> Mob:
	return Player.mob()

func area() -> Area:
	return _area
