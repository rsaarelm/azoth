class_name FloatingText extends Label

const LIFETIME_PER_LETTER_S := 0.05
const DRIFTING_LIFETIME_S := 0.5
const DRIFT_SPEED := 40.0

## Whether the text floats out instead of sticking to the target.
@export var drifts_away := false

## Node the text is following.
var target_node: Node2D:
	set(value):
		target_node = value
		if target_node:
			snap_to(target_node)

## Game screen control this text is displayed on. Text will be clamped to it.
var game_screen: Control

var _lifetime := 0.0

func _process(delta: float) -> void:
	_lifetime += delta

	if drifts_away:
		if _lifetime >= DRIFTING_LIFETIME_S:
			queue_free()
			return
	elif _lifetime >= max(text.length() * LIFETIME_PER_LETTER_S, 0.5):
		queue_free()
		return

	if drifts_away:
		# Float away from initial position.
		global_position.y -= drifts_away as float * DRIFT_SPEED * delta

		# Fade out over lifetime.
		var alpha = clamp(1.0 - (_lifetime / DRIFTING_LIFETIME_S), 0.0, 1.0)
		modulate.a = alpha
	elif target_node:
		snap_to(target_node)

func snap_to(target):
	# Snap bottom-center to the target node's position.
	# Add the extra nudge to bring it just above a 8x8 sprite.
	var offset = size * Vector2(0.5, 1.0) + Vector2(0, 6)

	global_position = target.global_position - offset
