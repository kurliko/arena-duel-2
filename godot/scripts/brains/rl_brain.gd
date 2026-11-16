class_name RLBrain
extends Brain

var controller: RLController


func _init(rl_controller: RLController) -> void:
	controller = rl_controller


func observe(obs: Observation) -> void:
	controller.on_decision(obs)


func decide(_obs: Observation) -> Action:
	return controller.current_action
