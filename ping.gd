extends Node2D
## Ping effect, an expanding and fading circle around the center position.

var lifetime := 0.2
var elapsed := 0.0

@export var max_radius: float = 12.0
@export var color: Color = Color(0.5, 0, 0, 1)

func _process(delta: float) -> void:
	color.a = lerp(1.0, 0.0, elapsed / lifetime)
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var radius = lerp(0.0, max_radius, elapsed / lifetime)
	draw_circle(Vector2.ZERO, radius, color, false, 2.0)
