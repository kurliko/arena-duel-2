class_name Observation
extends RefCounted

var self_position: Vector2 = Vector2.ZERO
var self_velocity: Vector2 = Vector2.ZERO
var self_aim_angle: float = 0.0
var self_angular_velocity: float = 0.0
var self_hp: float = 1.0
var self_ammo: float = 0.0
var shot_cooldown_left: float = 0.0
var dash_cooldown_left: float = 0.0
var time_left: float = 1.0

var opponent_visible: bool = false
var opponent_relative_pos: Vector2 = Vector2.ZERO
var opponent_velocity: Vector2 = Vector2.ZERO
var opponent_hp: float = 0.0

var nearest_projectiles: Array[Dictionary] = []
var ray_distances: PackedFloat32Array = PackedFloat32Array()
var ammo_pickup_relative_pos: Vector2 = Vector2.ZERO
var ammo_pickup_available: bool = false
var medkit_relative_pos: Vector2 = Vector2.ZERO
var medkit_available: bool = false
var nearest_crates: Array[Dictionary] = []
var cover_relative_pos: Vector2 = Vector2.ZERO
var cover_available: bool = false
