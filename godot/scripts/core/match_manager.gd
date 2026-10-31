class_name MatchManager
extends Node
## Przebieg meczów: start z ziarnem losowości, decyzje mózgów co decision_interval_ticks,
## koniec po śmierci bota albo limicie czasu, seria meczów ze zmianą stron.
##
## Argumenty użytkownika (po `--`): --brain-a=NAZWA --brain-b=NAZWA --matches=N --seed=S --config=res://...
##   --csv=ŚCIEŻKA (dopisywanie wyników; ścieżka względna liczona od katalogu repozytorium)

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
@export var brain_a_name: String = BrainFactory.SCRIPTED
@export var brain_b_name: String = BrainFactory.RANDOM
## Liczba meczów do rozegrania, potem wyjście z gry (0 = bez końca).
@export var matches_to_play: int = 0
## Plik CSV z wynikami (pusty = bez zapisu).
@export var csv_path: String = ""

var fighter_a: Fighter
var fighter_b: Fighter
var brain_a: Brain
var brain_b: Brain
var pickups: Array[AmmoPickup] = []

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


func _ready() -> void:
	# Decyzje zapadają przed ruchem postaci i pocisków w tym samym ticku.
	process_physics_priority = -10
	_apply_command_line()
	if not csv_path.is_empty():
		_csv = CsvWriter.new()
		if _csv.open(csv_path) == OK:
			print("wyniki zapisywane do ", _csv.path)
	fighter_a = _create_fighter(COLOR_A, MatchResult.WINNER_A)
	fighter_b = _create_fighter(COLOR_B, MatchResult.WINNER_B)
	for point: Vector2 in arena.layout.pickup_points:
		var pickup := AmmoPickup.new()
		pickup.setup(config, point)
		pickups_root.add_child(pickup)
		pickups.append(pickup)
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
	if args.has("seed"):
		config.rng_seed = int(args["seed"])


func _create_fighter(color: Color, label: String) -> Fighter:
	var fighter := Fighter.new()
	fighter.setup(config, color, label)
	fighter.shot_fired.connect(_on_shot_fired)
	fighter.died.connect(_on_fighter_died)
	fighters_root.add_child(fighter)
	return fighter


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func start_match() -> void:
	var match_seed: int = config.rng_seed + match_index
	seed(match_seed)
	for projectile: Node in projectiles_root.get_children():
		projectile.queue_free()
	for pickup: AmmoPickup in pickups:
		pickup.reset()
	# Zmiana stron co mecz, żeby układ areny nie faworyzował żadnego mózgu.
	var swap: bool = match_index % 2 == 1
	_sides_swapped = swap
	var spawns: Array[Vector2] = arena.layout.spawn_points
	var spawn_a: Vector2 = spawns[1] if swap else spawns[0]
	var spawn_b: Vector2 = spawns[0] if swap else spawns[1]
	fighter_a.reset_at(spawn_a, (arena.center() - spawn_a).angle())
	fighter_b.reset_at(spawn_b, (arena.center() - spawn_b).angle())
	brain_a = BrainFactory.create(brain_a_name, config)
	brain_b = BrainFactory.create(brain_b_name, config)
	brain_a.reset(match_seed * 2)
	brain_b.reset(match_seed * 2 + 1)
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
	if _tick % config.decision_interval_ticks == 0:
		var projectiles: Array[Projectile] = active_projectiles()
		fighter_a.apply_action(brain_a.decide(
				Perception.build(fighter_a, fighter_b, arena, projectiles, pickups, config)))
		fighter_b.apply_action(brain_b.decide(
				Perception.build(fighter_b, fighter_a, arena, projectiles, pickups, config)))
	_tick += 1
	elapsed += delta
	# Tolerancja na błąd zaokrąglenia sumy kroków (inaczej limit 60 s kończyłby się po 60,017 s).
	if elapsed >= config.max_match_seconds - TIME_EPSILON:
		_finish(MatchResult.REASON_TIME)


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
	print(result.summary())
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


func _decide_winner(reason: String) -> String:
	if reason == MatchResult.REASON_TIME and not config.time_limit_winner_by_hp:
		return MatchResult.DRAW
	if fighter_a.hp > fighter_b.hp:
		return MatchResult.WINNER_A
	if fighter_b.hp > fighter_a.hp:
		return MatchResult.WINNER_B
	return MatchResult.DRAW
