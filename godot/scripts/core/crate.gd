class_name Crate
extends RigidBody2D
## Przesuwana skrzynia: ciało sztywne z masą, tarciem o podłoże (tłumienie) i momentem bezwładności.
## Postacie mogą ją pchać, pociski przekazują jej pęd (trafienie poza środkiem ją obraca) i odbijają się od niej.
## Zasłania widok tak jak stałe przeszkody, więc działa jak ruchoma osłona.

const WOOD: Color = Color(0.55, 0.38, 0.2)
const WOOD_DARK: Color = Color(0.36, 0.24, 0.12)
const WOOD_LIGHT: Color = Color(0.68, 0.5, 0.28)
const BORDER: float = 5.0

var config: GameConfig
var _pending_reset: bool = false
var _reset_transform: Transform2D


func setup(cfg: GameConfig) -> void:
	config = cfg
	name = "Crate"
	gravity_scale = 0.0
	can_sleep = false
	mass = config.crate_mass
	# Moment bezwładności kwadratu względem środka: m * a^2 / 6.
	inertia = config.crate_mass * config.crate_size * config.crate_size / 6.0
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = config.crate_linear_damp
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = config.crate_angular_damp
	var material := PhysicsMaterial.new()
	material.friction = 0.3
	material.bounce = config.crate_restitution
	physics_material_override = material
	collision_layer = PhysicsLayers.CRATES
	collision_mask = PhysicsLayers.WALLS | PhysicsLayers.FIGHTERS | PhysicsLayers.CRATES | PhysicsLayers.PROJECTILES
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * config.crate_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func reset_at(at: Vector2) -> void:
	# Transformacja globalna (jak w Fighter.reset_at): areny w scenie treningowej są przesunięte.
	_reset_transform = (get_parent() as Node2D).global_transform * Transform2D(0.0, at)
	_pending_reset = true
	position = at
	rotation = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _pending_reset:
		state.transform = _reset_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_pending_reset = false


func _draw() -> void:
	var half: float = config.crate_size / 2.0
	var outer := Rect2(-half, -half, config.crate_size, config.crate_size)
	draw_rect(outer, WOOD_DARK)
	draw_rect(outer.grow(-2.0), WOOD)
	var inner: Rect2 = outer.grow(-BORDER)
	draw_rect(inner, WOOD_LIGHT, false, 2.0)
	draw_line(inner.position, inner.end, WOOD_DARK, 3.0)
	draw_line(Vector2(inner.position.x, inner.end.y), Vector2(inner.end.x, inner.position.y), WOOD_DARK, 3.0)
