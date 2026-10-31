class_name ArenaSync
extends "res://addons/godot_rl_agents/sync.gd"
## Węzeł Sync z Godot RL Agents sterowany zegarem decyzji gry zamiast własnego licznika kroków.
## Oryginalny Sync wymienia dane z Pythonem co action_repeat ticków liczonych od startu sceny, niezależnie
## od tego, kiedy decydują pozostałe mózgi. Tu step() woła MatchManager (albo TrainingScene) w tickach decyzji:
## po zebraniu obserwacji, a przed wykonaniem akcji, więc bot RL decyduje w tych samych tickach co inne mózgi
## i na podstawie aktualnej obserwacji.


func _physics_process(_delta: float) -> void:
	pass


func step() -> void:
	if not initialized:
		return
	_training_process()
	_inference_process()
