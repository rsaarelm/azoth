class_name Rules
## Game-specific static functions

## Distance between two games in the metric used by the game.
static func dist(p1, p2) -> float:
	# Taxicab metric distance
	p1 = Util.unwrap_cell(p1)
	p2 = Util.unwrap_cell(p2)
	return abs(p1.x - p2.x) + abs(p1.y - p2.y)

## How many coins do you need to pay to level up to given level.
static func level_up_cost(level: int) -> int:
	return int(100 * 1.05 ** (level - 1))

