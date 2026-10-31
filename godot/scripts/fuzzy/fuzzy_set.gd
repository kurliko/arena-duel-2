class_name FuzzySet
extends RefCounted
## Zbiór rozmyty z trapezową funkcją przynależności (a, b, c, d).
## Trójkąt to trapez z b == c. Ramię lewe: a == b, ramię prawe: c == d.

var name: String
var a: float
var b: float
var c: float
var d: float


func _init(set_name: String, points: Array) -> void:
	name = set_name
	assert(points.size() == 3 or points.size() == 4, "Zbiór %s: potrzebne 3 (trójkąt) lub 4 (trapez) punkty" % set_name)
	a = points[0]
	b = points[1]
	c = points[2] if points.size() == 4 else points[1]
	d = points[3] if points.size() == 4 else points[2]
	assert(a <= b and b <= c and c <= d, "Zbiór %s: punkty muszą być niemalejące" % set_name)


func membership(x: float) -> float:
	if x < a or x > d:
		return 0.0
	if x < b:
		return (x - a) / (b - a)
	if x <= c:
		return 1.0
	return (d - x) / (d - c)
