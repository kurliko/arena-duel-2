"""Eksport polityki PPO (Stable-Baselines3) do ONNX w formacie czytelnym dla pluginu Godot RL Agents."""

import os
from pathlib import Path

import onnx
from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
from stable_baselines3 import PPO


def export_single_file_onnx(model: PPO, onnx_path: Path) -> None:
    """Eksport do ONNX jako jeden plik.

    Nowy eksporter PyTorcha zapisuje wagi osobno (.onnx.data), a plugin w Godocie
    wczytuje model z bufora bajtów, więc wagi muszą być wewnątrz pliku .onnx.
    """
    onnx_path.parent.mkdir(parents=True, exist_ok=True)
    export_model_as_onnx(model, str(onnx_path))
    merged = onnx.load(str(onnx_path))  # dociąga wagi z .onnx.data
    onnx.save(merged, str(onnx_path), save_as_external_data=False)
    data_file = onnx_path.with_name(onnx_path.name + ".data")
    if data_file.exists():
        os.remove(data_file)
