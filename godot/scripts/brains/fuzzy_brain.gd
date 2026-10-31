class_name FuzzyBrain
extends Brain
## Bot rozmyty: z Observation liczy wejścia lingwistyczne, własny silnik Mamdaniego (FuzzyEngine)
## ocenia opłacalność czterech zachowań (atak, unik, osłona, zbieranie amunicji), a bot wykonuje
## najbardziej opłacalne przez wspólny moduł Behaviors. Reguły są w data/fuzzy_rules.json.

const DEFAULT_RULES_PATH: String = "res://data/fuzzy_rules.json"
## Premia dla zachowania wybranego w poprzedniej decyzji: ogranicza przeskakiwanie między zachowaniami
## przy zbliżonej opłacalności.
const HYSTERESIS: float = 0.05
const OUTPUTS: Array[String] = ["attack", "dodge", "cover", "collect"]

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
		# Nieznane HP przeciwnika: wartość środkowa, nie aktywuje ani „mało”, ani „dużo”.
		"opponent_hp": obs.opponent_hp if obs.opponent_visible else 0.5,
		"pickup_distance": obs.ammo_pickup_relative_pos.length() * scale if obs.ammo_pickup_available else _config.vision_range,
	}


func _choose(obs: Observation) -> String:
	var best: String = "attack"
	var best_score: float = -INF
	for output: String in OUTPUTS:
		if output == "collect" and not obs.ammo_pickup_available:
			continue
		var score: float = last_outputs[output] + (HYSTERESIS if output == chosen else 0.0)
		if score > best_score:
			best_score = score
			best = output
	return best
