class_name BrainFactory

const RANDOM: String = "random"
const SCRIPTED: String = "scripted"
const FUZZY: String = "fuzzy"
const RL: String = "rl"


static func create(brain_name: String, config: GameConfig) -> Brain:
	match brain_name:
		RANDOM:
			return RandomBrain.new()
		SCRIPTED:
			return ScriptedBrain.new(config)
		FUZZY:
			return FuzzyBrain.new(config)
	push_error("Nieznany mózg: %s, używam %s" % [brain_name, RANDOM])
	return RandomBrain.new()
