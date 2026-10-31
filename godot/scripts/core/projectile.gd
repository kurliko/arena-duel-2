class_name Projectile
extends CharacterBody2D
## Pocisk z czasem lotu i rykoszetami.
## Ruch przez move_and_collide (rzutowanie kształtu na całym odcinku ruchu), więc szybki
## pocisk nie przeskakuje cienkich ścian. Odbicie: velocity.bounce(normal) ze stratą prędkości.

## Ile odbić może się zdarzyć w jednym ticku (np. w rogu areny).
const MAX_COLLISIONS_PER_TICK: int = 4

var config: GameConfig
var shooter: Fighter
var bounces: int = 0
var _lifetime_left: float = 0.0


func setup(cfg: GameConfig, from_fighter: Fighter, direction: Vector2) -> void:
	config = cfg
	shooter = from_fighter
	position = from_fighter.position
	velocity = direction * config.projectile_speed
	_lifetime_left = config.projectile_lifetime
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.PROJECTILES
	collision_mask = PhysicsLayers.WALLS | PhysicsLayers.FIGHTERS
	var shape := CircleShape2D.new()
	shape.radius = config.projectile_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# Pocisk startuje ze środka strzelca; strzelca może trafić dopiero po odbiciu.
	add_collision_exception_with(from_fighter)


func _physics_process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()
		return
	var motion: Vector2 = velocity * delta
	for i: int in MAX_COLLISIONS_PER_TICK:
		var collision: KinematicCollision2D = move_and_collide(motion)
		if collision == null:
			break
		var target := collision.get_collider() as Fighter
		if target != null:
			_hit(target)
			return
		bounces += 1
		if bounces > config.max_bounces:
			queue_free()
			return
		var normal: Vector2 = collision.get_normal()
		velocity = velocity.bounce(normal) * config.bounce_speed_loss
		motion = collision.get_remainder().bounce(normal) * config.bounce_speed_loss
		if bounces == 1 and is_instance_valid(shooter):
			remove_collision_exception_with(shooter)


func _hit(target: Fighter) -> void:
	if is_instance_valid(shooter):
		if target == shooter:
			shooter.stats.self_hits += 1
		else:
			shooter.stats.hits += 1
			if bounces > 0:
				shooter.stats.ricochet_hits += 1
	target.take_damage(config.projectile_damage)
	queue_free()


func _draw() -> void:
	var tint: Color = shooter.color if is_instance_valid(shooter) else Color.WHITE
	draw_circle(Vector2.ZERO, config.projectile_radius, tint.lightened(0.4))
