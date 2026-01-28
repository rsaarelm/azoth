class_name Equipment
extends RefCounted
## Equipped item set for a character.

enum EquipSlot {
	HELMET,
	AMULET,
	CLOAK,
	BODY,
	LEFT_HAND,
	RIGHT_HAND,
	LEFT_RING,
	RIGHT_RING,
}

## EquipSlot -> Item | null
@export_storage var slot: Dictionary

signal contents_changed


## Apply the effects of the equipment set to a mob.
func apply_to(_mob: Mob):
	# * Reset mob's derived stats to ones derived from the base creature data.
	# Same effect can come from both spell effects and equipment, should handle
	# equipping and unequipping correctly, ie, keep going as long as spell
	# lasts even if effect item was unequipped.

	# * Add the effects of each equipped item to entity, need some iteration
	# scheme here to keep code nice.
	pass


func unequip(s: Equipment.EquipSlot) -> Variant:
	if slot.has(s):
		var item = slot[s]
		slot.erase(s)
		contents_changed.emit()
		return item
	return null


## Find a slot where the item can be equipped right now.
func find_free_slot(item: Item) -> Variant:
	match item.data.kind:
		ItemData.Kind.HELMET:
			if not slot.has(EquipSlot.HELMET):
				return EquipSlot.HELMET
		ItemData.Kind.AMULET:
			if not slot.has(EquipSlot.AMULET):
				return EquipSlot.AMULET
		ItemData.Kind.CLOAK:
			if not slot.has(EquipSlot.CLOAK):
				return EquipSlot.CLOAK
		ItemData.Kind.ARMOR:
			if not slot.has(EquipSlot.BODY):
				return EquipSlot.BODY
		ItemData.Kind.WEAPON:
			# Only equip in main hand.
			if not slot.has(EquipSlot.RIGHT_HAND):
				return EquipSlot.RIGHT_HAND
			# If dual wielding is allowed, this can return off hand when main hand is occupied.
		ItemData.Kind.TWO_HANDED_WEAPON:
			# Only equip in main hand, both hands must be free.
			if not slot.has(EquipSlot.RIGHT_HAND) and not slot.has(EquipSlot.LEFT_HAND):
				return EquipSlot.RIGHT_HAND
		ItemData.Kind.SHIELD:
			# Only equip in off hand, main hand must not have a two-handed weapon.
			if not slot.has(EquipSlot.LEFT_HAND) and \
			not (slot.has(EquipSlot.RIGHT_HAND) and \
				slot[EquipSlot.RIGHT_HAND].data.kind == ItemData.Kind.TWO_HANDED_WEAPON ):
				return EquipSlot.LEFT_HAND
		ItemData.Kind.RING:
			# Prefer left hand for rings.
			if not slot.has(EquipSlot.LEFT_RING):
				return EquipSlot.LEFT_RING
			if not slot.has(EquipSlot.RIGHT_RING):
				return EquipSlot.RIGHT_RING
	return null


## Return list of slots to unequip that would let a new item be equipped.
## Assumes you called `find_free_slot` first, so it's assumed the default slot
## is occupied and this method doesn't do further occupancy checks in the
## simple cases.
##
## Returns null if the item isn't equippable at all.
func slots_to_unequip_for(item: Item) -> Variant:
	match item.data.kind:
		ItemData.Kind.HELMET:
			return [EquipSlot.HELMET]
		ItemData.Kind.AMULET:
			return [EquipSlot.AMULET]
		ItemData.Kind.CLOAK:
			return [EquipSlot.CLOAK]
		ItemData.Kind.ARMOR:
			return [EquipSlot.BODY]
		ItemData.Kind.WEAPON:
			return [EquipSlot.RIGHT_HAND]
		ItemData.Kind.TWO_HANDED_WEAPON:
			return [
				EquipSlot.RIGHT_HAND,
				EquipSlot.LEFT_HAND,
			]
		ItemData.Kind.SHIELD:
			return [EquipSlot.LEFT_HAND]
		ItemData.Kind.RING:
			# Just keep cycling right ring.
			return [EquipSlot.RIGHT_RING]
	return null


## Try to equip an item, unequipping other items if needed.
## Return null if item can't be equipped, list of unequipped items otherwise.
func equip(item: Item) -> Variant:
	# Try to find a free slot first.
	var f = find_free_slot(item)
	if f != null:
		slot[f] = item
		contents_changed.emit()
		return []

	# See if we can get by with unequipping something.
	var slots_to_unequip = slots_to_unequip_for(item)
	if slots_to_unequip == null:
		# Looks like this mignt not be an equippable item.
		return null

	var unequipped_items = []
	for s in slots_to_unequip:
		if slot.has(s):
			unequipped_items.append(slot[s])
			slot.erase(s)

	# Now equip the new item.
	var target_slot = find_free_slot(item)
	assert(target_slot != null)
	slot[target_slot] = item
	contents_changed.emit()
	return unequipped_items
