class_name GameConfig
extends Resource
## Wszystkie parametry gry i fizyki w jednym miejscu (bez magicznych liczb w kodzie).
## Zestawy parametrów zapisujemy jako pliki .tres w data/configs/.

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
@export var max_hp: float = 100.0
@export var max_ammo: int = 10
@export var start_ammo: int = 5
@export var max_speed: float = 220.0
@export var acceleration: float = 900.0
@export var friction: float = 600.0
@export var turn_rate_deg: float = 240.0
## Ułamek turn_rate_deg dla precyzyjnego obrotu (Action.TURN_*_FINE).
@export var fine_turn_factor: float = 0.25
@export var dash_speed: float = 480.0
@export var dash_cooldown: float = 1.5

@export_group("Weapon")
@export var projectile_radius: float = 4.0
@export var projectile_speed: float = 500.0
@export var projectile_damage: float = 20.0
@export var shot_cooldown: float = 0.4
## Liczba odbić, po której pocisk znika (0 = znika na pierwszej ścianie).
@export var max_bounces: int = 2
## Mnożnik prędkości przy każdym odbiciu.
@export var bounce_speed_loss: float = 0.8
@export var projectile_lifetime: float = 3.0

@export_group("Ammo pickups")
@export var pickup_radius: float = 14.0
@export var pickup_ammo: int = 3
@export var pickup_respawn_seconds: float = 8.0

@export_group("Perception")
@export var nearest_projectiles_k: int = 3
@export var vision_range: float = 900.0
## Liczba raycastów do ścian (równomiernie co 360/n stopni, zgodnie z kierunkami ruchu).
@export var vision_rays: int = 8
@export var ray_length: float = 600.0
## Odległość, przez którą dzielimy pozycje w Observation (normalizacja do ok. -1..1).
@export var observation_distance_scale: float = 1200.0
