class_name ArenaSync
extends "res://addons/godot_rl_agents/sync.gd"


# wylaczamy wlasny licznik Sync, step() wola MatchManager razem z decyzjami innych botow
func _physics_process(_delta: float) -> void:
	pass


func step() -> void:
	if not initialized:
		return
	_training_process()
	_inference_process()
