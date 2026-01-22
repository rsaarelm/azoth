class_name Area extends TileMapLayer
## Custom terrain class that provides pathfinding and visibility checks.
## Use as root for area scenes.

## Size of a terrain cell in pixels.
const CELL_SIZE = 8
const CELL = Vector2(CELL_SIZE, CELL_SIZE)

const ACTIVE_ALTAR = Vector2i(6, 5)

# Position of exit terrain tile in terrain.png tilesheet.
const EXIT_TILE := Vector2i(0, 5)

# Physics layer that determines whether a tile blocks sight. Do not count it
# when considering if a tile blocks movement.
const SIGHT_LAYER := 2

# Map dimensions. These are fixed, since the maximum map is hardcoded to
# screen layout.
const MAX_WIDTH := 64
const MAX_HEIGHT := 41

# Neighbor maps in the game world you exit from map edges.
# These can't be PackedScenes because you get circular dependencies, so
# they're paths instead.

# A bunch of constraints apply to neighbor maps.

# INVARIANT: A neighbor map variable must either be empty or the path of the
# packed scene file for an area.

# INVARIANT: Open positions at the edge of a map with a neighbor connection
# must connect to the wider map and always have a second open position towards
# the center of the map immediately next to them. The outermost positions of
# the map are turned into the exit zone and the positions where the player
# enters the map are one step towards the center from those.

# INVARIANT: A map that is connected to must have at least one exit position
# on it's side that's facing the connection, eg. West side for a map that is
# being connected to towards the East, South side on a map that is being
# connected to towards the North.

# INVARIANT: Stairwells must have free spaces on opposite sides on vertically
# adjacent maps since the character jumps across the stairwell tile when
# moving. (This is to allow a single backstep that returns you to previous
# map)
#
#  @>#  <->  #<@
#  ^           ^
#   up      down
# stairs   stairs

@export_group("Neighboring Maps")
@export var north: String
@export var east: String
@export var south: String
@export var west: String

@export var above: String
@export var below: String

# INVARIANT: These must match the integers used in the tileset "kind" field.
enum Kind {
	REGULAR = 0,
	EXIT = 1,
	ALTAR = 2,
	DOWNSTAIRS = 3,
	UPSTAIRS = 4,
}

var _astar := AStarGrid2D.new()

var _astar_is_dirty: bool = false

var fog: Fog:
	set(value):
		# Make sure to remove any previous fog.
		if fog == value:
			return
		if fog:
			fog.queue_free()
		fog = value
		add_child(value, true)

# NB. Do not rely on collision physics to detect mobs. Moving entities only
# register in Godot's collision system on the frame after they moved, and a
# lot of the logic of the game relies on mobs showing up in their destination
# cell immediately after they've run their own process routin. Eg. consider
# two mobs updating on the same frame and trying to move to the same target
# cell.

func _ready():
	# Configure for 4-way movement.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_build_astar()

	# Schedule a pathfinding update whenever the tiles change.
	# Do not call _build_astar() directly here since there can be many change
	# events per frame.
	self.changed.connect(func() -> void:
		_astar_is_dirty = true
	)
	# NB. Pathfinding doesn't work immediately at the init frame, you need to
	# wait for the next frame after _astar.update() was called before paths
	# are formed correctly.

	# TODO: Support smaller maps that are centered. The exit edge consists of
	# the outermost walkable tiles on the map, wherever they are.

	# Add exit region to show connectivity to neighboring maps.
	if north:
		for x in range(get_used_rect().size.x):
			var pos = Vector2i(x, 0)
			if is_passable(pos):
				set_cell(pos, 1, EXIT_TILE)

	if west:
		for y in range(get_used_rect().size.y):
			var pos = Vector2i(0, y)
			if is_passable(pos):
				set_cell(pos, 1, EXIT_TILE)

	if east:
		for y in range(get_used_rect().size.y):
			var pos = Vector2i(get_used_rect().size.x - 1, y)
			if is_passable(pos):
				set_cell(pos, 1, EXIT_TILE)

	if south:
		for x in range(get_used_rect().size.x):
			var pos = Vector2i(x, get_used_rect().size.y - 1)
			if is_passable(pos):
				set_cell(pos, 1, EXIT_TILE)

	child_entered_tree.connect(_on_child_entered_tree)

	# Create fog of war
	fog = Fog.new()

func _process(_delta: float) -> void:
	if _astar_is_dirty:
		_build_astar()
		_astar_is_dirty = false

## Get path from start to end cell coordinates.
func path_to(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	return _astar.get_id_path(start, end)

## Return whether terrain can be walked at given cell coordinates.
## Does not consider mobs that might block the path.
func is_passable(cell: Vector2i) -> bool:
	var data = get_cell_tile_data(cell)
	# XXX: Currently any collision data in the tile makes it impassable.
	# In the future we might want to support thin walls so this should check
	# for polygons that cover the center of the tile only.
	if !data:
		return false
	for i in range(tile_set.get_physics_layers_count()):
		# Opaque cells can be passable.
		if i == SIGHT_LAYER:
			continue
		if data.get_collision_polygons_count(i) > 0:
			return false
	return true

func is_opaque(cell: Vector2i) -> bool:
	var data = get_cell_tile_data(cell)
	if !data:
		return false
	return data.get_collision_polygons_count(SIGHT_LAYER) > 0

## Return the special kind value of terrain at given cell.
func kind(cell: Vector2i) -> Kind:
	var data = get_cell_tile_data(cell)
	if !data:
		return Kind.REGULAR
	var kind_value = data.get_custom_data("kind")
	if kind_value == null:
		return Kind.REGULAR
	return kind_value as Kind

## Return cell the mouse is currently over.
func mouse_cell():
	var cell = local_to_map(get_local_mouse_position())
	# Return null if the map doesn't contain the cell.
	if !get_cell_tile_data(cell):
		return null
	return cell

## Return entities in a given cell.
func entities_at(cell: Vector2i) -> Array:
	# XXX: Unoptimized, a spatial index in area that stores objects by cell
	# would be better. (We can't use Godot's built-in collision physics since
	# they don't register movement during the frame when the entity moves.)
	var result = []
	for child in find_children("*", "", true, false):
		# Child must have "cell" property to be considered.
		if "cell" in child and child.cell == cell:
			result.append(child)
	return result

## Clear all entities from cell, bypasses game logic on damage, death etc. Use
## this to cull spawned items on a newly instantiated area.
func clear_cell(cell: Vector2i):
	for e in entities_at(cell):
		e.queue_free()

func clear_mobs(cell: Vector2i):
	for e in entities_at(cell):
		if e is Mob:
			e.queue_free()

func clear_items(cell: Vector2i):
	for e in entities_at(cell):
		if e is ItemNode:
			e.queue_free()

## Return mob at given cell, or null if none.
func mob_at(cell: Vector2i):
	var entities = entities_at(cell)
	for e in entities:
		if e is Mob and !e.is_dead():
			return e
	return null

## Return item at given cell, or null if none.
func item_at(cell: Vector2i):
	var entities = entities_at(cell)
	for e in entities:
		if e is ItemNode:
			return e
	return null

func make_altar_lit(pos: Vector2i):
	if kind(pos) == Kind.ALTAR:
		set_cell(pos, 1, ACTIVE_ALTAR)

# Make more raycast methods as needed, raycast_projectile etc.

## Do a raycast up until you collide with something that blocks vision.
## Return null if nothing was hit, otherwise return the collision position.
func raycast_sight(from: Vector2i, to: Vector2i):
	var space_state = get_world_2d().direct_space_state
	var from_pos = to_global(map_to_local(from))
	var to_pos = to_global(map_to_local(to))
	var params = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1 << SIGHT_LAYER)

	var collision = space_state.intersect_ray(params)
	if collision.size() > 0:
		# Displace along normal so we get the point inside the cell hit.
		var p = collision.position - collision.normal * 0.5 * CELL

		# Return cell space position of the hit.
		return local_to_map(to_local(p))
	return null

func can_see(from: Vector2i, to: Vector2i) -> bool:
	return raycast_sight(from, to) == null

## Display a temporary animation drawing attention to the given cell.
func ping(at: Vector2i):
	var fx = preload("res://ping.tscn").instantiate() as Node2D
	fx.position = map_to_local(at)
	self.add_child(fx)

## Clear fog of war up to radius from center using field of view
## algorithm.
func expose_fov(center: Vector2i, radius: int):
	fog.expose_fov(center, radius, func(cell: Vector2i) -> bool:
		return !is_opaque(cell)
	)

## Get the location type (encoding area ID) for the given cell on this area.
func get_location(cell: Vector2i) -> Dictionary:
	return { area = scene_file_path, cell = cell }

## Return state of the fog packed into an array.
func dump_fog() -> PackedByteArray:
	return fog.to_bytes()

## Reset fog to match given packed byte array.
func pump_fog(data: PackedByteArray):
	fog = Fog.from_bytes(data)

func _build_astar() -> void:
	_astar.region = get_used_rect()
	_astar.update()
	# XXX: Cells missing from layer are not handled in iteration. Maps should
	# not have missing cells next to walkable cells.
	for cell in get_used_cells():
		_astar.set_point_solid(cell, !is_passable(cell))
	_astar.update()

func _on_child_entered_tree(node: Node) -> void:
	# Make sure newly generated mobs are added to the y-sorting Mobs node
	if node is Mob:
		node.call_deferred("reparent", $Mobs)
