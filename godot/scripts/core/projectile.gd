class_name Projectile
extends RigidBody2D
## Pocisk jako ciało sztywne o masie m_p, symulowane przez silnik fizyki:
## - ciągłe wykrywanie kolizji (CCD, rzutowanie kształtu), więc szybki pocisk nie przeskakuje ścian,
## - tłumienie liniowe: pocisk zwalnia z odległością,
## - rykoszet rozwiązuje silnik (restytucja materiału pocisku), z limitem odbić,
## - trafienie: silnik przekazuje trafionemu pęd (pchnięcie), a obrażenia są proporcjonalne do energii
##   kinetycznej pocisku tuż przed zderzeniem: damage_at_muzzle_speed * (v / v0)^2.

## Długość śladu pocisku (liczba zapamiętanych pozycji, tylko grafika).
const TRAIL_LENGTH: int = 6

var config: GameConfig
var shooter: Fighter
var bounces: int = 0
var _lifetime_left: float = 0.0
## Prędkość na początku bieżącego kroku fizyki, czyli tuż przed ewentualnym zderzeniem.
var _velocity_before_step: Vector2 = Vector2.ZERO
var _trail: Array[Vector2] = []
var _hit_done: bool = false


func setup(cfg: GameConfig, from_fighter: Fighter, direction: Vector2) -> void:
	config = cfg
	shooter = from_fighter
	position = from_fighter.position
	linear_velocity = direction * config.projectile_speed
	_velocity_before_step = linear_velocity
	_lifetime_left = config.projectile_lifetime
	gravity_scale = 0.0
	can_sleep = false
	lock_rotation = true
	mass = config.projectile_mass
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = config.projectile_linear_damp
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = true
	max_contacts_reported = 4
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = config.projectile_restitution
	physics_material_override = material
	collision_layer = PhysicsLayers.PROJECTILES
	collision_mask = PhysicsLayers.WALLS | PhysicsLayers.FIGHTERS | PhysicsLayers.CRATES
	var shape := CircleShape2D.new()
	shape.radius = config.projectile_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	# Pocisk startuje ze środka strzelca; strzelca może trafić dopiero po odbiciu.
	add_collision_exception_with(from_fighter)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_lifetime_left -= delta
	_velocity_before_step = linear_velocity
	if _lifetime_left <= 0.0 or linear_velocity.length() < config.min_projectile_speed:
		queue_free()
		return
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_back()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if _hit_done:
		return
	var target := body as Fighter
	if target != null:
		_hit(target)
		return
	bounces += 1
	if bounces > config.max_bounces:
		_hit_done = true
		queue_free()
		return
	if bounces == 1 and is_instance_valid(shooter):
		remove_collision_exception_with(shooter)


func _hit(target: Fighter) -> void:
	_hit_done = true
	var damage: float = config.damage_for_speed(_velocity_before_step.length())
	if is_instance_valid(shooter):
		if target == shooter:
			shooter.stats.self_hits += 1
		else:
			shooter.stats.hits += 1
			shooter.stats.damage_dealt += minf(damage, target.hp)
			if bounces > 0:
				shooter.stats.ricochet_hits += 1
	target.take_damage(damage)
	Effects.spawn_impact(get_parent(), position, shooter.color if is_instance_valid(shooter) else Color.WHITE)
	queue_free()


func _draw() -> void:
	var tint: Color = shooter.color if is_instance_valid(shooter) else Color.WHITE
	# Ślad: jaśniejszy przy pocisku, zanika do tyłu; jasność pocisku rośnie z energią.
	var energy: float = clampf(pow(linear_velocity.length() / config.projectile_speed, 2.0), 0.0, 1.0)
	for i: int in range(1, _trail.size()):
		var alpha: float = 0.5 * (1.0 - float(i) / TRAIL_LENGTH) * energy
		draw_line(to_local(_trail[i - 1]), to_local(_trail[i]), Color(tint, alpha), config.projectile_radius)
	draw_circle(Vector2.ZERO, config.projectile_radius + 1.5, Color(tint.lightened(0.6), 0.4 + 0.6 * energy))
	draw_circle(Vector2.ZERO, config.projectile_radius, Color.WHITE.lerp(tint, 0.3))
