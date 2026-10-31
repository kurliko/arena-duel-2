class_name FuzzyVariable
extends RefCounted
## Zmienna lingwistyczna: zakres wartości i nazwane zbiory rozmyte.

var name: String
var min_value: float
var max_value: float
var sets: Array[FuzzySet] = []


func _init(variable_name: String, value_range: Array, set_points: Dictionary) -> void:
	name = variable_name
	min_value = value_range[0]
	max_value = value_range[1]
	for set_name: String in set_points:
		sets.append(FuzzySet.new(set_name, set_points[set_name]))


func has_set(set_name: String) -> bool:
	return get_set(set_name) != null


func get_set(set_name: String) -> FuzzySet:
	for fuzzy_set: FuzzySet in sets:
		if fuzzy_set.name == set_name:
			return fuzzy_set
	return null


## Fuzzyfikacja: stopień przynależności wartości (obciętej do zakresu) do każdego zbioru.
func fuzzify(value: float) -> Dictionary:
	var x: float = clampf(value, min_value, max_value)
	var degrees: Dictionary = {}
	for fuzzy_set: FuzzySet in sets:
		degrees[fuzzy_set.name] = fuzzy_set.membership(x)
	return degrees
