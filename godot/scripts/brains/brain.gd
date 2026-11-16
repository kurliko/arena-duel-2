class_name Brain
extends RefCounted

func observe(_observation: Observation) -> void:
	pass


func decide(_observation: Observation) -> Action:
	push_error("Brain.decide() musi być nadpisane w podklasie.")
	return Action.idle()


func reset(_rng_seed: int) -> void:
	pass
