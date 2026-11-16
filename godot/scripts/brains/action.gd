class_name Action
extends RefCounted

const MOVE_STOP: int = 0
const MOVE_DIRECTIONS: int = 9
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


static func move_vector(move_index: int) -> Vector2:
	if move_index == MOVE_STOP:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(deg_to_rad(45.0 * (move_index - 1)))
