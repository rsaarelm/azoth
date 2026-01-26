extends HBoxContainer

func _init():
	update_icons()


func update_icons():
	# Remove old icons
	for child in get_children():
		remove_child(child)
		child.queue_free()

	for ability in Game.player_abilities():
		# TODO: Hotbar will need to have a selected set of abilities, not just
		# a list of everything the player has. Doing the simpler thing for
		# now though.
		var btn = TextureButton.new()
		btn.texture_normal = ability.icon

		btn.connect("pressed", Callable(self, "_on_ability_pressed").bind(ability))
		add_child(btn)


func _on_ability_pressed(ability):
	var player = Game.leader()
	if not player:
		return
	if ability.needs_aiming():
		# Tell the game we're aiming this ability.
		# Firing the ability is punted to the game node.
		Game.aim_ability = ability
	else:
		# Stop aim state just in case
		Game.aim_ability = null
		# No aiming needed, center on player.
		ability.use(player, player.cell)
