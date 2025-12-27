extends TileMapLayer

## Make given cell visible.
func expose(cell: Vector2i):
	set_cells_terrain_connect([cell], 0, 0)

## Make the entire area unmapped.
func restore():
	for y in Area.MAX_HEIGHT:
		for x in Area.MAX_WIDTH:
			set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

func expose_fov(center: Vector2i, radius: int, vis: Callable):
	# Floodfill-style FoV algo that copilot vibecoded for me.
	# Not bad, though there should probably be less seeing around corners.

	# XXX: This is substantially slowing down my game, needs optimization.
	var visited := {}
	var to_visit := [center]
	while to_visit.size() > 0:
		var cell = to_visit.pop_front()
		if cell in visited:
			continue
		visited[cell] = true
		# Expose the cell.
		expose(cell)
		# If within radius, add neighbors.
		if cell.distance_to(center) < radius and vis.call(cell):
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor = cell + offset
				if neighbor.x >= 0 and neighbor.x < Area.MAX_WIDTH and neighbor.y >= 0 and neighbor.y < Area.MAX_HEIGHT:
					to_visit.append(neighbor)
			# Expose opaque diagonal corners to make the FoV look better.
			for offset in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var neighbor = cell + offset
				if cell.distance_to(neighbor) < radius and \
					neighbor.x >= 0 and neighbor.x < Area.MAX_WIDTH and \
					neighbor.y >= 0 and neighbor.y < Area.MAX_HEIGHT:
					if !vis.call(neighbor):
						expose(neighbor)
