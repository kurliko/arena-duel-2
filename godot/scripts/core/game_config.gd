class_name GameConfig
extends Resource
## Wszystkie parametry gry i fizyki w jednym miejscu (bez magicznych liczb w kodzie).
## Zestawy parametrów zapisujemy jako pliki .tres w data/configs/.
##
## Model fizyczny: postacie, pociski i skrzynie to ciała sztywne (RigidBody2D) symulowane przez silnik
## fizyki Godota. Sterujemy siłami, momentami sił i impulsami; prędkości graniczne wynikają z równowagi
## siły napędu i tłumienia (v_max = F / (m * c)), a zderzenia rozwiązuje silnik z masami i restytucją.
## Jednostki: długość w pikselach, czas w sekundach, masa w umownych jednostkach.

@export_group("Match")
@export var rng_seed: int = 0
@export var max_match_seconds: float = 60.0
## Co ile ticków fizyki bot podejmuje decyzję (jednakowo dla obu botów).
@export var decision_interval_ticks: int = 4
## Po limicie czasu wygrywa bot z większym HP (przy równym HP remis). Wyłączone: zawsze remis.
@export var time_limit_winner_by_hp: bool = true
## Przerwa między meczami w trybie z grafiką (w trybie --headless pomijana).
@export var between_matches_delay: float = 1.5

@export_group("Fighter")
@export var fighter_radius: float = 16.0
@export var fighter_mass: float = 10.0
## Siła napędu przy akcji ruchu.
@export var move_force: float = 8800.0
## Tłumienie liniowe (opór i tarcie o podłoże, 1/s): stała czasowa rozpędzania i hamowania = 1 / tłumienie.
@export var fighter_linear_damp: float = 4.0
## Moment bezwładności względem środka masy (dla walca m*r^2/2 = 1280).
@export var fighter_inertia: float = 1280.0
## Moment siły przy akcji obrotu.
@export var turn_torque: float = 36000.0
## Tłumienie kątowe (1/s).
@export var fighter_angular_damp: float = 6.7
## Ułamek turn_torque dla precyzyjnego obrotu (Action.TURN_*_FINE).
@export var fine_turn_factor: float = 0.25
## Impuls uniku (zmiana prędkości = impuls / masa).
@export var dash_impulse: float = 4800.0
@export var dash_cooldown: float = 1.5
## Współczynnik restytucji postaci (zderzenia z innymi ciałami).
@export var fighter_restitution: float = 0.2
@export var max_hp: float = 100.0
@export var max_ammo: int = 10
@export var start_ammo: int = 5

@export_group("Weapon")
@export var projectile_radius: float = 4.0
## Masa pocisku: od niej zależy odrzut strzelca (pęd m*v) i pchnięcie trafionego.
@export var projectile_mass: float = 0.8
## Prędkość wylotowa pocisku.
@export var projectile_speed: float = 500.0
## Tłumienie liniowe pocisku (1/s): pocisk zwalnia z odległością, więc traci energię i obrażenia.
@export var projectile_linear_damp: float = 0.15
## Współczynnik restytucji pocisku (rykoszet: prędkość po odbiciu = restytucja * prędkość przed).
@export var projectile_restitution: float = 0.8
## Obrażenia przy prędkości wylotowej; ogólnie obrażenia = damage_at_muzzle_speed * (v / v0)^2 (energia kinetyczna).
@export var damage_at_muzzle_speed: float = 35.0
## Pocisk wolniejszy niż ta prędkość znika (jego energia jest pomijalna).
@export var min_projectile_speed: float = 120.0
@export var shot_cooldown: float = 0.4
## Liczba odbić, po której pocisk znika (0 = znika na pierwszej ścianie).
@export var max_bounces: int = 2
@export var projectile_lifetime: float = 3.0

@export_group("Crates")
@export var crate_size: float = 44.0
@export var crate_mass: float = 15.0
## Tłumienie skrzyni (tarcie o podłoże): ciężka skrzynia rusza i zatrzymuje się szybko.
@export var crate_linear_damp: float = 5.0
@export var crate_angular_damp: float = 6.0
@export var crate_restitution: float = 0.1

@export_group("Pickups")
@export var pickup_radius: float = 14.0
@export var pickup_ammo: int = 3
@export var pickup_respawn_seconds: float = 8.0
@export var medkit_heal: float = 25.0
@export var medkit_respawn_seconds: float = 20.0

@export_group("Perception")
@export var nearest_projectiles_k: int = 3
@export var nearest_crates_k: int = 2
@export var vision_range: float = 900.0
## Liczba raycastów do ścian (równomiernie co 360/n stopni, zgodnie z kierunkami ruchu).
@export var vision_rays: int = 8
@export var ray_length: float = 600.0
## Odległość, przez którą dzielimy pozycje w Observation (normalizacja do ok. -1..1).
@export var observation_distance_scale: float = 1200.0
## Odstęp punktu osłony od krawędzi przeszkody (px, ponad promień postaci).
@export var cover_margin: float = 12.0


## Prędkość graniczna postaci: siła napędu równoważy tłumienie (F = m * c * v).
func max_speed() -> float:
	return move_force / (fighter_mass * fighter_linear_damp)


## Graniczna prędkość kątowa (rad/s): moment siły równoważy tłumienie kątowe.
func max_angular_speed() -> float:
	return turn_torque / (fighter_inertia * fighter_angular_damp)


## Obrażenia pocisku o danej prędkości: proporcjonalne do energii kinetycznej (1/2 m v^2).
func damage_for_speed(speed: float) -> float:
	return damage_at_muzzle_speed * pow(speed / projectile_speed, 2.0)


## Czas lotu pocisku na odległość `distance` przy tłumieniu c: v(t) = v0 e^(-ct), x(t) = v0/c (1 - e^(-ct)).
## INF, gdy pocisk nie doleci (zasięg graniczny v0/c).
func projectile_flight_time(distance: float) -> float:
	var c: float = projectile_linear_damp
	if c <= 0.0:
		return distance / projectile_speed
	var ratio: float = 1.0 - c * distance / projectile_speed
	return -log(ratio) / c if ratio > 0.0 else INF
