@tool  # Make the icon show up in editor
class_name ItemNode extends Area2D

## Node objects for items that show up on map.

## The resource for the actual item.
@export var item: Item:
	get:
		return item
	set(value):
		item = value
		_refresh()

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
