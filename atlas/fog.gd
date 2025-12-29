class_name Fog extends TileMapLayer

## Fog of war on top of the area, can be revealed using a field of view algorithm.

## Set of cells from which FOV has been exposed from. Do not re-run FOV from the same cell.
var _visited = {}

# Covered tile atlas coordinates.
const COVERED = Vector2i(0, 0)

func _init():
	name = "Fog"
	tile_set = preload("res://atlas/fog.tres")
	# Fill the tilemap with fog.
	for y in range(-1, Area.MAX_HEIGHT + 1):
		for x in range(-1, Area.MAX_WIDTH + 1):
			set_cell(Vector2i(x, y), 0, COVERED)

## Make given cell visible.
func expose(cell: Vector2i):
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

## Save to JSON array.
func save() -> Array[int]:
	var file: Array[int] = []
	# The fog is essentially a bitmap of visible cells, so we can compress things and pack runs of bits into 32-bit integers.

	# Total number of cells, the area with the one-tile border.
	var total_cells = (Area.MAX_WIDTH + 2) * (Area.MAX_HEIGHT + 2)
	for chunk in (total_cells + 31) / 32:
		var bits: int = 0
		for bit in range(32):
			var cell_index = chunk * 32 + bit
			if cell_index >= total_cells:
				break
			var x = (cell_index % (Area.MAX_WIDTH + 2)) - 1
			var y = (cell_index / (Area.MAX_WIDTH + 2)) - 1
			if is_seen(Vector2i(x, y)):
				bits |= (1 << bit)
		file.append(bits)

	# Trim trailing zeroes to keep the size down.
	while file.size() > 0 and file[file.size() - 1] == 0:
		file.remove_at(file.size() - 1)

	return file

## Load from JSON array.
static func load(file: Array) -> Fog:
	var fog = Fog.new()

	# Run the inverse of save, unpack the bits run and expose cells.
	var total_cells = (Area.MAX_WIDTH + 2) * (Area.MAX_HEIGHT + 2)
	for chunk in range((total_cells + 31) / 32):
		# If the input is shorter than expected, the rest is zeroes.
		if chunk >= file.size():
			break
		var bits: int = file[chunk]
		for bit in range(32):
			var cell_index = chunk * 32 + bit
			if cell_index >= total_cells:
				break
			var x = (cell_index % (Area.MAX_WIDTH + 2)) - 1
			var y = (cell_index / (Area.MAX_WIDTH + 2)) - 1
			if (bits & (1 << bit)) != 0:
				fog.expose(Vector2i(x, y))
	return fog

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
