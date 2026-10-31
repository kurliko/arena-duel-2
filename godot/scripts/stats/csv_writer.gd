class_name CsvWriter
extends RefCounted
## Dopisywanie wyników meczów do pliku CSV (jeden wiersz na mecz).
## Nagłówek jest zapisywany, gdy plik jest nowy lub pusty, więc kolejne serie można dopisywać do tego samego pliku.

## Parametry konfiguracji zapisywane w każdym wierszu (do eksperymentów z fizyką).
const CONFIG_COLUMNS: Array[String] = [
	"projectile_speed", "projectile_mass", "projectile_linear_damp", "projectile_restitution", "max_bounces",
	"fighter_mass", "fighter_inertia", "move_force", "fighter_linear_damp", "crate_mass",
]
const FIGHTER_COLUMNS: Array[String] = [
	"hp", "shots", "hits", "accuracy", "ammo_used", "damage_dealt", "damage_taken", "medkits",
	"ricochet_hits", "self_hits", "dashes", "pickups",
]

var path: String
var _file: FileAccess


## Ścieżka względna jest liczona od katalogu głównego repozytorium (nadrzędnego wobec godot/).
static func resolve_path(raw_path: String) -> String:
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return ProjectSettings.globalize_path(raw_path)
	if raw_path.is_absolute_path():
		return raw_path
	var repo_root: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	return repo_root.path_join(raw_path)


func open(raw_path: String) -> Error:
	path = resolve_path(raw_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var exists: bool = FileAccess.file_exists(path)
	_file = FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if _file == null:
		push_error("Nie można otworzyć CSV %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	_file.seek_end()
	if _file.get_position() == 0:
		_file.store_csv_line(header())
	return OK


static func header() -> PackedStringArray:
	var columns := PackedStringArray([
		"match_index", "seed", "config", "brain_a", "brain_b", "sides_swapped",
		"winner", "winner_brain", "reason", "duration",
	])
	for side: String in ["a", "b"]:
		for column: String in FIGHTER_COLUMNS:
			columns.append("%s_%s" % [column, side])
	columns.append_array(CONFIG_COLUMNS)
	return columns


func write(result: MatchResult, config: GameConfig) -> void:
	if _file == null:
		return
	var winner_brain: String = ""
	match result.winner:
		MatchResult.WINNER_A:
			winner_brain = result.brain_a
		MatchResult.WINNER_B:
			winner_brain = result.brain_b
	var row := PackedStringArray([
		str(result.match_index), str(result.rng_seed), result.config_name, result.brain_a, result.brain_b,
		str(int(result.sides_swapped)), result.winner, winner_brain, result.reason, "%.3f" % result.duration,
	])
	row.append_array(_fighter_values(result.hp_a, result.stats_a))
	row.append_array(_fighter_values(result.hp_b, result.stats_b))
	for column: String in CONFIG_COLUMNS:
		row.append(str(config.get(column)))
	_file.store_csv_line(row)
	_file.flush()


func _fighter_values(hp: float, stats: FighterStats) -> PackedStringArray:
	return PackedStringArray([
		"%.1f" % hp, str(stats.shots), str(stats.hits), "%.3f" % stats.accuracy(), str(stats.shots),
		"%.1f" % stats.damage_dealt, "%.1f" % stats.damage_taken, str(stats.medkits), str(stats.ricochet_hits), str(stats.self_hits),
		str(stats.dashes), str(stats.pickups),
	])


func close() -> void:
	if _file != null:
		_file.close()
		_file = null
