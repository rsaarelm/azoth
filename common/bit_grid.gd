class_name BitGrid extends Resource

## Bounds where the grid has set bits.
@export var bounds: Rect2i

## Internal bit buffer.
##
## It stores a bitmap with 8 bits per byte.
var buffer := PackedByteArray()

func _init(x: int, y: int, w: int, h: int):
	assert(w >= 0 && h >= 0)
	bounds = Rect2i(x, y, w, h)

	# One byte per 8 bits, make space for trailing bits with the + 7 part.
	var size_bytes = (w * h + 7) / 8
	buffer.resize(size_bytes)

func set_bit(pos: Vector2i, value: bool) -> void:
	var bit_index = _bit_index(pos)
	if bit_index == -1:
		return
	var byte_index = bit_index / 8
	var bit_offset = bit_index % 8
	if value:
		buffer[byte_index] |= 1 << bit_offset
	else:
		buffer[byte_index] &= ~(1 << bit_offset)

func get_bit(pos: Vector2i) -> bool:
	var bit_index = _bit_index(pos)
	if bit_index == -1:
		return false
	var byte_index = bit_index / 8
	var bit_offset = bit_index % 8
	return (buffer[byte_index] & (1 << bit_offset)) != 0

func _bit_index(pos: Vector2i) -> int:
	if !bounds.has_point(pos):
		return -1
	pos -= bounds.position
	return pos.y * bounds.size.x + pos.x
