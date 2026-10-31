@tool
class_name Arena
extends Node2D
## Arena: ściany i przeszkody jako StaticBody2D zbudowane z ArenaLayout,
## rysowanie planszy oraz zapytania o linię wzroku i odległość do ścian.
## Skrypt działa też w edytorze (@tool), żeby układ był widoczny bez uruchamiania gry.

const FLOOR_COLOR: Color = Color(0.16, 0.17, 0.2)
const WALL_COLOR: Color = Color(0.45, 0.47, 0.52)
const OBSTACLE_COLOR: Color = Color(0.36, 0.38, 0.44)
const MARKER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)
const EDITOR_MARKER_RADIUS: float = 10.0

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
	draw_rect(Rect2(Vector2.ZERO, layout.size), FLOOR_COLOR)
	for rect: Rect2 in _wall_rects():
		draw_rect(rect, WALL_COLOR)
	for rect: Rect2 in layout.obstacles:
		draw_rect(rect, OBSTACLE_COLOR)
	if Engine.is_editor_hint():
		for point: Vector2 in layout.spawn_points + layout.pickup_points:
			draw_circle(point, EDITOR_MARKER_RADIUS, MARKER_COLOR)


func center() -> Vector2:
	return layout.size / 2.0


## Czy między punktami nie ma ściany ani przeszkody.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WALLS)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Odległość do najbliższej ściany lub przeszkody w danym kierunku (maksymalnie max_length).
func ray_distance(from: Vector2, direction: Vector2, max_length: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * max_length, PhysicsLayers.WALLS)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_length
	return from.distance_to(hit["position"])
