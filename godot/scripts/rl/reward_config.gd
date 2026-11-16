class_name RewardConfig
extends Resource

@export_group("Events")
@export var damage_dealt_per_hp: float = 0.05
@export var damage_taken_per_hp: float = -0.05
@export var self_hit: float = -0.5
@export var shot: float = -0.03
@export var blind_shot: float = -0.15
@export var aimed_shot: float = 0.1
@export var aimed_shot_tolerance_deg: float = 8.0
@export var pickup_when_low: float = 1.0
@export var pickup: float = 0.1
@export var ammo_low_fraction: float = 0.2
@export var medkit_when_low: float = 0.5
@export var medkit: float = 0.0
@export var hp_low_fraction: float = 0.5
@export var dash: float = -0.02
@export var unnecessary_dash: float = -0.1
@export var dash_threat_threshold: float = 0.15

@export_group("Shaping")
@export var time_step: float = -0.002
@export var aim_on_target: float = 0.01
@export var aim_tolerance_deg: float = 10.0
@export var aim_improvement_per_rad: float = 0.5
@export var ammo_approach_per_px: float = 0.001

@export_group("Episode end")
@export var win: float = 5.0
@export var loss: float = -5.0
@export var draw: float = -1.0
