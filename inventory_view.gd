extends Control

## Reference to the character inventory in game data.
var backend: ItemCollection:
	set(value):
		# Disconnect old signal.
		if backend:
			backend.contents_changed.disconnect(_update)
		backend = value
		# Attach new signal and update.
		if backend:
			backend.contents_changed.connect(_update)
			_update()

# INVARIANT: offset value must be either zero or small enough that there are no
# empty lines in the item view grid.

## Offset of the first visible item in the items list.
var offset := 0

## How many columns does the item view grid have.
var columns := 1

var _slots: Array[ItemSlot]


func _ready():
	# Collect ItemSlot type child nodes into _slots array.
	_slots = []

	var slot_nodes = find_children("*", "ItemSlot", true, true)
	for i in slot_nodes.size():
		_slots.append(slot_nodes[i])

		# Bind slot buttons.
		slot_nodes[i].pressed.connect(_on_slot_pressed.bind(i))

	# Get the column count from the GUI component.
	columns = $ItemGrid.columns

	# Just hardcode the connection to player's stuff
	backend = Game.state.inventory

	# Populate
	_update()


func _process(_delta):
	# If game was loaded, the old link is invalid, update.
	if backend != Game.state.inventory:
		backend = Game.state.inventory


func _update():
	if not backend:
		return

	# Adjust offset down if there's empty space at the end.
	while offset > 0 and offset + _slots.size() - columns >= backend.items.size():
		offset -= columns

	for i in _slots.size():
		var item_index = offset + i
		if item_index < backend.items.size():
			_slots[i].item = backend.items[item_index]
		else:
			_slots[i].item = null

	$UpButton.visible = offset > 0
	$DownButton.visible = offset + _slots.size() < backend.items.size()


func _on_up_pressed():
	offset = max(0, offset - columns)
	_update()


func _on_down_pressed():
	offset += columns
	_update()


func _on_slot_pressed(idx: int):
	var item_idx = offset + idx
	if item_idx < backend.items.size():
		var item = backend.items[item_idx]
		if item.data.is_equipment():
			# Try to equip the item.
			var unequipped = Game.state.equipment.equip(item)
			if unequipped != null:
				# Successfully equipped, remove from inventory.
				backend.remove(item)

				# Add unequipped items back to inventory.
				for uneq_item in unequipped:
					backend.insert(uneq_item)
		else:
			# Use consumable item.
			item.use(Game.leader())
