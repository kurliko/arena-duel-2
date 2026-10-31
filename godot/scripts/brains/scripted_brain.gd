class_name ScriptedBrain
extends Brain
## Prosta maszyna stanów (FSM): klasyczne AI z gier jako punkt odniesienia i etap curriculum RL.
## Stany: ATAK (celowanie z wyprzedzeniem, utrzymywanie dystansu), AMUNICJA, SZUKANIE.
## Niezależnie od stanu: unik, gdy pocisk ma trafić w najbliższym czasie.

enum State { ATTACK, SEEK_AMMO, SEARCH }

## Dystans, który bot stara się utrzymać od przeciwnika (px).
const PREFERRED_DISTANCE: float = 350.0
const DISTANCE_TOLERANCE: float = 0.2
## Strzał, gdy błąd celowania jest mniejszy niż ten kąt (stopnie).
const SHOOT_ANGLE_DEG: float = 4.0
## Unik, gdy pocisk minie bota w odległości mniejszej niż ten mnożnik promienia w ciągu DODGE_HORIZON sekund.
const DODGE_RADIUS_FACTOR: float = 2.5
const DODGE_HORIZON: float = 0.5
## Co ile decyzji zmienia się kierunek krążenia wokół przeciwnika.
const STRAFE_SWITCH_DECISIONS: int = 40
## Minimalna wolna przestrzeń (ułamek ray_length) w kierunku krążenia; mniej = zmiana kierunku.
const MIN_FREE_RAY: float = 0.1
## Ostatnia znana pozycja przeciwnika jest uznana za sprawdzoną w tej odległości (px).
const LAST_SEEN_REACHED: float = 40.0
## Szukanie: losowy kierunek wśród tych z wolną przestrzenią (ułamek ray_length), zmieniany co tyle decyzji.
const WANDER_MIN_FREE_RAY: float = 0.3
const WANDER_SWITCH_DECISIONS: int = 25

var state: State = State.SEARCH
var _config: GameConfig
var _decisions: int = 0
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
	state = State.SEARCH
	_decisions = 0
	_strafe_sign = 1.0
	_has_last_seen = false


func decide(obs: Observation) -> Action:
	_decisions += 1
	var scale: float = _config.observation_distance_scale
	var my_pos: Vector2 = obs.self_position * scale
	var action := Action.new()

	if obs.opponent_visible:
		_last_seen = my_pos + obs.opponent_relative_pos * scale
		_has_last_seen = true

	if obs.self_ammo <= 0.0 and obs.ammo_pickup_available:
		state = State.SEEK_AMMO
	elif obs.opponent_visible:
		state = State.ATTACK
	else:
		state = State.SEARCH

	match state:
		State.ATTACK:
			_attack(obs, action)
		State.SEEK_AMMO:
			var to_pickup: Vector2 = obs.ammo_pickup_relative_pos * scale
			action.move = Steering.move_toward(to_pickup)
			action.turn = Steering.turn_toward(obs.self_aim_angle, to_pickup.angle(), _config)
		State.SEARCH:
			_search(obs, my_pos, action)

	_dodge_if_threatened(obs, action)
	return action


func _attack(obs: Observation, action: Action) -> void:
	var scale: float = _config.observation_distance_scale
	var to_opponent: Vector2 = obs.opponent_relative_pos * scale
	var opponent_velocity: Vector2 = obs.opponent_velocity * _config.max_speed
	# Celowanie z wyprzedzeniem: pozycja przeciwnika po czasie lotu pocisku.
	var flight_time: float = to_opponent.length() / _config.projectile_speed
	var aim_point: Vector2 = to_opponent + opponent_velocity * flight_time
	action.turn = Steering.turn_toward(obs.self_aim_angle, aim_point.angle(), _config)
	var aim_error: float = absf(angle_difference(obs.self_aim_angle, aim_point.angle()))
	action.shoot = obs.self_ammo > 0.0 and aim_error < deg_to_rad(SHOOT_ANGLE_DEG)

	var distance: float = to_opponent.length()
	if distance > PREFERRED_DISTANCE * (1.0 + DISTANCE_TOLERANCE):
		action.move = Steering.move_toward(to_opponent)
	elif distance < PREFERRED_DISTANCE * (1.0 - DISTANCE_TOLERANCE):
		action.move = Steering.move_toward(-to_opponent)
	else:
		if _decisions % STRAFE_SWITCH_DECISIONS == 0:
			_strafe_sign = -_strafe_sign
		var strafe: Vector2 = to_opponent.orthogonal() * _strafe_sign
		var move_index: int = Steering.move_toward(strafe)
		if obs.ray_distances[move_index - 1] < MIN_FREE_RAY:
			_strafe_sign = -_strafe_sign
			move_index = Steering.move_toward(-strafe)
		action.move = move_index


func _search(obs: Observation, my_pos: Vector2, action: Action) -> void:
	var direction: Vector2
	if _has_last_seen and my_pos.distance_to(_last_seen) > LAST_SEEN_REACHED:
		direction = _last_seen - my_pos
	else:
		_has_last_seen = false
		# Brak wskazówek: losowy kierunek z wolną przestrzenią. Losowość łamie symetrię:
		# dwa identyczne deterministyczne boty na symetrycznej arenie chodziłyby lustrzanie
		# i środkowa przeszkoda zasłaniałaby je sobie przez cały mecz.
		var rays: PackedFloat32Array = obs.ray_distances
		if _wander_ray < 0 or rays[_wander_ray] < MIN_FREE_RAY or _decisions % WANDER_SWITCH_DECISIONS == 0:
			_wander_ray = _pick_wander_ray(rays)
		direction = Vector2.RIGHT.rotated(TAU * _wander_ray / rays.size())
	action.move = Steering.move_toward(direction)
	action.turn = Steering.turn_toward(obs.self_aim_angle, direction.angle(), _config)


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


func _dodge_if_threatened(obs: Observation, action: Action) -> void:
	if obs.dash_cooldown_left > 0.0:
		return
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
			return
