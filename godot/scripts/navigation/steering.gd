class_name Steering
## Tłumaczenie zamiarów (idź w tym kierunku, wyceluj w ten kąt) na dyskretne pola Action.
## Wspólne dla mózgów skryptowego i rozmytego, żeby oba fizycznie robiły to samo.

const DIRECTION_STEP: float = PI / 4.0


## Indeks ruchu (Action.move) najbliższy podanemu kierunkowi; MOVE_STOP dla wektora zerowego.
static func move_toward(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return Action.MOVE_STOP
	return posmod(roundi(direction.angle() / DIRECTION_STEP), 8) + 1


## Obrót (Action.turn) w stronę target_angle. Kroki to obrót w czasie jednej decyzji.
static func turn_toward(current_angle: float, target_angle: float, config: GameConfig) -> int:
	var diff: float = angle_difference(current_angle, target_angle)
	var coarse_step: float = turn_step_per_decision(config)
	var fine_step: float = coarse_step * config.fine_turn_factor
	if absf(diff) <= fine_step / 2.0:
		return Action.TURN_NONE
	if absf(diff) <= coarse_step:
		return Action.TURN_RIGHT_FINE if diff > 0.0 else Action.TURN_LEFT_FINE
	return Action.TURN_RIGHT if diff > 0.0 else Action.TURN_LEFT


## Kąt (rad), o jaki zwykły obrót zmienia celowanie między dwiema decyzjami.
static func turn_step_per_decision(config: GameConfig) -> float:
	var ticks_per_second: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	return deg_to_rad(config.turn_rate_deg) * config.decision_interval_ticks / ticks_per_second
