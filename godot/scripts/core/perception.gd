class_name Perception
## Budowanie Observation z perspektywy jednego bota: tylko to, co ten bot może wiedzieć.
## Przeciwnik i pociski są widoczne wyłącznie przy wolnej linii wzroku (raycast); zasłaniają ją
## stałe przeszkody i skrzynie.


static func build(me: Fighter, opponent: Fighter, arena: Arena, projectiles: Array[Projectile],
		pickups: Array[Pickup], crates: Array[Crate], config: GameConfig) -> Observation:
	var scale: float = config.observation_distance_scale
	var obs := Observation.new()
	obs.self_position = me.position / scale
	obs.self_velocity = me.linear_velocity / config.max_speed()
	obs.self_aim_angle = me.aim_angle
	obs.self_angular_velocity = me.angular_velocity / config.max_angular_speed()
	obs.self_hp = me.hp / config.max_hp
	obs.self_ammo = float(me.ammo) / config.max_ammo
	obs.shot_cooldown_left = me.shot_cooldown_left / config.shot_cooldown
	obs.dash_cooldown_left = me.dash_cooldown_left / config.dash_cooldown

	var to_opponent: Vector2 = opponent.position - me.position
	obs.opponent_visible = to_opponent.length() <= config.vision_range \
			and arena.has_line_of_sight(me.position, opponent.position)
	if obs.opponent_visible:
		obs.opponent_relative_pos = to_opponent / scale
		obs.opponent_velocity = opponent.linear_velocity / config.max_speed()
		obs.opponent_hp = opponent.hp / config.max_hp

	obs.nearest_projectiles = _visible_projectiles(me, arena, projectiles, config)
	if obs.opponent_visible:
		var cover: Vector2 = _nearest_cover(me.position, opponent.position, arena, config)
		obs.cover_available = cover.is_finite()
		if obs.cover_available:
			obs.cover_relative_pos = (cover - me.position) / scale

	obs.ray_distances.resize(config.vision_rays)
	for i: int in config.vision_rays:
		var direction := Vector2.RIGHT.rotated(TAU * i / config.vision_rays)
		obs.ray_distances[i] = arena.ray_distance(me.position, direction, config.ray_length) / config.ray_length

	var ammo: Pickup = _nearest_pickup(me, pickups, Pickup.Kind.AMMO)
	obs.ammo_pickup_available = ammo != null
	if ammo != null:
		obs.ammo_pickup_relative_pos = (ammo.position - me.position) / scale
	var medkit: Pickup = _nearest_pickup(me, pickups, Pickup.Kind.MEDKIT)
	obs.medkit_available = medkit != null
	if medkit != null:
		obs.medkit_relative_pos = (medkit.position - me.position) / scale

	obs.nearest_crates = _nearest_crates(me, crates, config)
	return obs


## Najbliższy dostępny pakiet danego rodzaju. Położenie pakietów to wiedza o mapie, wspólna dla obu botów.
static func _nearest_pickup(me: Fighter, pickups: Array[Pickup], kind: Pickup.Kind) -> Pickup:
	var nearest: Pickup = null
	for pickup: Pickup in pickups:
		if pickup.kind == kind and pickup.available and (nearest == null
				or me.position.distance_squared_to(pickup.position) < me.position.distance_squared_to(nearest.position)):
			nearest = pickup
	return nearest


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
			"vel": p.linear_velocity / config.projectile_speed,
		})
	return result


## k najbliższych skrzyń (pozycja i prędkość względna). Skrzynie są duże i widoczne z daleka.
static func _nearest_crates(me: Fighter, crates: Array[Crate], config: GameConfig) -> Array[Dictionary]:
	var sorted: Array[Crate] = crates.duplicate()
	sorted.sort_custom(func(a: Crate, b: Crate) -> bool:
		return me.position.distance_squared_to(a.position) < me.position.distance_squared_to(b.position))
	var result: Array[Dictionary] = []
	for crate: Crate in sorted.slice(0, config.nearest_crates_k):
		result.append({
			"pos": (crate.position - me.position) / config.observation_distance_scale,
			"vel": crate.linear_velocity / config.max_speed(),
		})
	return result


## Punkt osłony: dla każdej stałej przeszkody punkt tuż za nią po stronie przeciwnej do przeciwnika.
## Wybierany jest najbliższy botowi punkt wewnątrz areny, poza przeszkodami i zasłonięty przed przeciwnikiem.
## Zwraca Vector2(INF, INF), gdy nie ma takiego punktu. Układ przeszkód to wiedza o mapie, wspólna dla obu botów.
static func _nearest_cover(me_pos: Vector2, opponent_pos: Vector2, arena: Arena, config: GameConfig) -> Vector2:
	var clearance: float = config.fighter_radius + config.cover_margin
	var interior := Rect2(Vector2.ZERO, arena.layout.size).grow(-clearance)
	var best := Vector2(INF, INF)
	var best_distance: float = INF
	for rect: Rect2 in arena.layout.obstacles:
		var away: Vector2 = (rect.get_center() - opponent_pos).normalized()
		# Odległość od środka prostokąta do jego krawędzi w kierunku `away`, plus odstęp postaci.
		var extent: float = absf(away.x) * rect.size.x / 2.0 + absf(away.y) * rect.size.y / 2.0
		var candidate: Vector2 = rect.get_center() + away * (extent + clearance)
		if not interior.has_point(candidate) or _inside_any_obstacle(candidate, arena, clearance):
			continue
		if arena.has_line_of_sight(opponent_pos, candidate):
			continue
		var distance: float = me_pos.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


static func _inside_any_obstacle(point: Vector2, arena: Arena, clearance: float) -> bool:
	for rect: Rect2 in arena.layout.obstacles:
		if rect.grow(clearance).has_point(point):
			return true
	return false
