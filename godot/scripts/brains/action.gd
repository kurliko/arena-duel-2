class_name Action
extends RefCounted
## Decyzja bota. Wszystkie pola dyskretne, żeby ta sama przestrzeń akcji
## pasowała do każdego mózgu (w tym PPO ze Stable-Baselines3).

## Kierunki ruchu: 0 = stop, 1..8 = osiem kierunków co 45 stopni (1 = prawo, zgodnie z ruchem wskazówek zegara).
const MOVE_STOP: int = 0
const MOVE_DIRECTIONS: int = 9
## Obrót: 0 = brak, 1 = w lewo, 2 = w prawo.
const TURN_NONE: int = 0
const TURN_LEFT: int = 1
const TURN_RIGHT: int = 2
const TURN_OPTIONS: int = 3

var move: int = MOVE_STOP
var turn: int = TURN_NONE
var shoot: bool = false
var dash: bool = false


static func idle() -> Action:
	return Action.new()
