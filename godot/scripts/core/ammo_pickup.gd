class_name AmmoPickup
extends Area2D
## Pakiet amunicji: podnosi go bot, który nie ma pełnej amunicji. Odnawia się po czasie.

const AVAILABLE_COLOR: Color = Color(1.0, 0.85, 0.2)
const EMPTY_COLOR: Color = Color(1.0, 0.85, 0.2, 0.15)

var config: GameConfig
var available: bool = true
var _respawn_left: float = 0.0


func setup(cfg: GameConfig, at: Vector2) -> void:
	config = cfg
	position = at
	collision_layer = PhysicsLayers.PICKUPS
	collision_mask = PhysicsLayers.FIGHTERS
	var shape := CircleShape2D.new()
	shape.radius = config.pickup_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func reset() -> void:
	available = true
	_respawn_left = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not available:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			reset()
		return
	for body: Node2D in get_overlapping_bodies():
		var fighter := body as Fighter
		if fighter != null and fighter.active and fighter.ammo < config.max_ammo:
			fighter.add_ammo(config.pickup_ammo)
			fighter.stats.pickups += 1
			available = false
			_respawn_left = config.pickup_respawn_seconds
			queue_redraw()
			return


func _draw() -> void:
	var r: float = config.pickup_radius
	draw_rect(Rect2(-r, -r, 2.0 * r, 2.0 * r), AVAILABLE_COLOR if available else EMPTY_COLOR)
