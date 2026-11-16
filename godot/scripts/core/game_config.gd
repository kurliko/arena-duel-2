class_name GameConfig
extends Resource

@export_group("Match")
@export var rng_seed: int = 0
@export var max_match_seconds: float = 60.0
@export var decision_interval_ticks: int = 4
@export var time_limit_winner_by_hp: bool = true
@export var between_matches_delay: float = 1.5

@export_group("Fighter")
@export var fighter_radius: float = 16.0
@export var fighter_mass: float = 10.0
@export var move_force: float = 8800.0
@export var fighter_linear_damp: float = 4.0
@export var fighter_inertia: float = 1280.0
@export var turn_torque: float = 36000.0
@export var fighter_angular_damp: float = 6.7
@export var fine_turn_factor: float = 0.25
@export var dash_impulse: float = 4800.0
@export var dash_cooldown: float = 1.5
@export var fighter_restitution: float = 0.2
@export var max_hp: float = 100.0
@export var max_ammo: int = 10
@export var start_ammo: int = 5

@export_group("Weapon")
@export var projectile_radius: float = 4.0
@export var projectile_mass: float = 0.8
@export var projectile_speed: float = 500.0
@export var projectile_linear_damp: float = 0.15
@export var projectile_restitution: float = 0.8
@export var damage_at_muzzle_speed: float = 35.0
@export var min_projectile_speed: float = 120.0
@export var shot_cooldown: float = 0.4
@export var max_bounces: int = 2
@export var projectile_lifetime: float = 3.0

@export_group("Crates")
@export var crate_size: float = 44.0
@export var crate_mass: float = 15.0
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
@export var vision_rays: int = 8
@export var ray_length: float = 600.0
@export var observation_distance_scale: float = 1200.0
@export var cover_margin: float = 12.0


func max_speed() -> float:
	return move_force / (fighter_mass * fighter_linear_damp)


func max_angular_speed() -> float:
	return turn_torque / (fighter_inertia * fighter_angular_damp)


# obrazenia z energii kinetycznej: 35 * (v / v0)^2
func damage_for_speed(speed: float) -> float:
	return damage_at_muzzle_speed * pow(speed / projectile_speed, 2.0)


# czas lotu z oporem, z x(t) = v0/c * (1 - e^(-ct))
func projectile_flight_time(distance: float) -> float:
	var c: float = projectile_linear_damp
	if c <= 0.0:
		return distance / projectile_speed
	var ratio: float = 1.0 - c * distance / projectile_speed
	return -log(ratio) / c if ratio > 0.0 else INF
