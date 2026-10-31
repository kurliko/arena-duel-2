class_name FuzzyBrain
extends Brain
## Bot rozmyty: z Observation liczy wejścia lingwistyczne, własny silnik Mamdaniego (FuzzyEngine)
## ocenia opłacalność pięciu zachowań (atak, unik, osłona, zbieranie amunicji, leczenie), a bot wykonuje
## najbardziej opłacalne przez wspólny moduł Behaviors. Reguły są w data/fuzzy_rules.json.

const DEFAULT_RULES_PATH: String = "res://data/fuzzy_rules.json"
## Premia dla zachowania wybranego w poprzedniej decyzji: ogranicza przeskakiwanie między zachowaniami
## przy zbliżonej opłacalności.
const HYSTERESIS: float = 0.05
const OUTPUTS: Array[String] = ["attack", "dodge", "cover", "collect", "heal"]

var engine: FuzzyEngine
## Stan ostatniej decyzji (do HUD-u i wizualizacji „myślenia”).
var last_inputs: Dictionary = {}
var last_outputs: Dictionary = {}
var chosen: String = "attack"

var _config: GameConfig
var _behaviors: Behaviors


func _init(config: GameConfig, rules_path: String = DEFAULT_RULES_PATH) -> void:
	_config = config
	_behaviors = Behaviors.new(config)
	engine = FuzzyEngine.load_from_file(rules_path)


func reset(rng_seed: int) -> void:
	_behaviors.reset(rng_seed)
	chosen = "attack"


func decide(obs: Observation) -> Action:
	_behaviors.observe(obs)
	last_inputs = _fuzzy_inputs(obs)
	last_outputs = engine.infer(last_inputs)
	chosen = _choose(obs)

	var action := Action.new()
	match chosen:
		"attack":
			_behaviors.attack(obs, action)
		"dodge":
			_behaviors.evade(obs, action)
		"cover":
			_behaviors.take_cover(obs, action)
		"collect":
			_behaviors.seek_ammo(obs, action)
		"heal":
			_behaviors.seek_medkit(obs, action)
	return action


## Wartości wejść silnika rozmytego w jednostkach z pliku reguł (px, ułamki 0..1).
func _fuzzy_inputs(obs: Observation) -> Dictionary:
	var scale: float = _config.observation_distance_scale
	return {
		# Niewidoczny przeciwnik: odległość nieznana, traktowana jak daleko.
		"distance": obs.opponent_relative_pos.length() * scale if obs.opponent_visible else _config.vision_range,
		"hp": obs.self_hp,
		"ammo": obs.self_ammo,
		"visible": 1.0 if obs.opponent_visible else 0.0,
		"threat": _behaviors.projectile_threat(obs),
		"opponent_speed": obs.opponent_velocity.length() if obs.opponent_visible else 0.0,
		# Energia, z jaką pocisk doleci do przeciwnika (ułamek energii wylotowej): spada z odległością przez opór.
		"impact_energy": _impact_energy(obs),
		# Nieznane HP przeciwnika: wartość środkowa, nie aktywuje ani „mało”, ani „dużo”.
		"opponent_hp": obs.opponent_hp if obs.opponent_visible else 0.5,
		"pickup_distance": obs.ammo_pickup_relative_pos.length() * scale if obs.ammo_pickup_available else _config.vision_range,
		"medkit_distance": obs.medkit_relative_pos.length() * scale if obs.medkit_available else _config.vision_range,
		# Gotowość celowania przy bezwładności obrotu (stopnie): kąt, przy którym broń sama by się zatrzymała
		# (obecny kąt + omega / tłumienie kątowe), względem kierunku do przeciwnika. Niewidoczny: 180.
		"aim_error": _predicted_aim_error_deg(obs),
		# Własna prędkość jako ułamek prędkości granicznej: powyżej 1 tylko po zryw albo pchnięciu (impulsy).
		"self_speed": obs.self_velocity.length(),
	}


func _impact_energy(obs: Observation) -> float:
	if not obs.opponent_visible:
		return 0.0
	var distance: float = obs.opponent_relative_pos.length() * _config.observation_distance_scale
	var impact_speed: float = maxf(_config.projectile_speed - _config.projectile_linear_damp * distance, 0.0)
	return pow(impact_speed / _config.projectile_speed, 2.0)


func _predicted_aim_error_deg(obs: Observation) -> float:
	if not obs.opponent_visible:
		return 180.0
	var omega: float = obs.self_angular_velocity * _config.max_angular_speed()
	var resting_angle: float = obs.self_aim_angle + omega / _config.fighter_angular_damp
	return rad_to_deg(absf(angle_difference(resting_angle, obs.opponent_relative_pos.angle())))


func _choose(obs: Observation) -> String:
	var best: String = "attack"
	var best_score: float = -INF
	for output: String in OUTPUTS:
		if output == "collect" and not obs.ammo_pickup_available:
			continue
		if output == "heal" and not obs.medkit_available:
			continue
		var score: float = last_outputs[output] + (HYSTERESIS if output == chosen else 0.0)
		if score > best_score:
			best_score = score
			best = output
	return best
