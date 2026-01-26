extends Node
## Top UI object for game

func _ready():
	if Save.exists():
		var loaded = Save.read()
		Game.state = loaded
	Game.load_area(Game.state.spawn_location.area, Game.state.spawn_location.cell)

## Ability you're currently aiming.
var aim_ability: Ability = null:
	set(value):
		if value != null:
			%CursorSprite.set_icon(value.icon)
		else:
			%CursorSprite.set_icon(null)
		aim_ability = value


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var area = Game.area()
		var leader = Game.leader()

		if !leader:
			return
		if aim_ability:
			# Fire the ability being aimed.

			var cell = area.mouse_cell()
			if cell:
				aim_ability.use(leader, cell)
				aim_ability = null
		else:
			# Start a long move
			# (Other actions show later)
			var cell = area.mouse_cell()
			if cell:
				# Is there an enemy?
				var mob = area.mob_at(cell)
				# Check the group, do nothing to "player" mobs.
				if mob:
					if mob.is_in_group("enemy"):
						# Assign mob as the target, it is now being hunted.
						leader.cmd_goto(mob)
						Game.start_running()
				elif area.is_passable(cell):
					# Move to unoccupied open ground.
					leader.cmd_goto(cell)
					Game.start_running()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var area = Game.area()

		# Right button cancels aiming
		if aim_ability:
			aim_ability = null

		# DEBUG: Show the field of view of a mob
		var cell = area.mouse_cell()
		if cell:
			var mob = area.mob_at(cell)
			if mob:
				# Trace los
				for y in range(0, 54):
					for x in range(0, 64):
						var pos = Vector2i(x, y)
						if Game.dist(pos, mob) <= Mob.ENEMY_SIGHT_RANGE and area.can_see(mob.cell, Vector2i(x, y)):
							area.ping(pos)


func msg(text: String) -> void:
	%Console.msg(text)

# These need to be member variables so we can modify them from the listener lambdas.
var _confirm_complete := false
var _confirm_result = null


func confirm(message: String) -> bool:
	var dialog = %ConfirmationPopup

	dialog.title = "Please confirm"
	dialog.dialog_text = message
	dialog.visible = true

	dialog.canceled.connect(
		func(): _confirm_result = false
			_confirm_complete = true
	)
	dialog.confirmed.connect(
		func(): _confirm_result = true
			_confirm_complete = true
	)

	while !_confirm_complete:
		# Busy-wait until we get an answer.
		await get_tree().process_frame
	_confirm_complete = false

	return _confirm_result
