class_name OpponentMemory
extends RefCounted
## Pamięć bota RL o przeciwniku: ostatnio widziana pozycja i czas od tamtej chwili.
## Odpowiednik _last_seen we wspólnych zachowaniach (Behaviors), z których korzystają boty skryptowy i rozmyty,
## więc bot RL nie jest w gorszej sytuacji, gdy przeciwnik schowa się za przeszkodą.
## Liczona wyłącznie z własnych obserwacji bota (to stan mózgu, nie dodatkowa wiedza od gry).

var has_last_seen: bool = false
## Ostatnio widziana pozycja przeciwnika w układzie areny, w jednostkach Observation (jak self_position).
var last_seen_position: Vector2 = Vector2.ZERO
## time_left meczu w chwili ostatniego zobaczenia przeciwnika.
var _seen_at_time_left: float = 1.0


func reset() -> void:
	has_last_seen = false
	last_seen_position = Vector2.ZERO
	_seen_at_time_left = 1.0


func update(obs: Observation) -> void:
	if obs.opponent_visible:
		has_last_seen = true
		last_seen_position = obs.self_position + obs.opponent_relative_pos
		_seen_at_time_left = obs.time_left


## Ostatnio widziana pozycja przeciwnika względem bota (jednostki Observation).
func relative_position(obs: Observation) -> Vector2:
	return last_seen_position - obs.self_position


## Czas od ostatniego zobaczenia przeciwnika jako ułamek limitu meczu (0 = widoczny teraz).
func time_since_seen(obs: Observation) -> float:
	return clampf(_seen_at_time_left - obs.time_left, 0.0, 1.0)
