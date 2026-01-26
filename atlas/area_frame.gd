class_name AreaFrame
extends Container
## Container for game screen that manages area transitions.

var area: Area


func _init():
	# Become area-sized
	size = Area.CELL * Vector2(Area.MAX_WIDTH, Area.MAX_HEIGHT)


func load_area(scene_path: String, player_pos: Vector2i, player: Mob = null) -> Area:
	if not player:
		# Get existing player entity.
		player = Game.build_player()
		assert(player)

	# Register exit from player's previous area (if any).
	if player.area:
		Game.on_area_exited(player.area)

	# If player is in a container, detach it from that first.
	if player.get_parent():
		player.get_parent().remove_child(player)

	# Delete any previous area stored in frame.
	if area:
		area.queue_free()

	area = load(scene_path).instantiate()
	add_child(area)

	# Wait for the area to initialize so that spawns show up for enter-hook to
	# delete.
	await get_tree().process_frame

	Game.on_area_entered(area)

	# Insert player in new area.
	player.cell = player_pos
	area.add_child(player)

	return area
