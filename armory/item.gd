class_name Item
extends Resource

## The abstract Item resource.

@export var name := "Unnamed item"
@export var icon: Texture2D

# If true, instances of the item can be fused into numbered piles.
@export var is_stacking := false
