class_name Observation
extends RefCounted
## Obserwacja budowana przez grę z perspektywy jednego bota.
## Zawiera wyłącznie to, co ten bot może wiedzieć. Wektory są względne
## i znormalizowane (ok. -1..1) przez budującą je grę.

var self_velocity: Vector2 = Vector2.ZERO
var self_aim_angle: float = 0.0
var self_hp: float = 1.0
var self_ammo: float = 0.0
var shot_cooldown_left: float = 0.0
var dash_cooldown_left: float = 0.0

var opponent_visible: bool = false
var opponent_relative_pos: Vector2 = Vector2.ZERO
var opponent_velocity: Vector2 = Vector2.ZERO
var opponent_hp: float = 0.0

## Każdy element: {"pos": Vector2, "vel": Vector2} względem bota, k najbliższych.
var nearest_projectiles: Array[Dictionary] = []
## Odległości raycastów do ścian i przeszkód (znormalizowane 0..1).
var ray_distances: PackedFloat32Array = PackedFloat32Array()
var ammo_pickup_relative_pos: Vector2 = Vector2.ZERO
var ammo_pickup_available: bool = false
