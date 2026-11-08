extends Node2D
## Scena treningowa bota RL: wiele niezależnych aren (kopie scenes/match.tscn przesunięte w przestrzeni),
## w każdej bot RL (A) kontra przeciwnik z curriculum (B). Jeden wspólny ArenaSync wymienia dane z Pythonem
## dla wszystkich aren naraz, a ten węzeł jest wspólnym zegarem decyzji.
##
## Argumenty użytkownika (po `--`): --arenas=N --opponent=random|scripted|fuzzy --seed=S --config=res://...
## Kilku przeciwników naraz: --opponent=scripted+fuzzy (areny dostają ich na zmianę: 0 skryptowy, 1 rozmyty, 2 skryptowy...),
## żeby bot nie zapominał jednego przeciwnika, ucząc się drugiego.
## Argument Godot RL Agents (przed `--`): --speedup=K (przyspieszenie symulacji przy stałym kroku fizyki).

const MATCH_SCENE: PackedScene = preload("res://scenes/match.tscn")
## Odstęp między arenami (większy niż arena ze ścianami, żeby się nie stykały).
const ARENA_SPACING: Vector2 = Vector2(1400.0, 900.0)
const ARENA_COLUMNS: int = 4
## Ziarna kolejnych aren różnią się o tyle, żeby serie meczów się nie pokrywały.
const SEED_STRIDE: int = 100000
## Separator nazw przeciwników w --opponent.
const OPPONENT_SEPARATOR: String = "+"

@export var arena_count: int = 8
## Nazwa mózgu przeciwnika albo kilka nazw oddzielonych OPPONENT_SEPARATOR.
@export var opponent: String = BrainFactory.RANDOM
@export var base_seed: int = 0
@export var config: GameConfig = preload("res://data/configs/default.tres")

var match_managers: Array[MatchManager] = []
var sync: ArenaSync
var _tick: int = 0


func _ready() -> void:
	# Zegar decyzji przed MatchManagerami (-10), postaciami i pociskami.
	process_physics_priority = -20
	_apply_command_line()
	print("trening: %d aren, przeciwnik %s, seed %d" % [arena_count, opponent, base_seed])
	for i: int in arena_count:
		_add_arena(i)
	sync = ArenaSync.new()
	sync.name = "ArenaSync"
	sync.control_mode = 1  # Sync.ControlModes.TRAINING
	add_child(sync)


func _apply_command_line() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	if args.has("config"):
		config = load(args["config"]) as GameConfig
	arena_count = int(args.get("arenas", arena_count))
	opponent = args.get("opponent", opponent)
	base_seed = int(args.get("seed", base_seed))


func _add_arena(index: int) -> void:
	var match_root: Node2D = MATCH_SCENE.instantiate()
	# Trening nie potrzebuje kamery ani HUD-u.
	match_root.get_node("Camera2D").free()
	match_root.get_node("HUD").free()
	var arena_config: GameConfig = config.duplicate()
	arena_config.rng_seed = base_seed + index * SEED_STRIDE
	arena_config.between_matches_delay = 0.0
	var manager: MatchManager = match_root.get_node("MatchManager")
	manager.read_command_line = false
	manager.config = arena_config
	manager.brain_a_name = BrainFactory.RL
	var opponents: PackedStringArray = opponent.split(OPPONENT_SEPARATOR, false)
	manager.brain_b_name = opponents[index % opponents.size()]
	manager.external_clock = true
	manager.quiet = true
	match_root.position = Vector2(index % ARENA_COLUMNS, index / ARENA_COLUMNS) * ARENA_SPACING
	add_child(match_root)
	match_managers.append(manager)


func _physics_process(_delta: float) -> void:
	if _tick % config.decision_interval_ticks == 0:
		for manager: MatchManager in match_managers:
			manager.collect_observations()
		sync.step()
		for manager: MatchManager in match_managers:
			manager.apply_decisions()
	_tick += 1
