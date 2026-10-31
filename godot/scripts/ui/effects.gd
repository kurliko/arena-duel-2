class_name Effects
extends Node2D
## Krótkie efekty wizualne (błysk wystrzału, iskry trafienia). Tylko grafika: w trybie --headless
## nie są tworzone, więc nie wpływają na symulację ani na szybkość treningu.

enum Kind { MUZZLE_FLASH, IMPACT }

const MUZZLE_LIFETIME: float = 0.08
const IMPACT_LIFETIME: float = 0.25
const MUZZLE_LENGTH: float = 18.0
const IMPACT_RADIUS: float = 16.0
const SPARK_COUNT: int = 6

var kind: Kind = Kind.IMPACT
var tint: Color = Color.WHITE
var direction: Vector2 = Vector2.RIGHT
var _lifetime: float = 0.0
var _age: float = 0.0


static func _enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func spawn_muzzle_flash(parent: Node, at: Vector2, dir: Vector2, color: Color) -> void:
	if _enabled() and parent != null:
		parent.add_child(_create(Kind.MUZZLE_FLASH, at, dir, color, MUZZLE_LIFETIME))


static func spawn_impact(parent: Node, at: Vector2, color: Color) -> void:
	if _enabled() and parent != null:
		parent.add_child(_create(Kind.IMPACT, at, Vector2.RIGHT, color, IMPACT_LIFETIME))


static func _create(effect_kind: Kind, at: Vector2, dir: Vector2, color: Color, lifetime: float) -> Effects:
	var effect := Effects.new()
	effect.kind = effect_kind
	effect.position = at
	effect.direction = dir
	effect.tint = color
	effect._lifetime = lifetime
	return effect


func _process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / _lifetime
	match kind:
		Kind.MUZZLE_FLASH:
			var tip: Vector2 = direction * MUZZLE_LENGTH * (1.0 - t * 0.5)
			var side: Vector2 = direction.orthogonal() * MUZZLE_LENGTH * 0.3
			draw_colored_polygon(PackedVector2Array([side, tip, -side]), Color(1.0, 0.9, 0.5, 1.0 - t))
			draw_circle(Vector2.ZERO, MUZZLE_LENGTH * 0.35, Color(1.0, 1.0, 0.8, 1.0 - t))
		Kind.IMPACT:
			draw_arc(Vector2.ZERO, IMPACT_RADIUS * t, 0.0, TAU, 16, Color(tint.lightened(0.5), 1.0 - t), 2.0)
			for i: int in SPARK_COUNT:
				var spark_dir := Vector2.RIGHT.rotated(TAU * i / SPARK_COUNT)
				draw_line(spark_dir * IMPACT_RADIUS * t * 0.5, spark_dir * IMPACT_RADIUS * t,
						Color(1.0, 0.95, 0.6, 1.0 - t), 2.0)
