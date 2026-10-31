class_name PhysicsLayers
## Bity warstw kolizji 2D (nazwy warstw ustawione w project.godot).

const WALLS: int = 1
const FIGHTERS: int = 2
const PROJECTILES: int = 4
const PICKUPS: int = 8
const CRATES: int = 16
## Wszystko, co zasłania widok i zatrzymuje raycasty: stałe przeszkody i skrzynie.
const SIGHT_BLOCKERS: int = WALLS | CRATES
