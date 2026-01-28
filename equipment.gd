class_name Equipment
extends RefCounted
## Equipped item set for a character.

@export_storage var cloak: Item
@export_storage var head: Item
@export_storage var amulet: Item

@export_storage var right_hand: Item
@export_storage var body: Item
@export_storage var left_hand: Item

@export_storage var left_ring: Item
@export_storage var right_ring: Item


## Apply the effects of the equipment set to a mob.
func apply_to(_mob: Mob):
	# * Reset mob's derived stats to ones derived from the base creature data.
	# Same effect can come from both spell effects and equipment, should handle
	# equipping and unequipping correctly, ie, keep going as long as spell
	# lasts even if effect item was unequipped.

	# * Add the effects of each equipped item to entity, need some iteration
	# scheme here to keep code nice.
	pass
