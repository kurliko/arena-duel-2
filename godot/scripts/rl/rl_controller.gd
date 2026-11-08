class_name RLController
extends AIController2D
## Most między meczem a Godot RL Agents dla jednego bota RL.
## Obserwację ustawia RLBrain w każdej decyzji; Sync odczytuje ją (get_obs), wysyła do Pythona albo modelu ONNX
## i zwraca akcję (set_action). Nagroda jest liczona z przyrostów statystyk bota między decyzjami.

## Klucze MUSZĄ być w kolejności alfabetycznej: Python (godot-rl) sortuje przestrzeń akcji po nazwach,
## więc model ONNX zwraca logity w tej kolejności, a Sync dekoduje je w kolejności tego słownika.
## Inna kolejność nie przeszkadza w treningu (akcje przychodzą z nazwami), ale psuje grę z modelem ONNX.
const ACTION_SPACE: Dictionary = {
	"dash": {"size": 2, "action_type": "discrete"},
	"move": {"size": Action.MOVE_DIRECTIONS, "action_type": "discrete"},
	"shoot": {"size": 2, "action_type": "discrete"},
	"turn": {"size": Action.TURN_OPTIONS, "action_type": "discrete"},
}
## Epizod kończy MatchManager (koniec meczu), nie licznik kroków pluginu.
const NO_STEP_LIMIT: int = 1 << 30

var config: GameConfig
var rewards: RewardConfig
var fighter: Fighter
var last_obs: Observation
var current_action: Action = Action.idle()
## Ostatnio widziana pozycja przeciwnika (pamięć mózgu RL, jak _last_seen w Behaviors).
var memory: OpponentMemory = OpponentMemory.new()
## Suma nagród w bieżącym epizodzie (do podglądu i logów).
var episode_reward: float = 0.0

var _won: bool = false
var _prev_hits: int = 0
var _prev_shots: int = 0
var _prev_self_hits: int = 0
var _prev_damage: float = 0.0
var _prev_pickups: int = 0
var _prev_dashes: int = 0
var _prev_damage_dealt: float = 0.0
var _prev_medkits: int = 0


func setup(cfg: GameConfig, reward_config: RewardConfig, owner_fighter: Fighter) -> void:
	config = cfg
	rewards = reward_config
	fighter = owner_fighter
	name = "RLController"
	reset_after = NO_STEP_LIMIT
	init(owner_fighter)


func begin_episode() -> void:
	_snapshot()
	last_obs = null
	memory.reset()
	episode_reward = 0.0
	# _won zostaje do następnego końca epizodu: nowy mecz startuje w tym samym ticku co koniec poprzedniego,
	# a Python odczytuje is_success dopiero przy kolejnej decyzji (razem z flagą końca epizodu).
	current_action = Action.idle()


## Wywoływane w każdej decyzji, zanim Sync odczyta obserwację i nagrodę.
## Zdarzenia od poprzedniej decyzji są skutkiem akcji wybranej na podstawie poprzedniej obserwacji (last_obs),
## więc to ją bierzemy pod uwagę, oceniając np. czy strzał był oddany na ślepo.
func on_decision(obs: Observation) -> void:
	_add(rewards.time_step + _stat_reward() + _shaping_reward(last_obs, obs))
	memory.update(obs)
	last_obs = obs


## Kształtowanie nagrody: sygnał za kroki pośrednie prowadzące do trafień i do amunicji.
func _shaping_reward(previous: Observation, current: Observation) -> float:
	var value: float = 0.0
	if current.opponent_visible:
		var aim_error: float = _aim_error(current)
		if aim_error < deg_to_rad(rewards.aim_tolerance_deg):
			value += rewards.aim_on_target
		if previous != null and previous.opponent_visible:
			value += (_aim_error(previous) - aim_error) * rewards.aim_improvement_per_rad
	if previous != null and previous.self_ammo <= rewards.ammo_low_fraction \
			and previous.ammo_pickup_available and current.ammo_pickup_available:
		var scale: float = config.observation_distance_scale
		var approach: float = (previous.ammo_pickup_relative_pos.length() - current.ammo_pickup_relative_pos.length()) * scale
		value += approach * rewards.ammo_approach_per_px
	return value


func _aim_error(obs: Observation) -> float:
	return absf(angle_difference(obs.self_aim_angle, obs.opponent_relative_pos.angle()))


## Koniec meczu: nagroda za wynik i flaga końca epizodu dla Pythona.
func end_episode(outcome: String) -> void:
	var terminal: float = rewards.draw
	if outcome == "win":
		terminal = rewards.win
	elif outcome == "loss":
		terminal = rewards.loss
	_add(_stat_reward() + terminal)
	_won = outcome == "win"
	done = true


func _add(value: float) -> void:
	reward += value
	episode_reward += value


## Nagroda za zdarzenia od poprzedniej decyzji (przyrosty statystyk bota), oceniana względem last_obs.
func _stat_reward() -> float:
	var s: FighterStats = fighter.stats
	var shots: int = s.shots - _prev_shots
	var value: float = (s.damage_dealt - _prev_damage_dealt) * rewards.damage_dealt_per_hp \
			+ (s.damage_taken - _prev_damage) * rewards.damage_taken_per_hp \
			+ (s.self_hits - _prev_self_hits) * rewards.self_hit \
			+ shots * rewards.shot \
			+ (s.dashes - _prev_dashes) * rewards.dash
	if shots > 0:
		var aimed: bool = last_obs != null and last_obs.opponent_visible \
				and _aim_error(last_obs) < deg_to_rad(rewards.aimed_shot_tolerance_deg)
		value += shots * (rewards.aimed_shot if aimed else rewards.blind_shot)
	var dashes: int = s.dashes - _prev_dashes
	if dashes > 0 and (last_obs == null
			or Behaviors.max_projectile_threat(last_obs, config) < rewards.dash_threat_threshold):
		value += dashes * rewards.unnecessary_dash
	var pickups: int = s.pickups - _prev_pickups
	if pickups > 0:
		var was_low: bool = last_obs == null or last_obs.self_ammo <= rewards.ammo_low_fraction
		value += pickups * (rewards.pickup_when_low if was_low else rewards.pickup)
	var medkits: int = s.medkits - _prev_medkits
	if medkits > 0:
		var hp_was_low: bool = last_obs == null or last_obs.self_hp <= rewards.hp_low_fraction
		value += medkits * (rewards.medkit_when_low if hp_was_low else rewards.medkit)
	_snapshot()
	return value


func _snapshot() -> void:
	var s: FighterStats = fighter.stats
	_prev_hits = s.hits
	_prev_shots = s.shots
	_prev_self_hits = s.self_hits
	_prev_damage = s.damage_taken
	_prev_pickups = s.pickups
	_prev_dashes = s.dashes
	_prev_damage_dealt = s.damage_dealt
	_prev_medkits = s.medkits


func get_obs() -> Dictionary:
	return {"obs": ObservationEncoder.encode(last_obs, config, memory)}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return ACTION_SPACE


func set_action(action) -> void:
	var a := Action.new()
	a.move = int(action["move"])
	a.turn = int(action["turn"])
	a.shoot = int(action["shoot"]) == 1
	a.dash = int(action["dash"]) == 1
	current_action = a


## Stable-Baselines3 liczy z tego odsetek zwycięstw (rollout/success_rate).
func get_info() -> Dictionary:
	return {"is_success": _won}
