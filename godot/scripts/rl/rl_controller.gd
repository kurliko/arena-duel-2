class_name RLController
extends AIController2D
## Most między meczem a Godot RL Agents dla jednego bota RL.
## Obserwację ustawia RLBrain w każdej decyzji; Sync odczytuje ją (get_obs), wysyła do Pythona albo modelu ONNX
## i zwraca akcję (set_action). Nagroda jest liczona z przyrostów statystyk bota między decyzjami.

const ACTION_SPACE: Dictionary = {
	"move": {"size": Action.MOVE_DIRECTIONS, "action_type": "discrete"},
	"turn": {"size": Action.TURN_OPTIONS, "action_type": "discrete"},
	"shoot": {"size": 2, "action_type": "discrete"},
	"dash": {"size": 2, "action_type": "discrete"},
}
## Epizod kończy MatchManager (koniec meczu), nie licznik kroków pluginu.
const NO_STEP_LIMIT: int = 1 << 30

var config: GameConfig
var rewards: RewardConfig
var fighter: Fighter
var last_obs: Observation
var current_action: Action = Action.idle()
## Suma nagród w bieżącym epizodzie (do podglądu i logów).
var episode_reward: float = 0.0

var _won: bool = false
var _prev_hits: int = 0
var _prev_shots: int = 0
var _prev_self_hits: int = 0
var _prev_damage: float = 0.0
var _prev_pickups: int = 0


func setup(cfg: GameConfig, reward_config: RewardConfig, owner_fighter: Fighter) -> void:
	config = cfg
	rewards = reward_config
	fighter = owner_fighter
	name = "RLController"
	reset_after = NO_STEP_LIMIT
	init(owner_fighter)


func begin_episode() -> void:
	_snapshot()
	episode_reward = 0.0
	_won = false
	current_action = Action.idle()


## Wywoływane w każdej decyzji, zanim Sync odczyta obserwację i nagrodę.
func on_decision(obs: Observation) -> void:
	last_obs = obs
	_add(rewards.time_step + _stat_reward())
	if obs.opponent_visible:
		var aim_error: float = absf(angle_difference(obs.self_aim_angle, obs.opponent_relative_pos.angle()))
		if aim_error < deg_to_rad(rewards.aim_tolerance_deg):
			_add(rewards.aim_on_target)


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


func _stat_reward() -> float:
	var s: FighterStats = fighter.stats
	var value: float = (s.hits - _prev_hits) * rewards.hit \
			+ (s.damage_taken - _prev_damage) * rewards.damage_taken_per_hp \
			+ (s.self_hits - _prev_self_hits) * rewards.self_hit \
			+ (s.shots - _prev_shots) * rewards.shot \
			+ (s.pickups - _prev_pickups) * rewards.pickup
	_snapshot()
	return value


func _snapshot() -> void:
	var s: FighterStats = fighter.stats
	_prev_hits = s.hits
	_prev_shots = s.shots
	_prev_self_hits = s.self_hits
	_prev_damage = s.damage_taken
	_prev_pickups = s.pickups


func get_obs() -> Dictionary:
	return {"obs": ObservationEncoder.encode(last_obs, config)}


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
