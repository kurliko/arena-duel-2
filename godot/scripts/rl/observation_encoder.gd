class_name ObservationEncoder
## Spłaszczenie Observation do wektora liczb (wejście sieci PPO). Te same dane, które dostają inne mózgi,
## w stałej kolejności i skali ok. -1..1. Względne pozycje mnożone przez RELATIVE_GAIN, bo przeciwnik
## i pociski są zwykle bliżej niż observation_distance_scale.

const RELATIVE_GAIN: float = 2.0
## 10 (bot) + 8 (przeciwnik) + 5 * k (pociski) + rays + 3 (amunicja) + 3 (osłona)
const SELF_SIZE: int = 10
const OPPONENT_SIZE: int = 8
const PROJECTILE_SIZE: int = 5
const PICKUP_SIZE: int = 3
const COVER_SIZE: int = 3


static func size(config: GameConfig) -> int:
	return SELF_SIZE + OPPONENT_SIZE + PROJECTILE_SIZE * config.nearest_projectiles_k \
			+ config.vision_rays + PICKUP_SIZE + COVER_SIZE


static func encode(obs: Observation, config: GameConfig) -> Array[float]:
	var values: Array[float] = []
	if obs == null:
		values.resize(size(config))
		values.fill(0.0)
		return values

	values.append_array([
		obs.self_position.x, obs.self_position.y, obs.self_velocity.x, obs.self_velocity.y,
		cos(obs.self_aim_angle), sin(obs.self_aim_angle),
		obs.self_hp, obs.self_ammo, obs.shot_cooldown_left, obs.dash_cooldown_left,
	])

	# Przeciwnik: widoczność, pozycja, prędkość, HP oraz kąt do niego względem celowania (cos, sin),
	# czyli wprost informacja, w którą stronę obrócić broń.
	if obs.opponent_visible:
		var relative_angle: float = angle_difference(obs.self_aim_angle, obs.opponent_relative_pos.angle())
		values.append_array([
			1.0, obs.opponent_relative_pos.x * RELATIVE_GAIN, obs.opponent_relative_pos.y * RELATIVE_GAIN,
			obs.opponent_velocity.x, obs.opponent_velocity.y, obs.opponent_hp,
			cos(relative_angle), sin(relative_angle),
		])
	else:
		values.append_array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

	for i: int in config.nearest_projectiles_k:
		if i < obs.nearest_projectiles.size():
			var p: Dictionary = obs.nearest_projectiles[i]
			var pos: Vector2 = p["pos"]
			var vel: Vector2 = p["vel"]
			values.append_array([1.0, pos.x * RELATIVE_GAIN, pos.y * RELATIVE_GAIN, vel.x, vel.y])
		else:
			values.append_array([0.0, 0.0, 0.0, 0.0, 0.0])

	for i: int in config.vision_rays:
		values.append(obs.ray_distances[i] if i < obs.ray_distances.size() else 0.0)

	values.append_array(_optional_vector(obs.ammo_pickup_available, obs.ammo_pickup_relative_pos))
	values.append_array(_optional_vector(obs.cover_available, obs.cover_relative_pos))
	return values


static func _optional_vector(available: bool, relative: Vector2) -> Array[float]:
	if not available:
		return [0.0, 0.0, 0.0]
	return [1.0, relative.x * RELATIVE_GAIN, relative.y * RELATIVE_GAIN]
