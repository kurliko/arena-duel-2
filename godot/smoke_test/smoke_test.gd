extends Node2D
## Scena smoke testu Godot RL Agents: sprawdza most Godot <-> Python, trening PPO
## i inferencję ONNX w grze. Nie jest częścią właściwej gry.
##
## Tryb inferencji: uruchom z argumentem użytkownika `-- --onnx=res://models/smoke_test.onnx`.

@onready var _sync: Node = $Sync


func _ready() -> void:
	# Sync czeka na ready rodzica, więc tryb można tu jeszcze przestawić.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--onnx="):
			_sync.control_mode = 2  # Sync.ControlModes.ONNX_INFERENCE
			_sync.onnx_model_path = arg.trim_prefix("--onnx=")
			# Krótko trenowana polityka w trybie deterministycznym potrafi drżeć tuż obok celu.
			_sync.deterministic_inference = false
			print("smoke_test: inferencja ONNX z ", _sync.onnx_model_path)
