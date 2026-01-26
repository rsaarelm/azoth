@tool # Make the icon show up in editor map view
class_name ItemNode
extends Area2D

# For inspector ergonomics, have dummy parameters here for the inner item resource.
# Build the actual item in _ready.

## Node objects for items that show up on map.

## The resource object for the actual item.
var inner := Item.new()

## The resource for the actual item.
@export var data: ItemData:
	get:
		return inner.data
	set(value):
		inner.data = value
		var icon = get_node_or_null("Icon") as Sprite2D
		if icon:
			icon.texture = inner.data.icon if data else null

## Count of copies of the item in a stack for stackable items.
@export_range(1, 99, 1) var count: int = 1:
	get:
		return inner.count
	set(value):
		if inner.data and inner.data.is_stacking:
			inner.count = value
		else:
			inner.count = 1

# XXX: Copy-pasted from mob.gd
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

## Point where item was originally spawned, used for respawn blocklists.
var spawn_origin: Vector2i

var display_name: String:
	get:
		if inner.data:
			return inner.data.name
		return "n/a"


# TODO New signature _init(inner: Item)
func _init(_inner: Item = null):
	if _inner:
		inner = _inner

	# Align to cell center.
	if position == Vector2.ZERO:
		position = Area.CELL / 2


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


## Take out the inner item resource and discard the node.
func take() -> Item:
	queue_free()
	return inner


## Drop the item at a position.
func drop(at: Vector2i):
	visible = true
	cell = at

	var area = Game.area()
	var existing_item = area.item_at(at)
	if not existing_item:
		area.add_child(self)

	if existing_item and \
	self.inner.stacks_with(existing_item.inner) and \
	self.count + existing_item.count <= self.inner.stack_limit():
		# Merge stacks if you can
		existing_item.count += self.count
		self.queue_free()
	else:
		# Just cram two objects into the same cell for now.
		# TODO: Scatter dropped items to adjacent cells pinata style.
		area.add_child(self)

#region Animation
const BLINK_CYCLE := int(2.0 * 60) # 2 seconds in frames
const BLINK_DURATION := int(0.15 * 60)
var _phase_offset = hash(self) % BLINK_CYCLE


func animate():
	if Engine.is_editor_hint():
		return # Don't animate in editor.

	# Blinking animation, operate in 60 FPS frames
	var frame = (Engine.get_physics_frames() + _phase_offset) % BLINK_CYCLE

	if frame < BLINK_DURATION:
		$Icon.modulate = Color(999, 999, 999)
	elif frame < BLINK_DURATION * 1.1:
		$Icon.modulate = Color(0, 0, 0)
	else:
		$Icon.modulate = Color(1, 1, 1, 1)
#endregion
