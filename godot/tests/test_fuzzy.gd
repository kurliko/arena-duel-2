extends SceneTree
## Testy jednostkowe silnika rozmytego. Uruchomienie (z katalogu repozytorium):
##   Godot_..._console.exe --headless --path godot --script res://tests/test_fuzzy.gd
## Kod wyjścia 0 = wszystkie testy przeszły.

const EPS: float = 1e-3

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_test_membership()
	_test_rule_parsing()
	_test_rule_strength()
	_test_centroid()
	_test_engine_end_to_end()
	_test_rules_file()
	print("test_fuzzy: %d OK, %d BŁĘDÓW" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("  BŁĄD: ", label)


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) < EPS, "%s: oczekiwano %.4f, jest %.4f" % [label, expected, actual])


func _test_membership() -> void:
	var tri := FuzzySet.new("tri", [0.0, 5.0, 10.0])
	_near(tri.membership(0.0), 0.0, "trójkąt lewy koniec")
	_near(tri.membership(2.5), 0.5, "trójkąt zbocze")
	_near(tri.membership(5.0), 1.0, "trójkąt szczyt")
	_near(tri.membership(7.5), 0.5, "trójkąt zbocze prawe")
	_near(tri.membership(11.0), 0.0, "trójkąt poza zakresem")
	var left := FuzzySet.new("left", [0.0, 0.0, 2.0, 4.0])
	_near(left.membership(0.0), 1.0, "lewe ramię na początku")
	_near(left.membership(3.0), 0.5, "lewe ramię zbocze")
	var right := FuzzySet.new("right", [6.0, 8.0, 10.0, 10.0])
	_near(right.membership(10.0), 1.0, "prawe ramię na końcu")
	var variable := FuzzyVariable.new("v", [0.0, 10.0], {"low": [0.0, 0.0, 2.0, 4.0]})
	_near(variable.fuzzify(-5.0)["low"], 1.0, "wejście obcięte do zakresu")


func _test_rule_parsing() -> void:
	var rule := FuzzyRule.parse("IF hp IS low AND distance IS NOT far THEN cover IS high")
	_check(rule != null, "poprawna reguła się parsuje")
	if rule != null:
		_check(rule.conditions.size() == 2, "dwa warunki")
		_check(rule.conditions[1]["negate"], "NOT rozpoznane")
		_check(rule.operator == FuzzyRule.OP_AND, "spójnik AND")
		_check(rule.output_variable == "cover" and rule.output_set == "high", "następnik")
	print("  (oczekiwane komunikaty o błędnych regułach poniżej)")
	_check(FuzzyRule.parse("hp IS low THEN cover IS high") == null, "brak IF odrzucony")
	_check(FuzzyRule.parse("IF hp IS low AND ammo IS none OR x IS y THEN a IS b") == null, "mieszane AND/OR odrzucone")
	_check(FuzzyRule.parse("IF hp IS THEN a IS b") == null, "niepełny warunek odrzucony")


func _test_rule_strength() -> void:
	var fuzzified: Dictionary = {"a": {"x": 0.7}, "b": {"y": 0.4}}
	_near(FuzzyRule.parse("IF a IS x AND b IS y THEN o IS z").strength(fuzzified), 0.4, "AND = min")
	_near(FuzzyRule.parse("IF a IS x OR b IS y THEN o IS z").strength(fuzzified), 0.7, "OR = max")
	_near(FuzzyRule.parse("IF a IS NOT x THEN o IS z").strength(fuzzified), 0.3, "NOT = 1 - x")
	_near(FuzzyRule.parse("IF a IS x THEN o IS z", 0.5).strength(fuzzified), 0.35, "waga reguły")


func _test_centroid() -> void:
	var engine := FuzzyEngine.new()
	var out := FuzzyVariable.new("o", [0.0, 1.0], {"low": [0.0, 0.25, 0.5], "high": [0.5, 0.75, 1.0]})
	_near(engine._centroid(out, {"high": 1.0}), 0.75, "środek symetrycznego trójkąta")
	_near(engine._centroid(out, {"high": 0.3}), 0.75, "obcięty trójkąt symetryczny")
	_near(engine._centroid(out, {"low": 1.0, "high": 1.0}), 0.5, "dwa równe zbiory")
	_check(engine._centroid(out, {"low": 0.2, "high": 0.8}) > 0.5, "silniejszy zbiór przesuwa środek")
	_near(engine._centroid(out, {}), 0.0, "brak aktywnych reguł")


func _test_engine_end_to_end() -> void:
	var engine := FuzzyEngine.from_dictionary({
		"inputs": {"hp": {"range": [0, 1], "sets": {"low": [0, 0, 0.2, 0.5], "high": [0.5, 0.8, 1, 1]}}},
		"outputs": {"cover": {"range": [0, 1], "sets": {"low": [0, 0, 0.2, 0.4], "high": [0.6, 0.8, 1, 1]}}},
		"rules": ["IF hp IS low THEN cover IS high", "IF hp IS high THEN cover IS low"],
	})
	_check(engine.rules.size() == 2, "silnik wczytał reguły")
	var low_hp: float = engine.infer({"hp": 0.1})["cover"]
	var high_hp: float = engine.infer({"hp": 0.95})["cover"]
	_check(low_hp > 0.7, "mało HP -> osłona wysoko (%.2f)" % low_hp)
	_check(high_hp < 0.3, "dużo HP -> osłona nisko (%.2f)" % high_hp)
	_check(engine.last_rule_strengths.size() == 2, "zapamiętane siły reguł")


func _test_rules_file() -> void:
	var path: String = "res://data/fuzzy_rules.json"
	if not FileAccess.file_exists(path):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var engine := FuzzyEngine.load_from_file(path)
	_check(engine != null, "plik reguł się wczytuje")
	if engine != null:
		_check(engine.rules.size() == data["rules"].size(), "wszystkie reguły z pliku poprawne (%d/%d)" % [engine.rules.size(), data["rules"].size()])
