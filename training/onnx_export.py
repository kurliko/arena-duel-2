import os
from pathlib import Path

import onnx
from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
from stable_baselines3 import PPO


def export_single_file_onnx(model: PPO, onnx_path: Path) -> None:
    # plugin w godocie nie widzi wag w osobnym .onnx.data, wiec sklejamy wszystko w jeden plik
    onnx_path.parent.mkdir(parents=True, exist_ok=True)
    export_model_as_onnx(model, str(onnx_path))
    merged = onnx.load(str(onnx_path))
    onnx.save(merged, str(onnx_path), save_as_external_data=False)
    data_file = onnx_path.with_name(onnx_path.name + ".data")
    if data_file.exists():
        os.remove(data_file)
