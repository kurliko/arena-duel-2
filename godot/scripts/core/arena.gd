@tool
class_name Arena
extends Node2D
## Arena: ściany i przeszkody jako StaticBody2D zbudowane z ArenaLayout,
## rysowanie planszy oraz zapytania o linię wzroku i odległość do przeszkód (stałych i skrzyń).
## Skrypt działa też w edytorze (@tool), żeby układ był widoczny bez uruchamiania gry.

const FLOOR_COLOR: Color = Color(0.15, 0.16, 0.19)
const FLOOR_TILE_COLOR: Color = Color(0.17, 0.18, 0.215)
const FLOOR_TILE: float = 60.0
const WALL_COLOR: Color = Color(0.38, 0.4, 0.46)
const WALL_EDGE: Color = Color(0.52, 0.55, 0.62)
const OBSTACLE_COLOR: Color = Color(0.32, 0.34, 0.4)
const OBSTACLE_TOP: Color = Color(0.44, 0.47, 0.54)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const SHADOW_OFFSET: Vector2 = Vector2(5.0, 6.0)
const BEVEL: float = 4.0
const SPAWN_MARK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const SPAWN_MARK_RADIUS: float = 26.0
const EDITOR_MARKER_RADIUS: float = 10.0
const EDITOR_COLORS: Dictionary = {
	"spawn": Color(0.3, 0.6, 1.0, 0.6), "ammo": Color(1.0, 0.8, 0.25, 0.6),
	"medkit": Color(0.9, 0.2, 0.2, 0.6), "crate": Color(0.6, 0.4, 0.2, 0.6),
}

@export var layout: ArenaLayout:
	set(value):
		layout = value
		queue_redraw()

var _body: StaticBody2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_bodies()


func _build_bodies() -> void:
	_body = StaticBody2D.new()
	_body.name = "Walls"
	_body.collision_layer = PhysicsLayers.WALLS
	_body.collision_mask = 0
	# Restytucja ścian 0: odbicie pocisku zależy od materiału pocisku (projectile_restitution).
	var material := PhysicsMaterial.new()
	material.friction = 0.0
	material.bounce = 0.0
	_body.physics_material_override = material
	add_child(_body)
	for rect: Rect2 in _wall_rects() + layout.obstacles:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		_body.add_child(collision)


func _wall_rects() -> Array[Rect2]:
	var t: float = layout.wall_thickness
	var s: Vector2 = layout.size
	return [
		Rect2(-t, -t, s.x + 2.0 * t, t),
		Rect2(-t, s.y, s.x + 2.0 * t, t),
		Rect2(-t, 0.0, t, s.y),
		Rect2(s.x, 0.0, t, s.y),
	]


func _draw() -> void:
	if layout == null:
		return
	_draw_floor()
	for point: Vector2 in layout.spawn_points:
		draw_circle(point, SPAWN_MARK_RADIUS, SPAWN_MARK_COLOR)
	for rect: Rect2 in layout.obstacles:
		draw_rect(Rect2(rect.position + SHADOW_OFFSET, rect.size), SHADOW_COLOR)
	for rect: Rect2 in _wall_rects():
		draw_rect(rect, WALL_COLOR)
	draw_rect(Rect2(Vector2.ZERO, layout.size), WALL_EDGE, false, 2.0)
	for rect: Rect2 in layout.obstacles:
		draw_rect(rect, OBSTACLE_COLOR)
		draw_rect(rect.grow(-BEVEL), OBSTACLE_TOP)
	if Engine.is_editor_hint():
		_draw_editor_markers()


## Podłoga w szachownicę dużych płytek (ułatwia ocenę prędkości i odległości na nagraniach).
func _draw_floor() -> void:
	draw_rect(Rect2(Vector2.ZERO, layout.size), FLOOR_COLOR)
	var columns: int = ceili(layout.size.x / FLOOR_TILE)
	var rows: int = ceili(layout.size.y / FLOOR_TILE)
	for x: int in columns:
		for y: int in rows:
			if (x + y) % 2 == 0:
				var tile := Rect2(Vector2(x, y) * FLOOR_TILE, Vector2.ONE * FLOOR_TILE)
				draw_rect(tile.intersection(Rect2(Vector2.ZERO, layout.size)), FLOOR_TILE_COLOR)


## W edytorze: punkty startowe, pakiety, apteczki i skrzynie jako kolorowe znaczniki.
func _draw_editor_markers() -> void:
	for point: Vector2 in layout.spawn_points:
		draw_circle(point, EDITOR_MARKER_RADIUS, EDITOR_COLORS["spawn"])
	for point: Vector2 in layout.pickup_points:
		draw_circle(point, EDITOR_MARKER_RADIUS, EDITOR_COLORS["ammo"])
	for point: Vector2 in layout.medkit_points:
		draw_circle(point, EDITOR_MARKER_RADIUS, EDITOR_COLORS["medkit"])
	for point: Vector2 in layout.crate_points:
		draw_rect(Rect2(point - Vector2.ONE * 22.0, Vector2.ONE * 44.0), EDITOR_COLORS["crate"])


func center() -> Vector2:
	return layout.size / 2.0


## Czy między punktami nie ma przeszkody ani skrzyni. Punkty we współrzędnych areny (lokalnych);
## raycast działa w globalnych, bo w scenie treningowej areny są przesunięte względem siebie.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(to_global(from), to_global(to), PhysicsLayers.SIGHT_BLOCKERS)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Odległość do najbliższej ściany, przeszkody lub skrzyni w danym kierunku (maksymalnie max_length).
func ray_distance(from: Vector2, direction: Vector2, max_length: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(
			to_global(from), to_global(from + direction * max_length), PhysicsLayers.SIGHT_BLOCKERS)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_length
	return from.distance_to(to_local(hit["position"]))
