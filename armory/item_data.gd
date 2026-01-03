class_name ItemData
extends Resource

## The abstract Item resource.

enum ItemKind {
	## Item can be used for some effect.
	CONSUMABLE,

	## Item has no practical use but is valuable and can be sold.
	TREASURE,

	## Item is a cash pile, will go to your wallet instead of staying in inventory.
	CASH,
}

const MAX_STACK := 99

@export var name := "Unnamed item"
@export var icon: Texture2D

# If true, instances of the item can be fused into numbered piles.
@export var is_stacking := false
