extends TileMapLayer

## Set of cells from which FOV has been exposed from. Do not re-run FOV from the same cell.
var _visited = {}

## Make given cell visible.
func expose(cell: Vector2i):
	# Allow going one tile outside of bounds so we don't get a visible boundary at the edge of the on-screen map.
	if cell.x < -1 or cell.x >= Area.MAX_WIDTH + 1 or cell.y < -1 or cell.y >= Area.MAX_HEIGHT + 1:
		return
	set_cells_terrain_connect([cell], 0, 0)


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
