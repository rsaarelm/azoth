class_name ItemCollection extends Node

var items: Array[Item]

signal contents_changed

func _ready():
	# Items can delete themselves when used, detect that here.
	child_exiting_tree.connect(_on_child_exiting_tree)

func take(item):
	if item.data.is_stacking:
		# Try to merge into an existing stack.
		for i in items.size():
			if items[i].data == item.data:
				var space = ItemData.MAX_STACK - items[i].count
				if space >= item.count:
					# Fully merged into an existing pile, exit early.
					items[i].count += item.count
					item.queue_free()
					contents_changed.emit()
					return
				else:
					items[i].count += space
					item.count -= space

	# If we're here, the item was not fully merged into an existing stack,
	# and we need to add a new item.

	# Item moves under container, stops being a visible sprite in the world.
	item.reparent(self)
	item.visible = false

	items.append(item)
	item.state_changed.connect(_on_item_state_changed)
	contents_changed.emit()

## Throw an item to a position back in the world.
func throw(index: int, cell: Vector2i, amount=1):
	var item = items[index].split(amount)
	if !is_instance_valid(items[index]):
		# It was consumed by the split
		_remove_item_at(index)
	contents_changed.emit()

	item.drop(cell)

## Consume items without sending them anywhere.
func destroy(index: int, amount=1):
	if amount >= items[index].count:
		items[index].queue_free()
		_remove_item_at(index)
	else:
		items[index].count -= amount
	contents_changed.emit()

## Load an ItemCollection from a JSON array.
static func load(file: Array) -> ItemCollection:
	var collection = ItemCollection.new()
	for entry in file:
		collection.items.append(Item.new(ResourceLoader.load(entry.item), entry.count))
	return collection

## Save an ItemCollection to a JSON array.
func save() -> Array:
	var file: Array = []
	for item in items:
		file.append({
			"item": item.data.resource_path,
			"count": item.count,
		})
	return file

func _remove_item_at(index: int):
	items[index].state_changed.disconnect(_on_item_state_changed)
	items.remove_at(index)
	contents_changed.emit()

func _on_child_exiting_tree(node: Node):
	var idx = items.find(node)
	if idx == -1:
		print("ItemCollection: exiting child " + str(node) + " not found in collection")
		return

	_remove_item_at(idx)

func _on_item_state_changed():
	contents_changed.emit()
