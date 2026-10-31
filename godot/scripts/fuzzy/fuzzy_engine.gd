class_name FuzzyEngine
extends RefCounted
## Własny silnik wnioskowania rozmytego typu Mamdaniego:
## fuzzyfikacja -> siła reguł (AND = min, OR = max) -> implikacja min (obcięcie zbioru wyjściowego)
## -> agregacja max -> defuzzyfikacja metodą środka ciężkości (próbkowanie zakresu wyjścia).
## Zmienne, zbiory i reguły są wczytywane z pliku JSON (data/fuzzy_rules.json).

## Liczba próbek zakresu zmiennej wyjściowej przy liczeniu środka ciężkości.
const CENTROID_SAMPLES: int = 101

var inputs: Dictionary = {}   # nazwa -> FuzzyVariable
var outputs: Dictionary = {}  # nazwa -> FuzzyVariable
var rules: Array[FuzzyRule] = []

## Stan ostatniego wnioskowania (do wizualizacji „myślenia” bota).
var last_fuzzified: Dictionary = {}
var last_rule_strengths: PackedFloat32Array = PackedFloat32Array()
var last_outputs: Dictionary = {}


static func load_from_file(path: String) -> FuzzyEngine:
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Nie można wczytać reguł rozmytych z %s" % path)
		return null
	return from_dictionary(data)


static func from_dictionary(data: Dictionary) -> FuzzyEngine:
	var engine := FuzzyEngine.new()
	for var_name: String in data["inputs"]:
		var spec: Dictionary = data["inputs"][var_name]
		engine.inputs[var_name] = FuzzyVariable.new(var_name, spec["range"], spec["sets"])
	for var_name: String in data["outputs"]:
		var spec: Dictionary = data["outputs"][var_name]
		engine.outputs[var_name] = FuzzyVariable.new(var_name, spec["range"], spec["sets"])
	for entry: Variant in data["rules"]:
		var rule: FuzzyRule
		if entry is Dictionary:
			rule = FuzzyRule.parse(entry["rule"], entry.get("weight", 1.0))
		else:
			rule = FuzzyRule.parse(entry)
		if rule != null and engine._validate(rule):
			engine.rules.append(rule)
	return engine


func _validate(rule: FuzzyRule) -> bool:
	for condition: Dictionary in rule.conditions:
		var variable: FuzzyVariable = inputs.get(condition["variable"])
		if variable == null or not variable.has_set(condition["set"]):
			push_error("Reguła \"%s\": nieznane wejście %s IS %s" % [rule.text, condition["variable"], condition["set"]])
			return false
	var output: FuzzyVariable = outputs.get(rule.output_variable)
	if output == null or not output.has_set(rule.output_set):
		push_error("Reguła \"%s\": nieznane wyjście %s IS %s" % [rule.text, rule.output_variable, rule.output_set])
		return false
	return true


## Wnioskowanie: wartości wejść (nazwa -> liczba) -> wartości wyjść (nazwa -> liczba ostra).
func infer(crisp_inputs: Dictionary) -> Dictionary:
	last_fuzzified = {}
	for var_name: String in inputs:
		last_fuzzified[var_name] = (inputs[var_name] as FuzzyVariable).fuzzify(crisp_inputs[var_name])

	# Aktywacja każdego zbioru wyjściowego = maksimum sił reguł, które do niego prowadzą.
	var activations: Dictionary = {}
	for var_name: String in outputs:
		activations[var_name] = {}
	last_rule_strengths.resize(rules.size())
	for i: int in rules.size():
		var rule: FuzzyRule = rules[i]
		var s: float = rule.strength(last_fuzzified)
		last_rule_strengths[i] = s
		var current: float = activations[rule.output_variable].get(rule.output_set, 0.0)
		activations[rule.output_variable][rule.output_set] = maxf(current, s)

	last_outputs = {}
	for var_name: String in outputs:
		last_outputs[var_name] = _centroid(outputs[var_name], activations[var_name])
	return last_outputs


## Środek ciężkości agregatu obciętych zbiorów; 0 (minimum zakresu), gdy żadna reguła nie odpaliła.
func _centroid(variable: FuzzyVariable, activations: Dictionary) -> float:
	var weighted_sum: float = 0.0
	var mass: float = 0.0
	for i: int in CENTROID_SAMPLES:
		var x: float = lerpf(variable.min_value, variable.max_value, float(i) / (CENTROID_SAMPLES - 1))
		var mu: float = 0.0
		for fuzzy_set: FuzzySet in variable.sets:
			var activation: float = activations.get(fuzzy_set.name, 0.0)
			if activation > 0.0:
				mu = maxf(mu, minf(activation, fuzzy_set.membership(x)))
		weighted_sum += x * mu
		mass += mu
	return weighted_sum / mass if mass > 0.0 else variable.min_value
