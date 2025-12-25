extends Control

@export var item: ItemData
@export var count := 1

func _ready():
	if item != null:
		$Icon.texture = item.icon
		if count > 1:
			$Count.text = str(count)
