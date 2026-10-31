class_name RLBrain
extends Brain
## Bot RL: polityka PPO działa poza tym obiektem (proces Pythona podczas treningu albo model ONNX w grze).
## RLBrain przekazuje obserwację do RLController i zwraca akcję, którą Sync zdążył ustawić w tej samej decyzji.

var controller: RLController


func _init(rl_controller: RLController) -> void:
	controller = rl_controller


func observe(obs: Observation) -> void:
	controller.on_decision(obs)


func decide(_obs: Observation) -> Action:
	return controller.current_action
