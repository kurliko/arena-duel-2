class_name MatchResult
extends RefCounted
## Wynik jednego meczu.

const WINNER_A: String = "A"
const WINNER_B: String = "B"
const DRAW: String = "draw"

const REASON_DEATH: String = "death"
const REASON_TIME: String = "time"

var match_index: int = 0
var rng_seed: int = 0
## Nazwa pliku konfiguracji (np. default), do rozróżniania eksperymentów.
var config_name: String = ""
## Czy A startował z punktu strony B (zmiana stron co mecz).
var sides_swapped: bool = false
var brain_a: String = ""
var brain_b: String = ""
var winner: String = DRAW
var reason: String = REASON_TIME
var duration: float = 0.0
var hp_a: float = 0.0
var hp_b: float = 0.0
var stats_a: FighterStats
var stats_b: FighterStats


func summary() -> String:
	return ("mecz %d: %s (A) vs %s (B) -> %s [%s, %.1f s] HP %.0f/%.0f, trafienia %d/%d, strzały %d/%d, "
			+ "rykoszety %d/%d, samotrafienia %d/%d, uniki %d/%d, pakiety %d/%d") % [
		match_index, brain_a, brain_b, winner, reason, duration, hp_a, hp_b,
		stats_a.hits, stats_b.hits, stats_a.shots, stats_b.shots,
		stats_a.ricochet_hits, stats_b.ricochet_hits, stats_a.self_hits, stats_b.self_hits,
		stats_a.dashes, stats_b.dashes, stats_a.pickups, stats_b.pickups,
	]
