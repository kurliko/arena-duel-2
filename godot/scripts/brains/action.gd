class_name Action
extends RefCounted
## Decyzja bota. Wszystkie pola dyskretne, żeby ta sama przestrzeń akcji
## pasowała do każdego mózgu (w tym PPO ze Stable-Baselines3).

## Kierunki ruchu: 0 = stop, 1..8 = osiem kierunków co 45 stopni (1 = prawo, zgodnie z ruchem wskazówek zegara).
const MOVE_STOP: int = 0
const MOVE_DIRECTIONS: int = 9
## Obrót: 0 = brak, 1/2 = w lewo/prawo, 3/4 = precyzyjnie w lewo/prawo (GameConfig.fine_turn_factor).
const TURN_NONE: int = 0
const TURN_LEFT: int = 1
const TURN_RIGHT: int = 2
const TURN_LEFT_FINE: int = 3
const TURN_RIGHT_FINE: int = 4
const TURN_OPTIONS: int = 5

var move: int = MOVE_STOP
var turn: int = TURN_NONE
var shoot: bool = false
var dash: bool = false


static func idle() -> Action:
	return Action.new()


## Wektor jednostkowy kierunku ruchu (zero dla MOVE_STOP).
static func move_vector(move_index: int) -> Vector2:
	if move_index == MOVE_STOP:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(deg_to_rad(45.0 * (move_index - 1)))
