class_name ItemCollection
extends RefCounted

@export_storage var items: Array[Item]:
	set(value):
		# Unbind old items.
		for i in items:
			i.destroyed.disconnect(_on_item_destroyed)
			i.changed.disconnect(_on_item_changed)

		items = value

		# Bind new items.
		for i in items:
			_bind_item(i)

		contents_changed.emit()

signal contents_changed


func _ready():
	# If collection starts out with contents, do initial bindings.
	for i in items:
		_bind_item(i)
	if items.size():
		contents_changed.emit()


func insert(item: Item):
	if item.data.is_stacking:
		# Try to merge into an existing stack.
		for i in items.size():
			if items[i].data == item.data:
				var space = ItemData.MAX_STACK - items[i].count
				if space >= item.count:
					# Fully merged into an existing pile, exit early.
					items[i].count += item.count
					item.die()
					contents_changed.emit()
					return
				else:
					items[i].count += space
					item.count -= space

	# If we're here, the item was not fully merged into an existing stack,
	# and we need to add a new item.

	items.append(item)
	_bind_item(item)

	contents_changed.emit()


func _bind_item(item):
	item.destroyed.connect(_on_item_destroyed.bind(item))
	item.changed.connect(_on_item_changed.bind(item))


func _remove_item_at(index: int):
	items[index].changed.disconnect(_on_item_changed)
	items[index].destroyed.disconnect(_on_item_destroyed)
	items.remove_at(index)
	contents_changed.emit()


func _on_item_destroyed(item: Item):
	var idx = items.find(item)
	if idx == -1:
		print("ItemCollection: destroyed item " + str(item) + " not found in collection")
		return

	_remove_item_at(idx)


func _on_item_changed(_item: Item):
	contents_changed.emit()
