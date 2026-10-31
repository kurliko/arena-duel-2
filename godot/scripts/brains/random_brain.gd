class_name RandomBrain
extends Brain
## Losowe akcje: dolna granica skuteczności i pierwszy przeciwnik w curriculum.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset(rng_seed: int) -> void:
	_rng.seed = rng_seed


func decide(_observation: Observation) -> Action:
	var action := Action.new()
	action.move = _rng.randi_range(0, Action.MOVE_DIRECTIONS - 1)
	action.turn = _rng.randi_range(0, Action.TURN_OPTIONS - 1)
	action.shoot = _rng.randf() < 0.3
	action.dash = _rng.randf() < 0.05
	return action
