class_name Item
extends RefCounted
## Individual item instances with runtime state.

@export_storage var data: ItemData

## Count of copies of the item in a stack for stackable items.
@export_storage var count: int = 1:
	get:
		return count
	set(value):
		if value != count:
			changed.emit.call_deferred()
		count = value

## Signal that the item has been destroyed and should be removed from any container it's in.
signal destroyed

## Signal that a property of the item has changed.
signal changed


func _init(_data = null, _count = 1):
	self.data = _data
	# XXX: Should recoverable error handling be used for constructor validation?
	assert(_count == 1 || (_data and _data.is_stacking))
	self.count = _count


func duplicate() -> Item:
	return Item.new(data, count)


# Split off part of stack.
func split(amount: int) -> ItemNode:
	var clone = duplicate()
	if amount >= count:
		amount = count # Don't make more than we have.
		die()
	assert(amount == 1 || clone.data.is_stacking)
	assert(amount <= ItemData.MAX_STACK)
	clone.count = amount
	return clone


static var _coin_res = ResourceLoader.load("res://armory/silver_coin.tres")


## Construct a stack of coins.
static func make_coins(amount: int) -> Item:
	return Item.new(_coin_res, amount)


func die():
	destroyed.emit()


func stack_limit() -> int:
	if !self.data.is_stacking:
		return 1
	if self.data.kind == ItemData.Kind.CASH:
		# Cash piles can be huge.
		return 999999
	return ItemData.MAX_STACK


## Decrement the item count, remove the item if it reaches zero.
func consume_one():
	if count < 2:
		die()
	else:
		count -= 1


## Return whether two items can stack in principle.
## Does consider stack size limits.
func stacks_with(other: Item) -> bool:
	return self.data.is_stacking and self.data == other.data


func use(mob: Mob):
	if data.kind == ItemData.Kind.CONSUMABLE:
		var effect = data.effect
		assert(effect, "Consumable item without effect")

		consume_one()
		if effect.needs_aiming():
			# Effect needs aiming, punt to game
			Game.aim_ability = effect
		else:
			# No aiming needed, use the effect immediately.
			effect.use(mob, mob.cell)
	elif data.kind == ItemData.Kind.TREASURE:
		if mob.is_player():
			if mob.is_next_to_altar():
				Game.msg("You sacrifice the " + data.name + " on the altar.")
				var value = data.value
				consume_one()
				Game.add_cash(value)
			else:
				Game.msg("You can sacrifice this when standing next to an altar.")
