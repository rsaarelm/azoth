class_name AreaState extends RefCounted

## Saved information for an area

## Explored area.
@export_storage var map_memory := PackedByteArray()

## Permanently killed mobs
@export_storage var kills := {}

## Permanently looted items.
@export_storage var loots := {}

## Mobs that are killed now but will respawn later unless the kills are made permanent.
var soft_kills := {}

func apply_to(area: Area):
	# Re-reveal explored terrain.
	if map_memory.size() > 0:
		area.pump_fog(map_memory)

	# Despawn things that have been removed.
	for pos in kills:
		area.clear_mobs(pos)

	for pos in soft_kills:
		area.clear_mobs(pos)

	for pos in loots:
		area.clear_items(pos)

func finalize_soft_kills():
	for key in soft_kills:
		kills[key] = soft_kills[key]
	soft_kills.clear()
