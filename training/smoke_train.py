"""Smoke test Godot RL Agents: krótki trening PPO i eksport polityki do ONNX.

Skrypt otwiera serwer na porcie 11008 i czeka, aż połączy się z nim gra
(scena godot/smoke_test/smoke_test.tscn uruchomiona w edytorze lub z konsoli).
"""

import argparse
import os
import sys
from pathlib import Path

import onnx
from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.vec_env import VecMonitor

REPO_ROOT = Path(__file__).resolve().parent.parent


def export_single_file_onnx(model: PPO, onnx_path: Path) -> None:
    """Eksport do ONNX jako jeden plik.

    Nowy eksporter PyTorcha zapisuje wagi osobno (.onnx.data), a plugin w Godocie
    wczytuje model z bufora bajtów, więc wagi muszą być wewnątrz pliku .onnx.
    """
    export_model_as_onnx(model, str(onnx_path))
    merged = onnx.load(str(onnx_path))  # dociąga wagi z .onnx.data
    onnx.save(merged, str(onnx_path), save_as_external_data=False)
    data_file = onnx_path.with_name(onnx_path.name + ".data")
    if data_file.exists():
        os.remove(data_file)


def main() -> None:
    # Eksporter PyTorcha wypisuje emoji, których konsola Windows (cp1250) nie obsługuje.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--timesteps", type=int, default=20_000)
    parser.add_argument("--onnx", type=Path, default=REPO_ROOT / "godot" / "models" / "smoke_test.onnx")
    args = parser.parse_args()

    # VecMonitor dodaje do logów średnią nagrodę i długość epizodu (ep_rew_mean, ep_len_mean).
    env = VecMonitor(StableBaselinesGodotEnv(env_path=None, port=11008))
    model = PPO("MultiInputPolicy", env, n_steps=256, verbose=1)
    model.learn(total_timesteps=args.timesteps)

    args.onnx.parent.mkdir(parents=True, exist_ok=True)
    model.save(args.onnx.with_suffix(".zip"))
    export_single_file_onnx(model, args.onnx)
    print(f"ONNX zapisany: {args.onnx}")
    env.close()


if __name__ == "__main__":
    main()
