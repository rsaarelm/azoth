class_name ItemData
extends Resource
## The abstract item resource.

enum Kind {
	## Item can be used for some effect.
	CONSUMABLE,

	## Item has no practical use but is valuable and can be sold.
	TREASURE,

	## Item is a cash pile, will go to your wallet instead of staying in inventory.
	CASH,

	## Equippable in armor slot.
	ARMOR,

	## Equippable in helmet slot.
	HELMET,

	## Equippable in cloak slot.
	CLOAK,

	## Equippable in amulet slot.
	AMULET,

	## Equippable as weapon.
	WEAPON,

	## Equippable as weapon, takes two hands.
	TWO_HANDED_WEAPON,

	## Equippable as shield.
	SHIELD,

	## Equippable as ring.
	RING,
}

const MAX_STACK := 99

@export var name := "unnamed item"
@export var icon: Texture2D

## If true, instances of the item can be fused into piles.
@export var is_stacking := false

@export var kind := Kind.TREASURE

## Value of a treasure item.
@export var value: int

## Effect of a consumable item.
@export var effect: Ability

## How powerful the item is as a weapon/armor
@export var power: int

## Minimum might needed to equip.
@export var might_min: int

## Minimum grace needed to equip.
@export var grace_min: int

## Minimum faith needed to equip.
@export var faith_min: int

## Minimum cunning needed to equip.
@export var cunning_min: int


func is_equipment() -> bool:
	return kind in [
		Kind.ARMOR,
		Kind.HELMET,
		Kind.CLOAK,
		Kind.AMULET,
		Kind.WEAPON,
		Kind.SHIELD,
		Kind.RING,
		Kind.TWO_HANDED_WEAPON,
	]
