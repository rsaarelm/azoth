class_name PulseJoystick extends Node

## Custom

## Repeat interval in seconds.
@export var interval := 0.15

## Output vector, will pulse the direction being pressed.
var output := Vector2i.ZERO

var previously_pressed: Vector2i = Vector2i.ZERO
## Time when current press started in seconds.
var press_started := 0.0

# use Time.get_ticks_msec() to get current time in milliseconds

## Return the current input event being pressed.
static func _current_vector() -> Vector2i:
	var vec := Vector2i.ZERO
	if Input.is_action_pressed("move_left"):
		vec += Vector2i.LEFT
	if Input.is_action_pressed("move_right"):
		vec += Vector2i.RIGHT
	if Input.is_action_pressed("move_up"):
		vec += Vector2i.UP
	if Input.is_action_pressed("move_down"):
		vec += Vector2i.DOWN

	if vec.x != 0 and vec.y != 0:
		# Diagonal movement not allowed.
		return Vector2i.ZERO

	return vec

func _process(_delta: float) -> void:
	var current_dir := _current_vector()

	if current_dir != previously_pressed:
		# New direction being pressed, start and emit the dir.
		previously_pressed = current_dir
		output = current_dir
		press_started = Time.get_ticks_msec() / 1000.0
	else:
		# Same direction is being pressed, check if we should pulse.
		var now := Time.get_ticks_msec() / 1000.0
		if now - press_started >= interval:
			# Time to pulse again.
			output = current_dir
			press_started += interval
		else:
			# Not yet time to pulse.
			output = Vector2i.ZERO
