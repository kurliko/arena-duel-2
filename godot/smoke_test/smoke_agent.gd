extends Node2D
## Agent smoke testu: ma dojść do celu. Ruch dyskretny (9 kierunków) jak w Action.

const SPEED: float = 300.0
const ARENA_HALF: Vector2 = Vector2(400.0, 250.0)
const REACH_DISTANCE: float = 25.0

var move_dir: int = 0
var reached_count: int = 0

@onready var ai_controller: SmokeAIController = $AIController2D
@onready var target: Node2D = $"../Target"
var _prev_distance: float = 0.0


func _ready() -> void:
	ai_controller.init(self)
	_reset()


func _physics_process(delta: float) -> void:
	if ai_controller.needs_reset:
		ai_controller.reset()
		_reset()
		return

	position += direction_of(move_dir) * SPEED * delta
	position = position.clamp(-ARENA_HALF, ARENA_HALF)

	var distance: float = position.distance_to(target.position)
	ai_controller.reward += (_prev_distance - distance) / 100.0
	_prev_distance = distance
	if distance < REACH_DISTANCE:
		reached_count += 1
		print("smoke_test: cel osiągnięty (", reached_count, ")")
		ai_controller.reward += 1.0
		ai_controller.done = true
		ai_controller.needs_reset = true


func _reset() -> void:
	position = Vector2(randf_range(-ARENA_HALF.x, ARENA_HALF.x), randf_range(-ARENA_HALF.y, ARENA_HALF.y))
	target.position = Vector2(randf_range(-ARENA_HALF.x, ARENA_HALF.x), randf_range(-ARENA_HALF.y, ARENA_HALF.y))
	_prev_distance = position.distance_to(target.position)
	move_dir = 0


static func direction_of(move: int) -> Vector2:
	if move == 0:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(deg_to_rad(45.0 * (move - 1)))
