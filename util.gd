class_name Util
## Game-agnostic utilities

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
