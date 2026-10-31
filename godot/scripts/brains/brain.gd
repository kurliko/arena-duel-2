class_name Brain
extends RefCounted
## Wspólny interfejs mózgu. Mózg nie odwołuje się do węzłów sceny:
## dostaje Observation, zwraca Action.

## Wywoływane w każdej decyzji przed decide() dla obu botów (i przed wymianą danych z Pythonem/ONNX).
## Domyślnie nic nie robi; RLBrain przekazuje tu obserwację do polityki.
func observe(_observation: Observation) -> void:
	pass


func decide(_observation: Observation) -> Action:
	push_error("Brain.decide() musi być nadpisane w podklasie.")
	return Action.idle()


## Wywoływane na początku meczu (np. reset stanu wewnętrznego, ustawienie seeda).
func reset(_rng_seed: int) -> void:
	pass
