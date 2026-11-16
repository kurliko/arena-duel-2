class_name Steering

const DIRECTION_STEP: float = PI / 4.0
const AIM_DEAD_ZONE: float = 0.02


static func move_toward(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return Action.MOVE_STOP
	return posmod(roundi(direction.angle() / DIRECTION_STEP), 8) + 1


static func turn_toward(current_angle: float, angular_velocity: float, target_angle: float, config: GameConfig) -> int:
	var omega: float = angular_velocity * config.max_angular_speed()
	# gdzie bron zatrzyma sie sama, jak to juz za celem to hamujemy
	var coast: float = omega / config.fighter_angular_damp
	var error: float = angle_difference(current_angle + coast, target_angle)
	if absf(error) <= AIM_DEAD_ZONE:
		return Action.TURN_NONE
	if absf(error) <= turn_step_per_decision(config):
		return Action.TURN_RIGHT_FINE if error > 0.0 else Action.TURN_LEFT_FINE
	return Action.TURN_RIGHT if error > 0.0 else Action.TURN_LEFT


static func turn_step_per_decision(config: GameConfig) -> float:
	var ticks_per_second: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	return config.max_angular_speed() * config.decision_interval_ticks / ticks_per_second
