class_name Pickup
extends Area2D
## Pakiet do podniesienia: amunicja albo apteczka. Podnosi go bot, któremu się przyda
## (niepełna amunicja / niepełne HP). Po podniesieniu odnawia się po czasie.
## Apteczka to mechanika gry (leczenie), nie fizyka.

enum Kind { AMMO, MEDKIT }

const AMMO_BOX: Color = Color(0.25, 0.3, 0.2)
const AMMO_SHELL: Color = Color(1.0, 0.8, 0.25)
const AMMO_TIP: Color = Color(0.75, 0.45, 0.2)
const MEDKIT_BOX: Color = Color(0.95, 0.95, 0.95)
const MEDKIT_CROSS: Color = Color(0.85, 0.15, 0.15)
const EMPTY_ALPHA: float = 0.15
## Pulsowanie dostępnego pakietu (tylko grafika).
const PULSE_SPEED: float = 4.0
const PULSE_AMOUNT: float = 0.08

var kind: Kind = Kind.AMMO
var config: GameConfig
var available: bool = true
var _respawn_left: float = 0.0
var _time: float = 0.0


func setup(cfg: GameConfig, pickup_kind: Kind, at: Vector2) -> void:
	config = cfg
	kind = pickup_kind
	name = "Ammo" if kind == Kind.AMMO else "Medkit"
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
		if fighter != null and fighter.active and _useful_for(fighter):
			_apply_to(fighter)
			available = false
			_respawn_left = config.pickup_respawn_seconds if kind == Kind.AMMO else config.medkit_respawn_seconds
			queue_redraw()
			return


func _useful_for(fighter: Fighter) -> bool:
	if kind == Kind.AMMO:
		return fighter.ammo < config.max_ammo
	return fighter.hp < config.max_hp


func _apply_to(fighter: Fighter) -> void:
	if kind == Kind.AMMO:
		fighter.add_ammo(config.pickup_ammo)
		fighter.stats.pickups += 1
	else:
		fighter.heal(config.medkit_heal)
		fighter.stats.medkits += 1


func _process(delta: float) -> void:
	if available:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var alpha: float = 1.0 if available else EMPTY_ALPHA
	var r: float = config.pickup_radius * (1.0 + PULSE_AMOUNT * sin(_time * PULSE_SPEED) if available else 1.0)
	if kind == Kind.AMMO:
		_draw_ammo(r, alpha)
	else:
		_draw_medkit(r, alpha)


## Skrzynka z trzema nabojami.
func _draw_ammo(r: float, alpha: float) -> void:
	draw_rect(Rect2(-r, -r * 0.7, 2.0 * r, 1.4 * r), Color(AMMO_BOX, alpha))
	var shell_w: float = r * 0.38
	for i: int in 3:
		var x: float = -r * 0.62 + i * r * 0.62
		draw_rect(Rect2(x - shell_w / 2.0, -r * 0.35, shell_w, r * 0.9), Color(AMMO_SHELL, alpha))
		draw_circle(Vector2(x, -r * 0.35), shell_w / 2.0, Color(AMMO_TIP, alpha))


## Biała apteczka z czerwonym krzyżem.
func _draw_medkit(r: float, alpha: float) -> void:
	draw_rect(Rect2(-r, -r, 2.0 * r, 2.0 * r), Color(MEDKIT_BOX, alpha))
	var arm: float = r * 0.32
	draw_rect(Rect2(-arm, -r * 0.7, 2.0 * arm, r * 1.4), Color(MEDKIT_CROSS, alpha))
	draw_rect(Rect2(-r * 0.7, -arm, r * 1.4, 2.0 * arm), Color(MEDKIT_CROSS, alpha))
