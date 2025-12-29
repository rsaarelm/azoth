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

func _init(_data=null, _count=1):
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
