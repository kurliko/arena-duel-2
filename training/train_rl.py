"""Trening bota RL (PPO, Stable-Baselines3) na arenie z Godota, z curriculum przeciwników.

Każdy etap curriculum uruchamia grę (scena training.tscn, tryb --headless) z innym przeciwnikiem
i kontynuuje trening tego samego modelu. Po każdym etapie zapisywany jest model (.zip) i eksport ONNX.

Przykład (PowerShell, katalog repozytorium):
    .\\venv\\Scripts\\python training\\train_rl.py --curriculum random:300000,scripted:500000,fuzzy:500000
Podgląd przebiegu: .\\venv\\Scripts\\tensorboard --logdir training\\runs
"""

import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.utils import set_random_seed
from stable_baselines3.common.vec_env import VecMonitor

from onnx_export import export_single_file_onnx

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_GODOT = (
    r"C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64"
    r"\Godot_v4.7.2-stable_mono_win64_console.exe"
)
# Godot czeka ok. 1 s po starcie na serwer Pythona; ten odstęp daje Pythonowi czas na otwarcie portu.
GODOT_START_DELAY_S = 2.0


def parse_curriculum(text: str) -> list[tuple[str, int]]:
    stages = []
    for item in text.split(","):
        opponent, steps = item.split(":")
        stages.append((opponent.strip(), int(steps)))
    return stages


def launch_godot(args: argparse.Namespace, opponent: str, stage_index: int, log_dir: Path) -> subprocess.Popen:
    godot = os.environ.get("GODOT_BIN", DEFAULT_GODOT)
    command = [
        godot, "--headless", "--path", str(REPO_ROOT / "godot"), "res://scenes/training.tscn",
        f"--speedup={args.speedup}", f"--port={args.port}",
        "--", f"--arenas={args.arenas}", f"--opponent={opponent}", f"--seed={args.seed + stage_index * 1000}",
    ]
    log_file = open(log_dir / f"godot_stage{stage_index}_{opponent}.log", "w", encoding="utf-8")
    print("uruchamiam Godota:", " ".join(command))
    return subprocess.Popen(command, stdout=log_file, stderr=subprocess.STDOUT)


def main() -> None:
    # Eksporter PyTorcha wypisuje emoji, których konsola Windows (cp1250) nie obsługuje.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser()
    parser.add_argument("--curriculum", default="random:300000,scripted:500000,fuzzy:500000",
                        help="etapy przeciwnik:kroki oddzielone przecinkami; kilku przeciwników naraz: scripted+fuzzy:kroki")
    parser.add_argument("--run", default=time.strftime("run_%Y%m%d_%H%M"), help="nazwa przebiegu (katalog w training/runs)")
    parser.add_argument("--resume", type=Path, help="model .zip, od którego kontynuować")
    parser.add_argument("--arenas", type=int, default=8)
    parser.add_argument("--speedup", type=int, default=8)
    parser.add_argument("--port", type=int, default=11008)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--ent-coef", type=float, default=0.005, help="współczynnik entropii PPO (losowość eksploracji)")
    parser.add_argument("--onnx", type=Path, default=REPO_ROOT / "godot" / "models" / "rl_brain.onnx")
    args = parser.parse_args()

    run_dir = REPO_ROOT / "training" / "runs" / args.run
    run_dir.mkdir(parents=True, exist_ok=True)
    # Ziarno PyTorcha i NumPy ustawiamy wprost: wrapper środowiska Godota nie obsługuje env.seed(),
    # a gra ma własne ziarna aren (--seed).
    set_random_seed(args.seed)
    model: PPO | None = PPO.load(args.resume) if args.resume else None

    for stage_index, (opponent, steps) in enumerate(parse_curriculum(args.curriculum)):
        print(f"=== etap {stage_index}: przeciwnik {opponent}, {steps} kroków ===")
        godot_holder: dict = {}
        timer = threading.Timer(
            GODOT_START_DELAY_S,
            lambda o=opponent, i=stage_index: godot_holder.setdefault("p", launch_godot(args, o, i, run_dir)),
        )
        timer.start()
        env = VecMonitor(StableBaselinesGodotEnv(env_path=None, port=args.port))

        if model is None:
            model = PPO(
                "MultiInputPolicy", env,
                n_steps=512, batch_size=512, n_epochs=10, learning_rate=3e-4,
                gamma=0.99, gae_lambda=0.95, ent_coef=args.ent_coef, clip_range=0.2,
                policy_kwargs={"net_arch": [128, 128]},
                tensorboard_log=str(run_dir / "tb"), verbose=1,
            )
        else:
            model.set_env(env)
            model.tensorboard_log = str(run_dir / "tb")

        checkpoint = CheckpointCallback(
            save_freq=max(100_000 // env.num_envs, 1), save_path=str(run_dir / "checkpoints"),
            name_prefix=f"stage{stage_index}_{opponent}",
        )
        try:
            model.learn(total_timesteps=steps, reset_num_timesteps=False, tb_log_name="ppo", callback=checkpoint)
        finally:
            stage_model = run_dir / f"stage{stage_index}_{opponent}.zip"
            model.save(stage_model)
            print(f"model zapisany: {stage_model}")
            env.close()
            if "p" in godot_holder:
                godot_holder["p"].wait(timeout=30)

        export_single_file_onnx(model, run_dir / f"stage{stage_index}_{opponent}.onnx")

    export_single_file_onnx(model, args.onnx)
    print(f"ONNX zapisany: {args.onnx}")


if __name__ == "__main__":
    main()
