class_name Fog extends TileMapLayer

## Fog of war on top of the area, can be revealed using a field of view algorithm.

## Set of cells from which FOV has been exposed from. Do not re-run FOV from the same cell.
var _visited = {}

# Covered tile atlas coordinates.
const COVERED = Vector2i(0, 0)

func _init():
	name = "Fog"
	tile_set = preload("res://atlas/fog.tres")
	z_index = 10

	# Fill the tilemap with fog.
	for y in range(-1, Area.MAX_HEIGHT + 1):
		for x in range(-1, Area.MAX_WIDTH + 1):
			set_cell(Vector2i(x, y), 0, COVERED)

## Initialize fog from byte array returned by a `to_bytes` call.
static func from_bytes(data: PackedByteArray) -> Fog:
	assert(data.size() == ((Area.MAX_WIDTH + 2) * (Area.MAX_HEIGHT + 2) + 7) / 8)
	var fog = Fog.new()
	for x in range(-1, Area.MAX_WIDTH + 1):
		for y in range(-1, Area.MAX_HEIGHT + 1):
			var i = x + y * (Area.MAX_WIDTH + 2)
			var seen = (data[i/8] & (1 << (i % 8))) != 0
			if seen:
				fog.expose(Vector2i(x, y))
	return fog

## Return state of the fog packed into an array.
func to_bytes() -> PackedByteArray:
	# Pack bits into byte array, 8 bits per byte.
	var ret = PackedByteArray()
	ret.resize(((Area.MAX_WIDTH + 2) * (Area.MAX_HEIGHT + 2) + 7) / 8)
	for x in range(-1, Area.MAX_WIDTH + 1):
		for y in range(-1, Area.MAX_HEIGHT + 1):
			var i = x + y * (Area.MAX_WIDTH + 2)
			if is_seen(Vector2i(x, y)):
				ret[i/8] |= 1 << (i % 8)
	return ret

## Make given cell visible.
func expose(cell: Vector2i):
	# This function makes sure the _inner bitgrid and the tilemap stay in sync.
	# Do not mutate either from elsewhere.

	# Allow going one tile outside of bounds so we don't get a visible boundary at the edge of the on-screen map.
	if cell.x < -1 or cell.x >= Area.MAX_WIDTH + 1 or cell.y < -1 or cell.y >= Area.MAX_HEIGHT + 1:
		return
	set_cells_terrain_connect([cell], 0, 0)

func is_seen(cell: Vector2i) -> bool:
	return get_cell_atlas_coords(cell) != COVERED

func expose_fov(center: Vector2i, radius: int, is_open: Callable):
	# Run each point at most once.
	if _visited.has(center):
		return
	_visited[center] = true

	# Expose the center cell.
	expose(center)
	# Do recursive shadowcasting.
	for u in [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(0, -1),
	]:
		# Perpendicular vectors
		var v = Vector2i(u.y, u.x)
		_process_octant(center, radius, is_open, u,  v, 1, 0.0, 1.0)
		_process_octant(center, radius, is_open, u, -v, 1, 0.0, 1.0)

func _process_octant(
	center: Vector2i,
	radius: int,
	is_open: Callable,
	forward: Vector2i,
	side: Vector2i,
	dist: int,
	start_slope: float,
	end_slope: float):

	if end_slope <= start_slope:
		return

	for u in range(dist, radius):
		var prev_visible = true
		for v in (u+1):
			# How the beams cross a square on the path:
			# Back corner on the side of the main axis.
			var inner_slope = (v - 0.5) / (u + 0.5)
			# Front corner opposite to main axis.
			var outer_slope = (v + 0.5) / (u - 0.5)

			if start_slope > outer_slope:
				continue
			if end_slope < inner_slope:
				break

			var offset = u * forward + v * side
			var cell = center + u * forward + v * side

			if offset.length() < radius:
				expose(cell)

			var cell_open = is_open.call(cell)
			if prev_visible and !cell_open:
				# Hit a wall after visible span, recurse to the sub-span
				prev_visible = false
				_process_octant(center, radius, is_open, forward, side, u + 1, start_slope, inner_slope)
			if !cell_open:
				# Update start slope while going through a wall.
				start_slope = outer_slope
			prev_visible = cell_open

		# This is a blocked span, do not proceed further.
		if !prev_visible:
			break
