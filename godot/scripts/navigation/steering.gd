class_name Steering
## Tłumaczenie zamiarów (idź w tym kierunku, wyceluj w ten kąt) na dyskretne pola Action.
## Wspólne dla mózgów skryptowego i rozmytego, żeby oba fizycznie robiły to samo.

const DIRECTION_STEP: float = PI / 4.0
## Błąd celowania (rad), poniżej którego nie przykładamy momentu siły.
const AIM_DEAD_ZONE: float = 0.02


## Indeks ruchu (Action.move) najbliższy podanemu kierunkowi; MOVE_STOP dla wektora zerowego.
static func move_toward(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return Action.MOVE_STOP
	return posmod(roundi(direction.angle() / DIRECTION_STEP), 8) + 1


## Obrót (Action.turn) w stronę target_angle przy obrocie z bezwładnością (regulator z przewidywaniem):
## bez momentu siły obracające się ciało przebędzie jeszcze kąt omega / c (tłumienie kątowe c),
## więc porównujemy z celem kąt, przy którym broń sama by się zatrzymała. Gdy broń obraca się szybko
## w stronę celu, przewidywany kąt go przekracza i wybierany jest moment hamujący (obrót w drugą stronę).
## angular_velocity jest znormalizowana jak w Observation (ułamek GameConfig.max_angular_speed()).
static func turn_toward(current_angle: float, angular_velocity: float, target_angle: float, config: GameConfig) -> int:
	var omega: float = angular_velocity * config.max_angular_speed()
	var coast: float = omega / config.fighter_angular_damp
	var error: float = angle_difference(current_angle + coast, target_angle)
	if absf(error) <= AIM_DEAD_ZONE:
		return Action.TURN_NONE
	if absf(error) <= turn_step_per_decision(config):
		return Action.TURN_RIGHT_FINE if error > 0.0 else Action.TURN_LEFT_FINE
	return Action.TURN_RIGHT if error > 0.0 else Action.TURN_LEFT


## Kąt (rad), o jaki obraca się broń między dwiema decyzjami przy granicznej prędkości kątowej.
static func turn_step_per_decision(config: GameConfig) -> float:
	var ticks_per_second: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	return config.max_angular_speed() * config.decision_interval_ticks / ticks_per_second
