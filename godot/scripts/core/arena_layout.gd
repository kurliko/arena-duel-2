class_name ArenaLayout
extends Resource
## Układ areny: rozmiar, przeszkody, punkty startowe, pakiety amunicji, apteczki i skrzynie.
## Współrzędne liczone od lewego górnego rogu wnętrza areny.

@export var size: Vector2 = Vector2(1200.0, 720.0)
@export var wall_thickness: float = 40.0
## Stałe przeszkody (StaticBody2D).
@export var obstacles: Array[Rect2] = []
## Dwa punkty startowe: [strona A, strona B].
@export var spawn_points: Array[Vector2] = []
@export var pickup_points: Array[Vector2] = []
@export var medkit_points: Array[Vector2] = []
## Środki przesuwanych skrzyń (RigidBody2D), ustawiane na start każdego meczu.
@export var crate_points: Array[Vector2] = []
