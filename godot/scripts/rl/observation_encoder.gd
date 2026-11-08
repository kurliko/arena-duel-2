class_name ObservationEncoder
## Spłaszczenie Observation do wektora liczb (wejście sieci PPO). Te same dane, które dostają inne mózgi,
## w stałej kolejności i skali ok. -1..1. Względne pozycje mnożone przez RELATIVE_GAIN, bo przeciwnik
## i pociski są zwykle bliżej niż observation_distance_scale.

const RELATIVE_GAIN: float = 2.0
## 12 (bot, z pozostałym czasem meczu) + 8 (przeciwnik) + 4 (pamięć przeciwnika) + 5 * k (pociski) + rays
## + 3 (amunicja) + 3 (apteczka) + 5 * k (skrzynie) + 3 (osłona)
const SELF_SIZE: int = 12
const OPPONENT_SIZE: int = 8
const MEMORY_SIZE: int = 4
const PROJECTILE_SIZE: int = 5
const PICKUP_SIZE: int = 3
const CRATE_SIZE: int = 5
const COVER_SIZE: int = 3


static func size(config: GameConfig) -> int:
	return SELF_SIZE + OPPONENT_SIZE + MEMORY_SIZE + PROJECTILE_SIZE * config.nearest_projectiles_k \
			+ config.vision_rays + 2 * PICKUP_SIZE + CRATE_SIZE * config.nearest_crates_k + COVER_SIZE


## memory: pamięć bota o przeciwniku (stan mózgu RL); null = brak pamięci (same zera).
static func encode(obs: Observation, config: GameConfig, memory: OpponentMemory = null) -> Array[float]:
	var values: Array[float] = []
	if obs == null:
		values.resize(size(config))
		values.fill(0.0)
		return values

	values.append_array([
		obs.self_position.x, obs.self_position.y, obs.self_velocity.x, obs.self_velocity.y,
		cos(obs.self_aim_angle), sin(obs.self_aim_angle), obs.self_angular_velocity,
		obs.self_hp, obs.self_ammo, obs.shot_cooldown_left, obs.dash_cooldown_left, obs.time_left,
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

	# Pamięć: gdzie przeciwnik był ostatnio widziany i jak dawno (przydatne, gdy schowa się za przeszkodą).
	if memory != null and memory.has_last_seen:
		var last_seen: Vector2 = memory.relative_position(obs)
		values.append_array([1.0, last_seen.x * RELATIVE_GAIN, last_seen.y * RELATIVE_GAIN, memory.time_since_seen(obs)])
	else:
		values.append_array([0.0, 0.0, 0.0, 0.0])

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
	values.append_array(_optional_vector(obs.medkit_available, obs.medkit_relative_pos))
	for i: int in config.nearest_crates_k:
		if i < obs.nearest_crates.size():
			var crate: Dictionary = obs.nearest_crates[i]
			var crate_pos: Vector2 = crate["pos"]
			var crate_vel: Vector2 = crate["vel"]
			values.append_array([1.0, crate_pos.x * RELATIVE_GAIN, crate_pos.y * RELATIVE_GAIN, crate_vel.x, crate_vel.y])
		else:
			values.append_array([0.0, 0.0, 0.0, 0.0, 0.0])
	values.append_array(_optional_vector(obs.cover_available, obs.cover_relative_pos))
	return values


static func _optional_vector(available: bool, relative: Vector2) -> Array[float]:
	if not available:
		return [0.0, 0.0, 0.0]
	return [1.0, relative.x * RELATIVE_GAIN, relative.y * RELATIVE_GAIN]
