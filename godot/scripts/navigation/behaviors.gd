class_name Behaviors
extends RefCounted

const PREFERRED_DISTANCE: float = 350.0
const DISTANCE_TOLERANCE: float = 0.2
const SHOOT_ANGLE_DEG: float = 4.0
const MIN_EXPECTED_DAMAGE: float = 6.0
const DODGE_RADIUS_FACTOR: float = 2.5
const DODGE_HORIZON: float = 0.5
const THREAT_HORIZON: float = 1.0
const THREAT_RADIUS_FACTOR: float = 4.0
const STRAFE_SWITCH_DECISIONS: int = 40
const MIN_FREE_RAY: float = 0.1
const LAST_SEEN_REACHED: float = 40.0
const WANDER_MIN_FREE_RAY: float = 0.3
const WANDER_SWITCH_DECISIONS: int = 25
const COVER_REACHED: float = 12.0
const BLOCKED_RAY: float = 0.08
const DETOUR_OFFSETS: Array[int] = [1, -1, 2, -2]

var decisions: int = 0
var _config: GameConfig
var _strafe_sign: float = 1.0
var _last_seen: Vector2 = Vector2.ZERO
var _has_last_seen: bool = false
var _wander_ray: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(config: GameConfig) -> void:
	_config = config


func reset(rng_seed: int) -> void:
	_rng.seed = rng_seed
	_wander_ray = -1
	decisions = 0
	_strafe_sign = 1.0
	_has_last_seen = false


func observe(obs: Observation) -> void:
	decisions += 1
	if obs.opponent_visible:
		_last_seen = _my_pos(obs) + obs.opponent_relative_pos * _config.observation_distance_scale
		_has_last_seen = true


func _my_pos(obs: Observation) -> Vector2:
	return obs.self_position * _config.observation_distance_scale


func attack(obs: Observation, action: Action) -> void:
	if not obs.opponent_visible:
		search(obs, action)
		return
	_aim_and_shoot(obs, action)
	var to_opponent: Vector2 = obs.opponent_relative_pos * _config.observation_distance_scale
	var distance: float = to_opponent.length()
	if distance > PREFERRED_DISTANCE * (1.0 + DISTANCE_TOLERANCE):
		action.move = _move_around(obs, to_opponent)
	elif distance < PREFERRED_DISTANCE * (1.0 - DISTANCE_TOLERANCE):
		action.move = _move_around(obs, -to_opponent)
	else:
		if decisions % STRAFE_SWITCH_DECISIONS == 0:
			_strafe_sign = -_strafe_sign
		action.move = _strafe_move(obs, to_opponent)


func _aim_and_shoot(obs: Observation, action: Action) -> void:
	var to_opponent: Vector2 = obs.opponent_relative_pos * _config.observation_distance_scale
	var opponent_velocity: Vector2 = obs.opponent_velocity * _config.max_speed()
	var distance: float = to_opponent.length()
	var flight_time: float = _config.projectile_flight_time(distance)
	var aim_point: Vector2 = to_opponent + opponent_velocity * (flight_time if is_finite(flight_time) else 0.0)
	action.turn = _turn(obs, aim_point.angle())
	var aim_error: float = absf(angle_difference(obs.self_aim_angle, aim_point.angle()))
	# predkosc pocisku przy celu (po oporze), z niej liczymy obrazenia
	var impact_speed: float = _config.projectile_speed - _config.projectile_linear_damp * distance
	var expected_damage: float = _config.damage_for_speed(maxf(impact_speed, 0.0))
	action.shoot = obs.self_ammo > 0.0 and aim_error < deg_to_rad(SHOOT_ANGLE_DEG) \
			and expected_damage >= MIN_EXPECTED_DAMAGE


func _turn(obs: Observation, target_angle: float) -> int:
	return Steering.turn_toward(obs.self_aim_angle, obs.self_angular_velocity, target_angle, _config)


func _move_around(obs: Observation, direction: Vector2) -> int:
	var move_index: int = Steering.move_toward(direction)
	if move_index == Action.MOVE_STOP or not _blocked(obs, move_index):
		return move_index
	var best: int = move_index
	var best_free: float = -1.0
	for offset: int in DETOUR_OFFSETS:
		var candidate: int = posmod(move_index - 1 + offset, 8) + 1
		var free: float = obs.ray_distances[candidate - 1]
		if free >= BLOCKED_RAY and free > best_free:
			best_free = free
			best = candidate
	return best


func _blocked(obs: Observation, move_index: int) -> bool:
	return move_index != Action.MOVE_STOP and obs.ray_distances[move_index - 1] < BLOCKED_RAY


func _strafe_move(obs: Observation, axis: Vector2) -> int:
	var strafe: Vector2 = axis.orthogonal() * _strafe_sign
	var move_index: int = Steering.move_toward(strafe)
	if obs.ray_distances[move_index - 1] < MIN_FREE_RAY:
		_strafe_sign = -_strafe_sign
		move_index = Steering.move_toward(-strafe)
	return move_index


func seek_ammo(obs: Observation, action: Action) -> void:
	if not obs.ammo_pickup_available:
		search(obs, action)
		return
	var to_pickup: Vector2 = obs.ammo_pickup_relative_pos * _config.observation_distance_scale
	action.move = _move_around(obs, to_pickup)
	if obs.opponent_visible and obs.self_ammo > 0.0:
		_aim_and_shoot(obs, action)
	else:
		action.turn = _turn(obs, to_pickup.angle())


func seek_medkit(obs: Observation, action: Action) -> void:
	if not obs.medkit_available:
		take_cover(obs, action)
		return
	var to_medkit: Vector2 = obs.medkit_relative_pos * _config.observation_distance_scale
	action.move = _move_around(obs, to_medkit)
	if obs.opponent_visible and obs.self_ammo > 0.0:
		_aim_and_shoot(obs, action)
	else:
		action.turn = _turn(obs, to_medkit.angle())


func search(obs: Observation, action: Action) -> void:
	var my_pos: Vector2 = _my_pos(obs)
	var direction: Vector2
	if _has_last_seen and my_pos.distance_to(_last_seen) > LAST_SEEN_REACHED \
			and not _blocked(obs, Steering.move_toward(_last_seen - my_pos)):
		direction = _last_seen - my_pos
	else:
		_has_last_seen = false
		var rays: PackedFloat32Array = obs.ray_distances
		if _wander_ray < 0 or rays[_wander_ray] < MIN_FREE_RAY or decisions % WANDER_SWITCH_DECISIONS == 0:
			_wander_ray = _pick_wander_ray(rays)
		direction = Vector2.RIGHT.rotated(TAU * _wander_ray / rays.size())
	action.move = _move_around(obs, direction)
	action.turn = _turn(obs, direction.angle())


func _pick_wander_ray(rays: PackedFloat32Array) -> int:
	var candidates: Array[int] = []
	var best: int = 0
	for i: int in rays.size():
		if rays[i] >= WANDER_MIN_FREE_RAY:
			candidates.append(i)
		if rays[i] > rays[best]:
			best = i
	if candidates.is_empty():
		return best
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func take_cover(obs: Observation, action: Action) -> void:
	if obs.opponent_visible:
		_aim_and_shoot(obs, action)
	elif _has_last_seen:
		action.turn = _turn(obs, (_last_seen - _my_pos(obs)).angle())
	if obs.cover_available:
		var to_cover: Vector2 = obs.cover_relative_pos * _config.observation_distance_scale
		if to_cover.length() > COVER_REACHED:
			action.move = _move_around(obs, to_cover)


func evade(obs: Observation, action: Action) -> void:
	if obs.opponent_visible:
		_aim_and_shoot(obs, action)
	if dodge_if_threatened(obs, action):
		return
	var threat_velocity: Vector2 = _most_threatening_projectile_velocity(obs)
	if not threat_velocity.is_zero_approx():
		action.move = _strafe_move(obs, threat_velocity)
	elif obs.opponent_visible:
		action.move = _strafe_move(obs, obs.opponent_relative_pos)


func dodge_if_threatened(obs: Observation, action: Action) -> bool:
	if obs.dash_cooldown_left > 0.0:
		return false
	var scale: float = _config.observation_distance_scale
	for p: Dictionary in obs.nearest_projectiles:
		var rel: Vector2 = p["pos"] * scale
		var vel: Vector2 = p["vel"] * _config.projectile_speed
		if rel.dot(vel) >= 0.0 or vel.is_zero_approx():
			continue  # pocisk się oddala
		var t: float = -rel.dot(vel) / vel.length_squared()
		var miss_distance: float = (rel + vel * t).length()
		if t < DODGE_HORIZON and miss_distance < _config.fighter_radius * DODGE_RADIUS_FACTOR:
			action.dash = true
			action.move = Steering.move_toward(vel.orthogonal())
			return true
	return false


func projectile_threat(obs: Observation) -> float:
	return max_projectile_threat(obs, _config)


static func max_projectile_threat(obs: Observation, config: GameConfig) -> float:
	var best: float = 0.0
	for p: Dictionary in obs.nearest_projectiles:
		best = maxf(best, threat_of(p, config))
	return best


static func threat_of(p: Dictionary, config: GameConfig) -> float:
	var rel: Vector2 = p["pos"] * config.observation_distance_scale
	var vel: Vector2 = p["vel"] * config.projectile_speed
	if rel.dot(vel) >= 0.0 or vel.is_zero_approx():
		return 0.0
	var t: float = -rel.dot(vel) / vel.length_squared()
	var miss_distance: float = (rel + vel * t).length()
	var time_factor: float = clampf(1.0 - t / THREAT_HORIZON, 0.0, 1.0)
	var miss_factor: float = clampf(1.0 - miss_distance / (config.fighter_radius * THREAT_RADIUS_FACTOR), 0.0, 1.0)
	return time_factor * miss_factor


func _most_threatening_projectile_velocity(obs: Observation) -> Vector2:
	var best: float = 0.0
	var velocity: Vector2 = Vector2.ZERO
	for p: Dictionary in obs.nearest_projectiles:
		var threat: float = threat_of(p, _config)
		if threat > best:
			best = threat
			velocity = p["vel"]
	return velocity
