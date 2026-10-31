class_name ScriptedBrain
extends Brain
## Prosta maszyna stanów (FSM): klasyczne AI z gier jako punkt odniesienia i etap curriculum RL.
## Stany: LECZENIE, AMUNICJA, ATAK, SZUKANIE (w tej kolejności priorytetu); niezależnie od stanu
## zryw przed nadlatującym pociskiem.
## Zachowania pochodzą ze wspólnego modułu Behaviors (te same co w FuzzyBrain).

enum State { ATTACK, SEEK_AMMO, SEARCH, HEAL }

## Próg HP (ułamek), poniżej którego bot idzie po apteczkę.
const HEAL_HP_THRESHOLD: float = 0.4

var state: State = State.SEARCH
var _behaviors: Behaviors


func _init(config: GameConfig) -> void:
	_behaviors = Behaviors.new(config)


func reset(rng_seed: int) -> void:
	_behaviors.reset(rng_seed)
	state = State.SEARCH


func decide(obs: Observation) -> Action:
	_behaviors.observe(obs)
	var action := Action.new()

	if obs.self_hp <= HEAL_HP_THRESHOLD and obs.medkit_available:
		state = State.HEAL
	elif obs.self_ammo <= 0.0 and obs.ammo_pickup_available:
		state = State.SEEK_AMMO
	elif obs.opponent_visible:
		state = State.ATTACK
	else:
		state = State.SEARCH

	match state:
		State.ATTACK:
			_behaviors.attack(obs, action)
		State.SEEK_AMMO:
			_behaviors.seek_ammo(obs, action)
		State.HEAL:
			_behaviors.seek_medkit(obs, action)
		State.SEARCH:
			_behaviors.search(obs, action)

	_behaviors.dodge_if_threatened(obs, action)
	return action
