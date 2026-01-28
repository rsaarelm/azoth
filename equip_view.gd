extends Control

var backend: Equipment:
	set(value):
		# Disconnect old signal.
		if backend:
			backend.contents_changed.disconnect(_update)
		backend = value
		# Attach new signal and update.
		if backend:
			backend.contents_changed.connect(_update)
			_update()

# Dictionary from EquipSlot enum to EquipSlot scene nodes.
var _slots := { }


func _ready():
	for node in find_children("*", "EquipSlot", true, true):
		_slots[node.slot_type] = node
		# Bind slot button.
		node.pressed.connect(_on_slot_pressed.bind(node.slot_type))

	_update()


func _update():
	if not backend:
		return

	for slot_type in _slots:
		if backend.slot.has(slot_type):
			_slots[slot_type].item = backend.slot[slot_type]
		else:
			_slots[slot_type].item = null


func _process(_delta):
	# If game was loaded, the old link is invalid, update.
	if backend != Game.state.equipment:
		backend = Game.state.equipment


func _on_slot_pressed(slot: Equipment.EquipSlot):
	# Try to unequip the item when clicked.
	var item = backend.unequip(slot)
	if item:
		Game.state.inventory.insert(item)
		_update()
