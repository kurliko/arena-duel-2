class_name Fighter
extends CharacterBody2D
## Ciało bota: ruch z bezwładnością, obrót, strzał, unik, życie i amunicja.
## Nie podejmuje decyzji: wykonuje ostatnią Action ustawioną przez MatchManager.

signal shot_fired(shooter: Fighter, direction: Vector2)
signal died(fighter: Fighter)

const AIM_LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const HP_BAR_BG: Color = Color(0.0, 0.0, 0.0, 0.6)
const HP_BAR_FG: Color = Color(0.3, 0.9, 0.4)
const HP_BAR_SIZE: Vector2 = Vector2(36.0, 4.0)

var config: GameConfig
var color: Color = Color.WHITE
var label: String = ""

var hp: float = 0.0
var ammo: int = 0
var aim_angle: float = 0.0
var shot_cooldown_left: float = 0.0
var dash_cooldown_left: float = 0.0
var active: bool = false
var current_action: Action = Action.idle()
var stats: FighterStats = FighterStats.new()


func setup(cfg: GameConfig, fighter_color: Color, fighter_label: String) -> void:
	config = cfg
	color = fighter_color
	label = fighter_label
	name = "Fighter" + fighter_label
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = PhysicsLayers.FIGHTERS
	collision_mask = PhysicsLayers.WALLS | PhysicsLayers.FIGHTERS
	var shape := CircleShape2D.new()
	shape.radius = config.fighter_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)


func reset_at(spawn_position: Vector2, facing_angle: float) -> void:
	position = spawn_position
	aim_angle = facing_angle
	velocity = Vector2.ZERO
	hp = config.max_hp
	ammo = config.start_ammo
	shot_cooldown_left = 0.0
	dash_cooldown_left = 0.0
	current_action = Action.idle()
	stats = FighterStats.new()
	active = true
	queue_redraw()


func apply_action(action: Action) -> void:
	current_action = action


func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(aim_angle)


func is_alive() -> bool:
	return hp > 0.0


func add_ammo(amount: int) -> void:
	ammo = mini(ammo + amount, config.max_ammo)


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = maxf(hp - amount, 0.0)
	stats.damage_taken += amount
	queue_redraw()
	if not is_alive():
		died.emit(self)


func _physics_process(delta: float) -> void:
	if not active:
		return
	shot_cooldown_left = maxf(shot_cooldown_left - delta, 0.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	_apply_turn(delta)
	_apply_movement(delta)
	_apply_shoot()
	move_and_slide()
	queue_redraw()


func _apply_turn(delta: float) -> void:
	var turn_speed: float = deg_to_rad(config.turn_rate_deg) * delta
	match current_action.turn:
		Action.TURN_LEFT:
			aim_angle -= turn_speed
		Action.TURN_RIGHT:
			aim_angle += turn_speed
		Action.TURN_LEFT_FINE:
			aim_angle -= turn_speed * config.fine_turn_factor
		Action.TURN_RIGHT_FINE:
			aim_angle += turn_speed * config.fine_turn_factor
	aim_angle = wrapf(aim_angle, -PI, PI)


func _apply_movement(delta: float) -> void:
	var move_dir: Vector2 = Action.move_vector(current_action.move)
	if current_action.dash and dash_cooldown_left <= 0.0:
		# Unik: impuls prędkości w kierunku ruchu, a bez ruchu w bok względem celowania.
		var dash_dir: Vector2 = move_dir if move_dir != Vector2.ZERO else aim_direction().orthogonal()
		velocity = dash_dir * config.dash_speed
		dash_cooldown_left = config.dash_cooldown
		stats.dashes += 1
		return
	if move_dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, config.friction * delta)
	else:
		velocity = velocity.move_toward(move_dir * config.max_speed, config.acceleration * delta)


func _apply_shoot() -> void:
	if not current_action.shoot or shot_cooldown_left > 0.0 or ammo <= 0:
		return
	ammo -= 1
	shot_cooldown_left = config.shot_cooldown
	stats.shots += 1
	shot_fired.emit(self, aim_direction())


func _draw() -> void:
	if config == null:
		return
	var r: float = config.fighter_radius
	draw_circle(Vector2.ZERO, r, color)
	draw_line(Vector2.ZERO, aim_direction() * (r + 12.0), AIM_LINE_COLOR, 3.0)
	var bar_pos := Vector2(-HP_BAR_SIZE.x / 2.0, -r - 10.0)
	draw_rect(Rect2(bar_pos, HP_BAR_SIZE), HP_BAR_BG)
	draw_rect(Rect2(bar_pos, Vector2(HP_BAR_SIZE.x * hp / config.max_hp, HP_BAR_SIZE.y)), HP_BAR_FG)
