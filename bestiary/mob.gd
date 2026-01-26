class_name Mob
extends StaticBody2D

enum CreatureTrait {
	## Walks upright, can open doors and use items.
	HUMANOID,
	## Various special rules apply, does not count as living being.
	UNDEAD,
	## Fire does additional damage.
	FLAMMABLE,
	## This is a boss or a miniboss who won't respawn.
	NO_RESPAWN,
	## Killing this creature wins the level.
	QUEST_BOSS,
}

enum Goal {
	NONE,
	## Move towards _cmd_target
	GOTO,
}

const PLAYER_SIGHT_RANGE := 10
const ENEMY_SIGHT_RANGE := 7

# Rule of thumb: Creature with all settings at default corresponds to
# something like the common pig (human-sized, human-like biology, not sapient,
# not humanoid)

@export var display_name: String = "mob"

## List of abilities this mob can use.
@export var abilities: Array[Ability]

## Innate traits for this mob.
@export var traits: Array[CreatureTrait]

## How much damage can the mob take.
@export var health := 10

## How hard does the mob hit.
@export var strength := 3

## How likely the mob is to land a blow.
@export var accuracy := 1

## How well can the mob evade attacks.
@export var evasion := 0

## "Inverse hitpoints", set up so it's easy to reset by setting it to zero.
##
## Once wounds reach up to your health, you're dead.
var wounds := 0

## Cached reference to current area
var area: Area

## Access cell coordinates of the mob, using the underlying position.
##
## NB. You must reassign the whole cell value, mutating its .x or .y fields won't have any effect.
var cell: Vector2i:
	get:
		return Vector2i(position / Area.CELL_SIZE)
	set(value):
		# Make sure to preserve the local offset.
		var offset = Vector2i(
			posmod(position.x as int, Area.CELL_SIZE),
			posmod(position.y as int, Area.CELL_SIZE),
		)
		position = Vector2(value * Area.CELL_SIZE + offset)

var _goal := Goal.NONE

## Can be node (attacking a mob) or Vector2i
var _goal_target = null

## Cached pathfinding info
var _planned_path: Array[Vector2i]
var _planned_destination: Vector2i

## Set to true if mob moved in its last turn.
## Mob is considered to be currently in motion if this is true,
## and will be sometimes treated differently by game rules if it is.
var _is_moving := false

## Enemies the mob is currently seeing. Used to determine whether a visible
## enemy is new or known.
var _known_enemies: Array[Mob]

# INVARIANT: Mobs can't migrate to a different level from where they were spawned.
# The blocklist logic relies on mob's area at the time of its death being the same
# where it was spawned.

## Point where mob was originally spawned, used for respawn blocklists.
var spawn_origin: Vector2i

#region Movement

func _enter_tree():
	# Clean up stuff that's probably invalid.
	area = null
	_clear_goal()

	var node = get_parent()
	while node and node is not Area:
		node = node.get_parent()
	assert(node, "Object has no parent area")
	area = node
	spawn_origin = cell

	_post_step()


func _process(_delta: float) -> void:
	_animate()

	if is_player() and Game.is_paused:
		# Direct input for player character, start running from pause.
		var vector = Joystick.output
		if vector != Vector2i.ZERO:
			if bump(vector):
				# Wipe out any current goal when the player acts manually.
				_goal = Goal.NONE
				_goal_target = null

				Game.start_running()
				return

	# The pause game check. Prevent mobs from acting while the game is paused.
	# Animations can still run so this isn't a higher-level mechanism that
	# stops all _process action.
	if Game.is_paused:
		return

	# Set to false at the start of every turn when the mob has a chance to
	# act.
	_is_moving = false

	match _goal:
		Goal.NONE:
			if is_enemy():
				# Idle enemies are on the lookout for something to attack.
				var targets = _visible_enemies(ENEMY_SIGHT_RANGE)
				if !targets.is_empty():
					# When they find something, they'll shout and charge.
					say("!")
					cmd_goto(targets[0])
			elif is_player():
				# PC has nothing to do, so we should wait for player input.
				Game.stop_running()
		Goal.GOTO:
			if is_player():
				var enemies = _visible_enemies(PLAYER_SIGHT_RANGE)
				# Live enemies spotted while moving, pause the game.

				# Maintain the _known_enemies set for hysteresis,
				# enemies don't cause repeated pings every time they're seen,
				# only the first time they're added to the list.
				if !enemies.is_empty():
					for enemy in enemies:
						if !_known_enemies.has(enemy):
							# Signal to the player that this enemy is blocking
							# your goto.
							area.ping(enemy.cell)
					Game.stop_running()
				_known_enemies = enemies

			# Move towards the goal target.
			var target = _goal_target_cell()
			if !target:
				# Goal is invalid, usually because it was a mob and it was
				# killed.
				_clear_goal()
			else:
				var state = _move_towards(target)
				if !state:
					# Goal is done or failed.
					_clear_goal()


## Take a single step in direction.
func step(direction: Vector2i) -> bool:
	assert(direction.length() == 1, "Direction must be a unit vector.")

	if can_move(direction):
		# Is there something funny in the new location? This only happens when
		# player hits the stuff.
		var pos = cell + direction

		var kind = area.kind(pos)
		match kind:
			Area.Kind.REGULAR:
				pass
			Area.Kind.EXIT:
				# Area transition!

				# XXX: This assumes that areas are full-size and have
				# symmetric exit regions. Actual areas can be smaller and
				# might have displaced regions, requiring you to adjust the
				# entry position.
				if is_player():
					var new_area := ""
					var new_pos = pos
					# Make sure the new pos is set just before the exit
					# region, not on it.
					if pos.y == 0:
						new_area = area.north
						new_pos.y = Area.MAX_HEIGHT - 2
					elif pos.y == Area.MAX_HEIGHT - 1:
						new_area = area.south
						new_pos.y = 1
					elif pos.x == 0:
						new_area = area.west
						new_pos.x = Area.MAX_WIDTH - 2
					elif pos.x == Area.MAX_WIDTH - 1:
						new_area = area.east
						new_pos.x = 1
					else:
						assert(false, "Exit tile in invalid position: " + pos)
					assert(new_area, "Exit tile with no neighbor area.")

					# Switch to the new level, though set the retain-player
					# flag so that you can't use level transition to heal.
					Game.load_area(new_area, new_pos, self)
					return true
				return false
			Area.Kind.UPSTAIRS, Area.Kind.DOWNSTAIRS:
				# Another area transition
				if is_player():
					# The assumption is that the matching exit is in the same
					# position in the above/below map, and we want to set up a
					# thing where the player can reverse the transition by
					# immediately moving in the reverse direction. To do this,
					# we do a two-step horizontal movement with the area
					# transition.
					var new_pos = cell + direction * 2

					var new_area := ""
					if kind == Area.Kind.UPSTAIRS:
						new_area = area.above
					elif kind == Area.Kind.DOWNSTAIRS:
						new_area = area.below
					assert(new_area, "Stair tile with no neighbor area.")
					Game.load_area(new_area, new_pos, self)
					return true
				return false
			Area.Kind.ALTAR:
				# Pray at altar, you heal but the enemies respawn.

				if is_player():
					# TODO: Complex altar behavior, pop up an actual rest operations menu here for
					# complex leveling up, spell attunement etc.

					# Eat cash and do simple level ups as far as you can.
					while Game.level_up():
						Game.msg("Gained a level!")
					Game.player_rests(pos)
					return true
				return false

		# Set is_moving to true when you're definitely taking a step.
		_is_moving = true
		cell += direction

		_post_step()
		# Hooks for stepping to a new position go here.

		return true

	return false


# Logic to call every time a mob steps on new cell.
func _post_step():
	if is_player():
		# Player-specific stuff
		var item = area.item_at(cell)
		if item:
			pick_up(item)

		area.expose_fov(cell, PLAYER_SIGHT_RANGE)


## Attack enemies if there are any in the way. Return if action succeeded.
func bump(direction: Vector2) -> bool:
	if attack(direction):
		return true
	return step(direction)


func can_move(direction: Vector2i) -> bool:
	var pos = cell + direction
	return area.is_passable(pos) and area.mob_at(pos) == null

#endregion

#region Game rules

# Should 'attack' be split into 'find_target' and 'deal_damage'?

func attack(vec: Vector2i) -> bool:
	# This is a bump-to-attack melee attack, ranged attacks need a different
	# implementation that does a raycast query to see if it has a line of
	# fire.
	var target = area.mob_at(cell + vec)
	if target:
		if Util.odds(accuracy - target.evasion):
			target.take_damage(self.strength)
		# TODO: Some animation when the mob is missed, mob jumps to the side or sth
		return true
	return false


func take_damage(damage: int) -> void:
	if is_dead():
		return

	wounds += damage
	if !is_dead():
		say_drift(str(damage))
	else:
		# Snap to health, no negative HP.
		wounds = health
		say_drift("death")
		queue_free()
		if is_player():
			Game.player_died()

		if is_enemy():
			# Drop cash.
			var payout = max(1, int(strength * randf_range(0.5, 2.0)))
			ItemNode.new(Item.make_coins(payout)).drop(cell)

			Game.on_enemy_killed(self)

		# Add more death logic as needed


func has_trait(_trait: CreatureTrait) -> bool:
	return traits.has(_trait)


## Check if mob is next to altar.
func is_next_to_altar() -> bool:
	var pos = cell
	return area.kind(pos + Vector2i(1, 0)) == Area.Kind.ALTAR or \
	area.kind(pos + Vector2i(-1, 0)) == Area.Kind.ALTAR or \
	area.kind(pos + Vector2i(0, 1)) == Area.Kind.ALTAR or \
	area.kind(pos + Vector2i(0, -1)) == Area.Kind.ALTAR

#endregion

#region AI

## True if this mob is the main player character. The game is turn-based
## around the main character's moves.
func is_player() -> bool:
	return self == Game.leader()


func is_enemy() -> bool:
	return is_in_group("enemy")


func has_goal() -> bool:
	return _goal != Goal.NONE


func is_dead() -> bool:
	return wounds >= health


func cmd_goto(target):
	_goal = Goal.GOTO
	_goal_target = target


func say(text):
	var node = _make_floating_text(text)
	node.target_node = self


func say_drift(text):
	var node = _make_floating_text(text)
	node.snap_to(self)
	node.drifts_away = true


func _make_floating_text(text: String) -> FloatingText:
	# XXX: Hardcoded scene and screen component names
	var floating_text_scene = preload("res://floating_text.tscn")
	var node = floating_text_scene.instantiate() as FloatingText
	get_tree().current_scene.find_child("AreaFrame", true, false).add_child(node)
	node.text = text
	return node


func _clear_goal():
	_goal = Goal.NONE
	_goal_target = null
	if self == Game.leader():
		Game.stop_running()


## Return cell of the current goal target, or null if there is none.
func _goal_target_cell():
	if _goal_target == null:
		return null
	if _goal_target is Vector2i:
		return _goal_target
	if !is_instance_valid(_goal_target):
		# We were targeting a mob that has since been deleted.
		return null
	if _goal_target is Mob:
		return _goal_target.cell
	# It's a live object but not a type we understand.
	assert(false, "Invalid goal target type: " + _goal_target)


## Goal-executing primitive. Returns true if the goal remains valid.
func _move_towards(destination: Vector2i) -> bool:
	if cell == destination:
		# Already at destination, we're done.
		return false

	if not _planned_path or _planned_destination != destination:
		# Cache a new path, the old one isn't good.
		# No planned path, compute one.
		var path = area.path_to(cell, destination)
		if path.is_empty():
			# No path found.
			return false
		# Path will include our current position, so drop that.
		assert(path[0] == cell)
		# XXX: remove_at from the front of an array is ineffective, if we want
		# to optimize pathing, path arrays should be reversed and cleared from
		# the end.
		path.remove_at(0)
		_planned_path = path
		_planned_destination = destination
	# If we're still here, we have an up-to-date planned path with steps to
	# take.

	# Take the next step in the planned path.
	var next_cell = _planned_path[0]
	var step_vector = next_cell - cell
	assert(step_vector.length() == 1, "Planned path contains non-adjacent steps.")
	# TODO: Evasion procedures if we run into mobs, currently we just bump
	# them.
	if bump(step_vector):
		# Step succeeded.

		# If bump made us fight something, we haven't actually moved.
		# Check if we have and only advance the path if we did.
		if cell == next_cell:
			_planned_path.remove_at(0)
		return true
	_planned_path = []
	_planned_destination = Vector2i(-1, -1)
	# Something went wrong, has the terrain changed?
	# Bail out since we don't know what's going on.
	return false


func _visible_enemies(detection_range: int) -> Array[Mob]:
	var result: Array[Mob] = []

	var search_group = "player"
	if is_in_group("player"):
		search_group = "enemy"

	for mob in get_tree().get_nodes_in_group(search_group):
		if Rules.dist(self, mob) <= detection_range:
			if area.can_see(self.cell, mob.cell):
				result.append(mob)

	# Sort from closest to furthest
	result.sort_custom(
		func(a, b):
			return Rules.dist(self, a) < Rules.dist(self, b)
	)
	return result
#endregion

#region Items
func pick_up(item: ItemNode) -> void:
	# If it's cash, add count to stat and junk the object.
	if item.data.kind == ItemData.Kind.CASH:
		say("\"$" + str(item.count) + "\"")
		Game.on_cash_picked_up(self, item)
		item.queue_free()
		return

	# TODO A/an distinction in articles
	say("\"A " + item.data.name + ".\"")
	Game.on_item_picked_up(self, item)
	Game.state.inventory.insert(item.take())
#endregion

#region Animation
const ANIM_CYCLE := int(1.0 * 60) # 2 seconds in frames
var _phase_offset = hash(self) % ANIM_CYCLE


func _animate():
	# Simple idle animation, operate in 60 FPS frames
	var frame = (Engine.get_physics_frames() + _phase_offset) % ANIM_CYCLE

	if is_enemy() && _goal != Goal.NONE:
		# Animate awake enemies.
		if frame < ANIM_CYCLE / 2:
			$Icon.position = Vector2(0, -1)
		else:
			$Icon.position = Vector2(0, 0)
	else:
		# Make sure you're reset to neutral pos when anim stops
		$Icon.position = Vector2(0, 0)
#endregion
