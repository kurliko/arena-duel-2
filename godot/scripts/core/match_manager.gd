class_name MatchManager
extends Node
## Przebieg meczów: start z ziarnem losowości, decyzje mózgów co decision_interval_ticks,
## koniec po śmierci bota albo limicie czasu, seria meczów ze zmianą stron.
##
## Argumenty użytkownika (po `--`): --brain-a=NAZWA --brain-b=NAZWA --matches=N --seed=S --config=res://...
##   --csv=ŚCIEŻKA (dopisywanie wyników; ścieżka względna liczona od katalogu repozytorium)
##   --rl-model=res://models/....onnx --rl-deterministic=1 --quiet=1
## Mózg "rl": bot sterowany polityką z Godot RL Agents (model ONNX w grze albo Python podczas treningu).

signal match_started(match_index: int)
signal match_finished(result: MatchResult)

const COLOR_A: Color = Color(0.3, 0.6, 1.0)
const COLOR_B: Color = Color(1.0, 0.4, 0.35)
const TIME_EPSILON: float = 1e-4

@export var config: GameConfig
@export var arena: Arena
@export var fighters_root: Node2D
@export var projectiles_root: Node2D
@export var pickups_root: Node2D
@export var crates_root: Node2D
@export var brain_a_name: String = BrainFactory.SCRIPTED
@export var brain_b_name: String = BrainFactory.RANDOM
## Liczba meczów do rozegrania, potem wyjście z gry (0 = bez końca).
@export var matches_to_play: int = 0
## Plik CSV z wynikami (pusty = bez zapisu).
@export var csv_path: String = ""
## Bez wypisywania wyniku każdego meczu (trening).
@export var quiet: bool = false
## false: ignoruj argumenty linii poleceń (TrainingScene ustawia parametry każdej areny sama).
@export var read_command_line: bool = true

@export_group("RL")
## Model ONNX dla mózgu "rl" przy grze bez Pythona.
@export var rl_model_path: String = "res://models/rl_brain.onnx"
## true: zawsze akcja o największym prawdopodobieństwie; false: losowanie z rozkładu polityki.
@export var rl_deterministic: bool = false
@export var reward_config: RewardConfig
## true: decyzje wyzwala zewnętrzny zegar (TrainingScene z wieloma arenami i wspólnym Sync).
@export var external_clock: bool = false

var fighter_a: Fighter
var fighter_b: Fighter
var brain_a: Brain
var brain_b: Brain
var pickups: Array[Pickup] = []
var crates: Array[Crate] = []

var match_index: int = 0
var elapsed: float = 0.0
var running: bool = false
var wins_a: int = 0
var wins_b: int = 0
var draws: int = 0

var _tick: int = 0
var _someone_died: bool = false
var _sides_swapped: bool = false
var _csv: CsvWriter
var _obs_a: Observation
var _obs_b: Observation
var controller_a: RLController
var controller_b: RLController
var _sync: ArenaSync


func _ready() -> void:
	# Decyzje zapadają przed ruchem postaci i pocisków w tym samym ticku.
	process_physics_priority = -10
	if read_command_line:
		_apply_command_line()
	if not csv_path.is_empty():
		_csv = CsvWriter.new()
		if _csv.open(csv_path) == OK:
			print("wyniki zapisywane do ", _csv.path)
	fighter_a = _create_fighter(COLOR_A, MatchResult.WINNER_A)
	fighter_b = _create_fighter(COLOR_B, MatchResult.WINNER_B)
	if brain_a_name == BrainFactory.RL:
		controller_a = _create_rl_controller(fighter_a)
	if brain_b_name == BrainFactory.RL:
		controller_b = _create_rl_controller(fighter_b)
	if (controller_a != null or controller_b != null) and not external_clock:
		_create_inference_sync()
	for point: Vector2 in arena.layout.pickup_points:
		_add_pickup(Pickup.Kind.AMMO, point)
	for point: Vector2 in arena.layout.medkit_points:
		_add_pickup(Pickup.Kind.MEDKIT, point)
	for point: Vector2 in arena.layout.crate_points:
		var crate := Crate.new()
		crate.setup(config)
		crates_root.add_child(crate)
		crates.append(crate)
	start_match()


func _apply_command_line() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	# Konfiguracja najpierw, żeby pozostałe argumenty (np. seed) trafiły do właściwego zasobu.
	if args.has("config"):
		config = load(args["config"]) as GameConfig
	brain_a_name = args.get("brain-a", brain_a_name)
	brain_b_name = args.get("brain-b", brain_b_name)
	matches_to_play = int(args.get("matches", matches_to_play))
	csv_path = args.get("csv", csv_path)
	rl_model_path = args.get("rl-model", rl_model_path)
	rl_deterministic = args.get("rl-deterministic", "1" if rl_deterministic else "0") == "1"
	quiet = args.get("quiet", "1" if quiet else "0") == "1"
	if args.has("seed"):
		config.rng_seed = int(args["seed"])


func _create_fighter(color: Color, label: String) -> Fighter:
	var fighter := Fighter.new()
	fighter.setup(config, color, label)
	fighter.shot_fired.connect(_on_shot_fired)
	fighter.died.connect(_on_fighter_died)
	fighters_root.add_child(fighter)
	return fighter


func _add_pickup(kind: Pickup.Kind, at: Vector2) -> void:
	var pickup := Pickup.new()
	pickup.setup(config, kind, at)
	pickups_root.add_child(pickup)
	pickups.append(pickup)


func _create_rl_controller(fighter: Fighter) -> RLController:
	if reward_config == null:
		reward_config = load("res://data/rl/reward_default.tres") as RewardConfig
	var controller := RLController.new()
	controller.setup(config, reward_config, fighter)
	fighter.add_child(controller)
	return controller


## Gra bez Pythona: Sync w trybie inferencji ONNX, wywoływany przez ten MatchManager w tickach decyzji.
func _create_inference_sync() -> void:
	_sync = ArenaSync.new()
	_sync.name = "ArenaSync"
	_sync.control_mode = 2  # Sync.ControlModes.ONNX_INFERENCE
	_sync.onnx_model_path = rl_model_path
	_sync.deterministic_inference = rl_deterministic
	add_child(_sync)


func _create_brain(brain_name: String, controller: RLController) -> Brain:
	if brain_name == BrainFactory.RL:
		return RLBrain.new(controller)
	return BrainFactory.create(brain_name, config)


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func start_match() -> void:
	var match_seed: int = config.rng_seed + match_index
	seed(match_seed)
	for projectile: Node in projectiles_root.get_children():
		projectile.queue_free()
	for pickup: Pickup in pickups:
		pickup.reset()
	for i: int in crates.size():
		crates[i].reset_at(arena.layout.crate_points[i])
	# Zmiana stron co mecz, żeby układ areny nie faworyzował żadnego mózgu.
	var swap: bool = match_index % 2 == 1
	_sides_swapped = swap
	var spawns: Array[Vector2] = arena.layout.spawn_points
	var spawn_a: Vector2 = spawns[1] if swap else spawns[0]
	var spawn_b: Vector2 = spawns[0] if swap else spawns[1]
	fighter_a.reset_at(spawn_a, (arena.center() - spawn_a).angle())
	fighter_b.reset_at(spawn_b, (arena.center() - spawn_b).angle())
	brain_a = _create_brain(brain_a_name, controller_a)
	brain_b = _create_brain(brain_b_name, controller_b)
	brain_a.reset(match_seed * 2)
	brain_b.reset(match_seed * 2 + 1)
	for controller: RLController in [controller_a, controller_b]:
		if controller != null:
			controller.begin_episode()
	_tick = 0
	elapsed = 0.0
	_someone_died = false
	running = true
	match_started.emit(match_index)


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _someone_died:
		_finish(MatchResult.REASON_DEATH)
		return
	if not external_clock and _tick % config.decision_interval_ticks == 0:
		collect_observations()
		if _sync != null:
			_sync.step()
		apply_decisions()
	_tick += 1
	elapsed += delta
	# Tolerancja na błąd zaokrąglenia sumy kroków (inaczej limit 60 s kończyłby się po 60,017 s).
	if elapsed >= config.max_match_seconds - TIME_EPSILON:
		_finish(MatchResult.REASON_TIME)


## Pierwsza połowa decyzji: obserwacje obu botów i przekazanie ich mózgom (Brain.observe).
func collect_observations() -> void:
	if not running:
		return
	var projectiles: Array[Projectile] = active_projectiles()
	_obs_a = Perception.build(fighter_a, fighter_b, arena, projectiles, pickups, crates, config)
	_obs_b = Perception.build(fighter_b, fighter_a, arena, projectiles, pickups, crates, config)
	var time_left: float = clampf(1.0 - elapsed / config.max_match_seconds, 0.0, 1.0)
	_obs_a.time_left = time_left
	_obs_b.time_left = time_left
	brain_a.observe(_obs_a)
	brain_b.observe(_obs_b)


## Druga połowa decyzji: akcje z mózgów trafiają do postaci.
func apply_decisions() -> void:
	if not running:
		return
	fighter_a.apply_action(brain_a.decide(_obs_a))
	fighter_b.apply_action(brain_b.decide(_obs_b))


func active_projectiles() -> Array[Projectile]:
	var result: Array[Projectile] = []
	for node: Node in projectiles_root.get_children():
		var projectile := node as Projectile
		if projectile != null and not projectile.is_queued_for_deletion():
			result.append(projectile)
	return result


func _on_shot_fired(shooter: Fighter, direction: Vector2) -> void:
	var projectile := Projectile.new()
	projectile.setup(config, shooter, direction)
	projectiles_root.add_child(projectile)
	Effects.spawn_muzzle_flash(projectiles_root, shooter.position + direction * (config.fighter_radius + 10.0),
			direction, shooter.color)


func _on_fighter_died(_fighter: Fighter) -> void:
	# Koniec meczu na początku następnego ticku, żeby objąć jednoczesną śmierć obu botów.
	_someone_died = true


func _finish(reason: String) -> void:
	running = false
	fighter_a.active = false
	fighter_b.active = false
	var result := MatchResult.new()
	result.match_index = match_index
	result.rng_seed = config.rng_seed + match_index
	result.config_name = config.resource_path.get_file().get_basename()
	result.sides_swapped = _sides_swapped
	result.brain_a = brain_a_name
	result.brain_b = brain_b_name
	result.reason = reason
	result.duration = elapsed
	result.hp_a = fighter_a.hp
	result.hp_b = fighter_b.hp
	result.stats_a = fighter_a.stats
	result.stats_b = fighter_b.stats
	result.winner = _decide_winner(reason)
	match result.winner:
		MatchResult.WINNER_A:
			wins_a += 1
		MatchResult.WINNER_B:
			wins_b += 1
		_:
			draws += 1
	if not quiet:
		print(result.summary())
	_end_rl_episodes(result.winner)
	if _csv != null:
		_csv.write(result, config)
	match_finished.emit(result)
	match_index += 1

	if matches_to_play > 0 and match_index >= matches_to_play:
		print("koniec serii: A (%s) %d, B (%s) %d, remisy %d" % [brain_a_name, wins_a, brain_b_name, wins_b, draws])
		if _csv != null:
			_csv.close()
		get_tree().quit()
		return
	if not is_headless():
		await get_tree().create_timer(config.between_matches_delay).timeout
	start_match()


func _end_rl_episodes(winner: String) -> void:
	if controller_a != null:
		controller_a.end_episode(_outcome_for(MatchResult.WINNER_A, winner))
	if controller_b != null:
		controller_b.end_episode(_outcome_for(MatchResult.WINNER_B, winner))


func _outcome_for(side: String, winner: String) -> String:
	if winner == MatchResult.DRAW:
		return "draw"
	return "win" if winner == side else "loss"


func _decide_winner(reason: String) -> String:
	if reason == MatchResult.REASON_TIME and not config.time_limit_winner_by_hp:
		return MatchResult.DRAW
	if fighter_a.hp > fighter_b.hp:
		return MatchResult.WINNER_A
	if fighter_b.hp > fighter_a.hp:
		return MatchResult.WINNER_B
	return MatchResult.DRAW
