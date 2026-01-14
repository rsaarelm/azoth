class_name ItemSlot extends BaseButton

# Show icon and count for items, base graphic for empty slots.
@export var item: Item:
	set(value):
		if value != null:
			$Icon.texture = value.data.icon
			$Icon.visible = true
			if value.count > 1:
				$Count.text = str(value.count)
			else:
				$Count.text = ""
			$Base.visible = false
		else:
			$Count.text = ""
			$Icon.visible = false
			$Base.visible = true
