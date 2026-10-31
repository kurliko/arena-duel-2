class_name FuzzyRule
extends RefCounted
## Reguła w postaci tekstowej, np.:
##   IF hp IS low AND distance IS near THEN cover IS high
##   IF threat IS high OR hp IS NOT high THEN dodge IS medium
## W jednej regule spójniki muszą być jednakowe (same AND albo same OR). AND = min, OR = max, NOT = 1 - x.

const OP_AND: String = "and"
const OP_OR: String = "or"

var text: String
var weight: float = 1.0
## Każdy warunek: {"variable": String, "set": String, "negate": bool}.
var conditions: Array[Dictionary] = []
var operator: String = OP_AND
var output_variable: String
var output_set: String


## Zwraca regułę albo null (z komunikatem błędu), jeśli tekst jest niepoprawny.
static func parse(rule_text: String, rule_weight: float = 1.0) -> FuzzyRule:
	var rule := FuzzyRule.new()
	rule.text = rule_text
	rule.weight = rule_weight
	var tokens: PackedStringArray = rule_text.strip_edges().to_lower().split(" ", false)
	var then_index: int = tokens.find("then")
	if tokens.is_empty() or tokens[0] != "if" or then_index < 0:
		return _fail(rule_text, "oczekiwano: IF ... THEN ...")
	var consequent: PackedStringArray = tokens.slice(then_index + 1)
	if consequent.size() != 3 or consequent[1] != "is":
		return _fail(rule_text, "następnik musi mieć postać: zmienna IS zbiór")
	rule.output_variable = consequent[0]
	rule.output_set = consequent[2]

	var antecedent: PackedStringArray = tokens.slice(1, then_index)
	var i: int = 0
	var connective: String = ""
	while i < antecedent.size():
		if i + 2 >= antecedent.size():
			return _fail(rule_text, "niepełny warunek")
		if antecedent[i + 1] != "is":
			return _fail(rule_text, "warunek musi mieć postać: zmienna IS [NOT] zbiór")
		var negate: bool = antecedent[i + 2] == "not"
		var set_index: int = i + 3 if negate else i + 2
		if set_index >= antecedent.size():
			return _fail(rule_text, "brak nazwy zbioru")
		rule.conditions.append({"variable": antecedent[i], "set": antecedent[set_index], "negate": negate})
		i = set_index + 1
		if i < antecedent.size():
			var word: String = antecedent[i]
			if word != OP_AND and word != OP_OR:
				return _fail(rule_text, "oczekiwano AND albo OR, jest: %s" % word)
			if not connective.is_empty() and connective != word:
				return _fail(rule_text, "nie mieszaj AND i OR w jednej regule")
			connective = word
			i += 1
	rule.operator = connective if not connective.is_empty() else OP_AND
	if rule.conditions.is_empty():
		return _fail(rule_text, "brak warunków")
	return rule


static func _fail(rule_text: String, reason: String) -> FuzzyRule:
	push_error("Błędna reguła rozmyta \"%s\": %s" % [rule_text, reason])
	return null


## Siła odpalenia reguły dla wejść po fuzzyfikacji ({zmienna: {zbiór: stopień}}).
func strength(fuzzified: Dictionary) -> float:
	var result: float = 1.0 if operator == OP_AND else 0.0
	for condition: Dictionary in conditions:
		var degree: float = fuzzified[condition["variable"]][condition["set"]]
		if condition["negate"]:
			degree = 1.0 - degree
		result = minf(result, degree) if operator == OP_AND else maxf(result, degree)
	return result * weight
