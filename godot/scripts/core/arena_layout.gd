class_name ArenaLayout
extends Resource
## Układ areny: rozmiar, przeszkody, punkty startowe i punkty z amunicją.
## Współrzędne liczone od lewego górnego rogu wnętrza areny.

@export var size: Vector2 = Vector2(1200.0, 720.0)
@export var wall_thickness: float = 40.0
@export var obstacles: Array[Rect2] = []
## Dwa punkty startowe: [strona A, strona B].
@export var spawn_points: Array[Vector2] = []
@export var pickup_points: Array[Vector2] = []
