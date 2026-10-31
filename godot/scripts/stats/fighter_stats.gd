class_name FighterStats
extends RefCounted
## Statystyki jednego bota w jednym meczu (trafiają do CSV).

var shots: int = 0
var hits: int = 0
var ricochet_hits: int = 0
var self_hits: int = 0
var damage_taken: float = 0.0
var dashes: int = 0
var pickups: int = 0


func accuracy() -> float:
	return float(hits) / shots if shots > 0 else 0.0
