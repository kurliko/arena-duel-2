class_name Brain
extends RefCounted
## Wspólny interfejs mózgu. Mózg nie odwołuje się do węzłów sceny:
## dostaje Observation, zwraca Action.

func decide(_observation: Observation) -> Action:
	push_error("Brain.decide() musi być nadpisane w podklasie.")
	return Action.idle()


## Wywoływane na początku meczu (np. reset stanu wewnętrznego, ustawienie seeda).
func reset(_rng_seed: int) -> void:
	pass
