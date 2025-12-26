class_name ItemData
extends Resource

## The abstract Item resource.

const MAX_STACK := 99

@export var name := "Unnamed item"
@export var icon: Texture2D

# If true, instances of the item can be fused into numbered piles.
@export var is_stacking := false
