class_name Stats
extends RefCounted
## Primary and derived stats for player characters.

@export_storage var might := 0
@export_storage var faith := 0
@export_storage var grace := 0
@export_storage var cunning := 0

var level:
	get:
		return might + faith + grace + cunning

var health:
	get:
		# Health is derived from the base stats.
		return 30 + 5 * might + 4 * faith + 4 * grace + 3 * cunning
