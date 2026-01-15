@tool  # Make the icon show up in editor map view
class_name Item extends Area2D

## Node objects for items that show up on map.

## The resource for the actual item.
@export var data: ItemData:
	get:
		return data
	set(value):
		data = value
		var icon = get_node_or_null("Icon") as Sprite2D
		if icon:
			icon.texture = data.icon if data else null

## Count of copies of the item in a stack for stackable items.
@export_range(1, 99, 1) var count: int = 1:
	get:
		return count
	set(value):
		if data and data.is_stacking:
			if value != count:
				state_changed.emit.call_deferred()
			count = value
		else:
			count = 1

# XXX: Copy-pasted from mob.gd
var cell: Vector2i:
	get:
		return Vector2i(position / Area.CELL_SIZE)
	set(value):
		# Make sure to preserve the local offset.
		var offset = Vector2i(
			posmod(position.x as int, Area.CELL_SIZE),
			posmod(position.y as int, Area.CELL_SIZE))
		position = Vector2(value * Area.CELL_SIZE + offset)

## Point where mob was originally spawned, used for respawn blocklists.
var spawn_origin: Vector2i

## Signal to UI that the item looks different now, eg. has a different count.
signal state_changed

func _init(_data=null, _count=1):
	if position == Vector2.ZERO:
		position = Vector2(Area.CELL_SIZE / 2.0, Area.CELL_SIZE / 2.0)

	self.data = _data
	# XXX: Should recoverable error handling be used for constructor validation?
	assert(_count == 1 || (_data and _data.is_stacking))
	self.count = _count

func _ready():
	# Create a Sprite2D child node named Icon.
	var icon = Sprite2D.new()
	icon.name = "Icon"
	add_child(icon, true)
	icon.texture = data.icon if data else null
	# Create a CollisionShape2D child node that's a circle with radius 2.0
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 2.0
	collision.shape = shape
	add_child(collision)

func _enter_tree():
	self.spawn_origin = cell

func _process(_delta):
	animate()

# Split off part of stack.
func split(amount: int) -> Item:
	var clone = duplicate()
	if amount >= count:
		amount = count  # Don't make more than we have.
		self.queue_free()
	assert(amount == 1 || clone.data.is_stacking)
	assert(amount <= ItemData.MAX_STACK)
	clone.count = amount
	return clone

static var _coin_res = ResourceLoader.load("res://armory/silver_coin.tres")

## Construct a stack of coins.
static func make_coins(amount: int) -> Item:
	return Item.new(_coin_res, amount)

## Drop the item at a position.
func drop(at: Vector2i):
	visible = true
	cell = at

	var area = Game.area()
	var existing_item = area.item_at(at)
	if not existing_item:
		area.add_child(self)

	if existing_item and \
		self.stacks_with(existing_item) and \
		self.count + existing_item.count <= self.stack_limit():
			# Merge stacks if you can
			existing_item.count += self.count
			self.queue_free()
	else:
		# Just cram two objects into the same cell for now.
		# TODO: Scatter dropped items to adjacent cells pinata style.
		area.add_child(self)

func stack_limit() -> int:
	if !self.data.is_stacking:
		return 1
	elif self.data.kind == ItemData.Kind.CASH:
		# Cash piles can be huge.
		return 999999
	else:
		return ItemData.MAX_STACK

## Decrement the item count, remove the item if it reaches zero.
func consume_one():
	if count < 2:
		queue_free()
	else:
		count -= 1
		state_changed.emit.call_deferred()

## Return whether two items can stack in principle.
## Does consider stack size limits.
func stacks_with(other: Item) -> bool:
	return self.data.is_stacking and self.data == other.data


func use(mob: Mob):
	if data.kind == ItemData.Kind.CONSUMABLE:
		var effect = data.effect
		assert(effect, "Consumable item without effect")

		consume_one()
		if effect.needs_aiming():
			# Effect needs aiming, punt to game
			Game.aim_ability = effect
		else:
			# No aiming needed, use the effect immediately.
			effect.use(mob, mob.cell)
	elif data.kind == ItemData.Kind.TREASURE:
		if mob.is_player():
			if mob.is_next_to_altar():
				Game.msg("You sacrifice the " + data.name + " on the altar.")
				var value = data.value
				consume_one()
				Player.cash += value
			else:
				Game.msg("You can sacrifice this when standing next to an altar.")

#region Animation
const BLINK_CYCLE := int(2.0 * 60)  # 2 seconds in frames
const BLINK_DURATION := int(0.15 * 60)
var _phase_offset = hash(self) % BLINK_CYCLE

func animate():
	if Engine.is_editor_hint():
		return  # Don't animate in editor.

	# Blinking animation, operate in 60 FPS frames
	var frame = (Engine.get_physics_frames() + _phase_offset) % BLINK_CYCLE

	if frame < BLINK_DURATION:
		$Icon.modulate = Color(999, 999, 999)
	elif frame < BLINK_DURATION * 1.1:
		$Icon.modulate = Color(0, 0, 0)
	else:
		$Icon.modulate = Color(1, 1, 1, 1)
#endregion
