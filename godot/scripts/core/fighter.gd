class_name Fighter
extends RigidBody2D
## Ciało bota jako ciało sztywne symulowane przez silnik fizyki:
## - ruch: siła napędu F w kierunku akcji, tłumienie liniowe (opór), więc a = F/m i v_max = F/(m*c),
## - celowanie: obrót całego ciała momentem siły tau przy momencie bezwładności I (eps = tau/I) i tłumieniu kątowym,
## - unik: impuls (zmiana prędkości J/m), strzał: odrzut -m_p * v0 (III zasada dynamiki),
## - zderzenia z innymi ciałami (postacie, skrzynie, pociski) rozwiązuje silnik z masami i restytucją.
## Nie podejmuje decyzji: wykonuje ostatnią Action ustawioną przez MatchManager.

signal shot_fired(shooter: Fighter, direction: Vector2)
signal died(fighter: Fighter)

const OUTLINE_COLOR: Color = Color(0.05, 0.05, 0.08)
const BARREL_COLOR: Color = Color(0.85, 0.85, 0.9)
const BARREL_SIZE: Vector2 = Vector2(14.0, 6.0)
const HP_BAR_BG: Color = Color(0.0, 0.0, 0.0, 0.6)
const HP_BAR_FG: Color = Color(0.3, 0.9, 0.4)
const HP_BAR_LOW: Color = Color(0.95, 0.3, 0.25)
const HP_BAR_SIZE: Vector2 = Vector2(36.0, 4.0)

var config: GameConfig
var color: Color = Color.WHITE
var label: String = ""

var hp: float = 0.0
var ammo: int = 0
var shot_cooldown_left: float = 0.0
var dash_cooldown_left: float = 0.0
var active: bool = false
var current_action: Action = Action.idle()
var stats: FighterStats = FighterStats.new()

## Kąt celowania = obrót ciała (broń jest sztywno związana z postacią).
var aim_angle: float:
	get:
		return wrapf(rotation, -PI, PI)

var _pending_reset: bool = false
var _reset_transform: Transform2D


func setup(cfg: GameConfig, fighter_color: Color, fighter_label: String) -> void:
	config = cfg
	color = fighter_color
	label = fighter_label
	name = "Fighter" + fighter_label
	gravity_scale = 0.0
	can_sleep = false
	mass = config.fighter_mass
	inertia = config.fighter_inertia
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = config.fighter_linear_damp
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = config.fighter_angular_damp
	# Tarcie zerowe: kontakt ze ścianą nie obraca postaci, obrót pochodzi tylko z momentu siły.
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = config.fighter_restitution
	physics_material_override = material
	collision_layer = PhysicsLayers.FIGHTERS
	collision_mask = PhysicsLayers.WALLS | PhysicsLayers.FIGHTERS | PhysicsLayers.CRATES | PhysicsLayers.PROJECTILES
	var shape := CircleShape2D.new()
	shape.radius = config.fighter_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


## Ustawienie na pozycji startowej. Stan ciała sztywnego zmieniamy w _integrate_forces, a nie przez
## bezpośrednie przypisanie, żeby silnik fizyki nie nadpisał pozycji i prędkości.
func reset_at(spawn_position: Vector2, facing_angle: float) -> void:
	_reset_transform = Transform2D(facing_angle, spawn_position)
	_pending_reset = true
	position = spawn_position
	rotation = facing_angle
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	hp = config.max_hp
	ammo = config.start_ammo
	shot_cooldown_left = 0.0
	dash_cooldown_left = 0.0
	current_action = Action.idle()
	stats = FighterStats.new()
	active = true
	queue_redraw()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _pending_reset:
		state.transform = _reset_transform
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		_pending_reset = false


func apply_action(action: Action) -> void:
	current_action = action


func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


func is_alive() -> bool:
	return hp > 0.0


func add_ammo(amount: int) -> void:
	ammo = mini(ammo + amount, config.max_ammo)


func heal(amount: float) -> void:
	hp = minf(hp + amount, config.max_hp)
	queue_redraw()


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	var dealt: float = minf(amount, hp)
	hp -= dealt
	stats.damage_taken += dealt
	queue_redraw()
	if not is_alive():
		died.emit(self)


func _physics_process(delta: float) -> void:
	if not active:
		return
	shot_cooldown_left = maxf(shot_cooldown_left - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	_apply_turn()
	_apply_movement()
	_apply_shoot()
	queue_redraw()


## Moment siły dla obrotu (siły i momenty przyłożone w tym ticku działają przez jeden krok fizyki).
func _apply_turn() -> void:
	var torque: float = 0.0
	match current_action.turn:
		Action.TURN_LEFT:
			torque = -config.turn_torque
		Action.TURN_RIGHT:
			torque = config.turn_torque
		Action.TURN_LEFT_FINE:
			torque = -config.turn_torque * config.fine_turn_factor
		Action.TURN_RIGHT_FINE:
			torque = config.turn_torque * config.fine_turn_factor
	if torque != 0.0:
		apply_torque(torque)


func _apply_movement() -> void:
	var move_dir: Vector2 = Action.move_vector(current_action.move)
	if current_action.dash and dash_cooldown_left <= 0.0:
		# Unik: impuls w kierunku ruchu, a bez ruchu w bok względem celowania.
		var dash_dir: Vector2 = move_dir if move_dir != Vector2.ZERO else aim_direction().orthogonal()
		apply_central_impulse(dash_dir * config.dash_impulse)
		dash_cooldown_left = config.dash_cooldown
		stats.dashes += 1
	if move_dir != Vector2.ZERO:
		apply_central_force(move_dir * config.move_force)


func _apply_shoot() -> void:
	if not current_action.shoot or shot_cooldown_left > 0.0 or ammo <= 0:
		return
	ammo -= 1
	shot_cooldown_left = config.shot_cooldown
	stats.shots += 1
	var direction: Vector2 = aim_direction()
	# Odrzut: pęd pocisku m_p * v0 oddany strzelcowi w przeciwnym kierunku.
	apply_central_impulse(-direction * config.projectile_mass * config.projectile_speed)
	shot_fired.emit(self, direction)


func _draw() -> void:
	if config == null:
		return
	var r: float = config.fighter_radius
	# Rysowanie w układzie ciała (obraca się razem z celowaniem): korpus i lufa.
	draw_rect(Rect2(Vector2(r - 4.0, -BARREL_SIZE.y / 2.0), BARREL_SIZE), BARREL_COLOR)
	draw_circle(Vector2.ZERO, r + 2.0, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, r, color)
	draw_circle(Vector2(r * 0.35, 0.0), r * 0.3, color.lightened(0.35))
	# Pasek HP w układzie świata (bez obrotu).
	draw_set_transform(Vector2.ZERO, -rotation)
	var bar_pos := Vector2(-HP_BAR_SIZE.x / 2.0, -r - 12.0)
	var fraction: float = hp / config.max_hp
	draw_rect(Rect2(bar_pos, HP_BAR_SIZE), HP_BAR_BG)
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_SIZE.x * fraction, HP_BAR_SIZE.y)), HP_BAR_FG.lerp(HP_BAR_LOW, 1.0 - fraction))
	draw_set_transform(Vector2.ZERO, 0.0)
