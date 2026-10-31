class_name SmokeAIController
extends AIController2D


func get_obs() -> Dictionary:
	var agent := _player as Node2D
	var target: Node2D = agent.get_node("../Target")
	var relative: Vector2 = (target.position - agent.position) / 800.0
	return {"obs": [relative.x, relative.y, agent.position.x / 400.0, agent.position.y / 250.0]}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	return {
		"move": {"size": 9, "action_type": "discrete"},
		"shoot": {"size": 2, "action_type": "discrete"},
	}


func set_action(action) -> void:
	_player.move_dir = int(action["move"])
