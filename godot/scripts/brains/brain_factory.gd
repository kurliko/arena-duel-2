class_name BrainFactory
## Tworzenie mózgów po nazwie (z linii poleceń, menu, turnieju).

const RANDOM: String = "random"
const SCRIPTED: String = "scripted"


static func create(brain_name: String, config: GameConfig) -> Brain:
	match brain_name:
		RANDOM:
			return RandomBrain.new()
		SCRIPTED:
			return ScriptedBrain.new(config)
	push_error("Nieznany mózg: %s, używam %s" % [brain_name, RANDOM])
	return RandomBrain.new()
