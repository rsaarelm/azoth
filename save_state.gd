class_name SaveState
extends RefCounted
## Class containing all the data that goes in a save file

@export_storage var player_stats := Stats.new()

@export_storage var spawn_location := \
{ area = "res://atlas/northlands.tscn", cell = Vector2i(57, 36) }

@export_storage var last_altar_location := \
{ area = "res://atlas/northlands.tscn", cell = Vector2i(57, 35) }

@export_storage var corpse_cash_location = null
@export_storage var corpse_cash_amount := 0

@export_storage var cash := 0

@export_storage var inventory := ItemCollection.new()

# TODO: Equipment blocks, per character thing

## Dictionary of area resource path to AreaState
@export_storage var areas := { }
