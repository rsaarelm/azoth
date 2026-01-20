class_name Stats extends RefCounted

## Primary and derived stats for player characters.

@export_storage var might := 0
@export_storage var trickery := 0
@export_storage var faith := 0
@export_storage var deftness := 0

var level:
	get:
		return might + trickery + faith + deftness

var health:
	get:
		# Health is derived from the base stats.
		return 30 + 5 * might + 4 * faith + 4 * deftness + 3 * trickery
