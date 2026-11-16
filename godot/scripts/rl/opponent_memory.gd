class_name OpponentMemory
extends RefCounted

var has_last_seen: bool = false
var last_seen_position: Vector2 = Vector2.ZERO
var _seen_at_time_left: float = 1.0


func reset() -> void:
	has_last_seen = false
	last_seen_position = Vector2.ZERO
	_seen_at_time_left = 1.0


func update(obs: Observation) -> void:
	if obs.opponent_visible:
		has_last_seen = true
		last_seen_position = obs.self_position + obs.opponent_relative_pos
		_seen_at_time_left = obs.time_left


func relative_position(obs: Observation) -> Vector2:
	return last_seen_position - obs.self_position


func time_since_seen(obs: Observation) -> float:
	return clampf(_seen_at_time_left - obs.time_left, 0.0, 1.0)
