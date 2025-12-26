@tool  # Make the icon show up in editor
class_name Item extends Area2D

## Node objects for items that show up on map.

## The resource for the actual item.
@export var item: ItemData:
	get:
		return item
	set(value):
		item = value
		_refresh()

## Count of copies of the item in a stack for stackable items.
@export_range(1, 99, 1) var count: int = 1:
	get:
		return count
	set(value):
		if item and item.is_stacking:
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

func _ready():
	_refresh()

func _refresh():
	if item:
		$Icon.texture = item.icon
	else:
		$Icon.texture = null

#region Animation
const BLINK_CYCLE := int(2.0 * 60)  # 2 seconds in frames
const BLINK_DURATION := int(0.15 * 60)
var _phase_offset = hash(self) % BLINK_CYCLE

func _process(_delta):
	# Blinking animation, operate in 60 FPS frames
	var frame = (Engine.get_physics_frames() + _phase_offset) % BLINK_CYCLE

	if frame < BLINK_DURATION:
		$Icon.modulate = Color(999, 999, 999)
	elif frame < BLINK_DURATION * 1.1:
		$Icon.modulate = Color(0, 0, 0)
	else:
		$Icon.modulate = Color(1, 1, 1, 1)
#endregion
