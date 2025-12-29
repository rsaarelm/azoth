class_name Util
## Game-agnostic utilities

# Can't use the built-in Input.get_vector() here because it doesn't do the
# just_pressed bit.
static func get_input_vector() -> Vector2i:
	if Input.is_action_just_pressed("move_left"):
		return Vector2i.LEFT
	elif Input.is_action_just_pressed("move_right"):
		return Vector2i.RIGHT
	elif Input.is_action_just_pressed("move_up"):
		return Vector2i.UP
	elif Input.is_action_just_pressed("move_down"):
		return Vector2i.DOWN
	else:
		return Vector2i.ZERO

## Extract cell value from either vector or mob entity.
static func unwrap_cell(entity) -> Vector2i:
	if entity is Vector2i:
		return entity
	elif entity is Mob:
		return entity.cell
	else:
		assert(false, "unwrap_pos: Can't handle entity of type %s" % [typeof(entity)])
	return Vector2i.ZERO

## Get probability value for deciban odds.
static func odds_prob(a: float) -> float:
	return 1.0 - 1.0 / (1.0 + 10.0 ** (a / 10.0))

## Randomly return true with the given deciban odds.
static func odds(a: float) -> bool:
	return randf() < odds_prob(a)

# INVARIANT: There must not be areas wider than 2^8 = 256 cells.

## Encode map cell to JSON-friendly integer.
static func cell_to_int(cell: Vector2i) -> int:
	return cell.x + (cell.y << 8)

## Decode encoded integer cell back to Vector2i.
static func int_to_cell(value: int) -> Vector2i:
	return Vector2i(value & 0xFF, (value >> 8) & 0xFF)
