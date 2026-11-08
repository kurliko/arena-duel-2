class_name Observation
extends RefCounted
## Obserwacja budowana przez grę z perspektywy jednego bota.
## Zawiera wyłącznie to, co ten bot może wiedzieć. Wektory są względne
## i znormalizowane (ok. -1..1) przez budującą je grę.

## Pozycja względem lewego górnego rogu areny.
var self_position: Vector2 = Vector2.ZERO
## Prędkość liniowa w jednostkach prędkości granicznej (GameConfig.max_speed()).
var self_velocity: Vector2 = Vector2.ZERO
var self_aim_angle: float = 0.0
## Prędkość kątowa celowania w jednostkach granicznej prędkości kątowej (GameConfig.max_angular_speed()).
var self_angular_velocity: float = 0.0
var self_hp: float = 1.0
var self_ammo: float = 0.0
var shot_cooldown_left: float = 0.0
var dash_cooldown_left: float = 0.0
## Pozostały czas meczu jako ułamek limitu (1 = start, 0 = koniec). Zegar meczu znają oba boty.
var time_left: float = 1.0

var opponent_visible: bool = false
var opponent_relative_pos: Vector2 = Vector2.ZERO
var opponent_velocity: Vector2 = Vector2.ZERO
var opponent_hp: float = 0.0

## Każdy element: {"pos": Vector2, "vel": Vector2} względem bota, k najbliższych.
var nearest_projectiles: Array[Dictionary] = []
## Odległości raycastów do ścian, przeszkód i skrzyń (znormalizowane 0..1).
## Promień i ma kierunek ruchu Action i+1 (0 = w prawo, dalej co 45 stopni zgodnie z zegarem).
var ray_distances: PackedFloat32Array = PackedFloat32Array()
var ammo_pickup_relative_pos: Vector2 = Vector2.ZERO
var ammo_pickup_available: bool = false
var medkit_relative_pos: Vector2 = Vector2.ZERO
var medkit_available: bool = false
## Każdy element: {"pos": Vector2, "vel": Vector2} względem bota, k najbliższych skrzyń.
var nearest_crates: Array[Dictionary] = []
## Najbliższy punkt za przeszkodą, którego widoczny przeciwnik nie widzi (dostępny tylko, gdy przeciwnik jest widoczny).
var cover_relative_pos: Vector2 = Vector2.ZERO
var cover_available: bool = false
