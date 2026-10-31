class_name Perception
## Budowanie Observation z perspektywy jednego bota: tylko to, co ten bot może wiedzieć.
## Przeciwnik i pociski są widoczne wyłącznie przy wolnej linii wzroku (raycast).


static func build(me: Fighter, opponent: Fighter, arena: Arena, projectiles: Array[Projectile],
		pickups: Array[AmmoPickup], config: GameConfig) -> Observation:
	var scale: float = config.observation_distance_scale
	var obs := Observation.new()
	obs.self_position = me.position / scale
	obs.self_velocity = me.velocity / config.max_speed
	obs.self_aim_angle = me.aim_angle
	obs.self_hp = me.hp / config.max_hp
	obs.self_ammo = float(me.ammo) / config.max_ammo
	obs.shot_cooldown_left = me.shot_cooldown_left / config.shot_cooldown
	obs.dash_cooldown_left = me.dash_cooldown_left / config.dash_cooldown

	var to_opponent: Vector2 = opponent.position - me.position
	obs.opponent_visible = to_opponent.length() <= config.vision_range \
			and arena.has_line_of_sight(me.position, opponent.position)
	if obs.opponent_visible:
		obs.opponent_relative_pos = to_opponent / scale
		obs.opponent_velocity = opponent.velocity / config.max_speed
		obs.opponent_hp = opponent.hp / config.max_hp

	obs.nearest_projectiles = _visible_projectiles(me, arena, projectiles, config)

	obs.ray_distances.resize(config.vision_rays)
	for i: int in config.vision_rays:
		var direction := Vector2.RIGHT.rotated(TAU * i / config.vision_rays)
		obs.ray_distances[i] = arena.ray_distance(me.position, direction, config.ray_length) / config.ray_length

	var nearest: AmmoPickup = null
	for pickup: AmmoPickup in pickups:
		if pickup.available and (nearest == null
				or me.position.distance_squared_to(pickup.position) < me.position.distance_squared_to(nearest.position)):
			nearest = pickup
	obs.ammo_pickup_available = nearest != null
	if nearest != null:
		obs.ammo_pickup_relative_pos = (nearest.position - me.position) / scale
	return obs


static func _visible_projectiles(me: Fighter, arena: Arena, projectiles: Array[Projectile],
		config: GameConfig) -> Array[Dictionary]:
	var visible: Array[Projectile] = []
	for p: Projectile in projectiles:
		if me.position.distance_to(p.position) <= config.vision_range \
				and arena.has_line_of_sight(me.position, p.position):
			visible.append(p)
	visible.sort_custom(func(a: Projectile, b: Projectile) -> bool:
		return me.position.distance_squared_to(a.position) < me.position.distance_squared_to(b.position))
	var result: Array[Dictionary] = []
	for p: Projectile in visible.slice(0, config.nearest_projectiles_k):
		result.append({
			"pos": (p.position - me.position) / config.observation_distance_scale,
			"vel": p.velocity / config.projectile_speed,
		})
	return result
