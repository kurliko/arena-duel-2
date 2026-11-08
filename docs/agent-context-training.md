# Agent context: running RL training on a teammate's machine

Audience: a Claude Code agent working for Zofia Jedlińska (teammate). Read this file fully before acting.
Also read `CLAUDE.md` (auto-loaded) and, if you need the full project spec, `docs/project-context.md`.
Detailed history and design rationale: `docs/dziennik-prac.md` (Polish).

## Goal of this session

Set up the project on this machine and run one long RL training (PPO, curriculum), then deliver the model.
Do NOT change game code, fuzzy rules, rewards or physics: training results must be comparable with the rest
of the project. If something looks broken, stop and report to the user instead of "fixing" game logic.

Deliverables:
1. `godot/models/rl_brain.onnx` from the finished run, committed and pushed to `main`.
2. The TensorBoard folder `training/runs/<run>/tb/` zipped and handed to the user (it is gitignored; Filip needs it
   for learning-curve plots in the report).
3. A short report to the user: steps done, final `rollout/success_rate` per curriculum stage, wall time, any errors.

## Project in one paragraph

Godot 4.7.2 (.NET build) 2D top-down arena duel. Two bots fight; each is a `Brain` that receives an `Observation`
and returns a discrete `Action`. Brains: `fuzzy` (custom Mamdani engine, rules in `godot/data/fuzzy_rules.json`),
`scripted` (FSM), `random`, `rl` (PPO policy). Physics: fighters, projectiles and crates are `RigidBody2D`
(forces, torque with moment of inertia, impulses, restitution, damage from kinetic energy). RL bridge:
Godot RL Agents plugin (`godot/addons/godot_rl_agents`) + Python `godot-rl` + Stable-Baselines3. The policy is
exported to ONNX and run inside the game via the plugin's C# OnnxRuntime code (hence the .NET build).

## Environment (Windows native, NOT WSL)

Required, exact versions:
- Godot **4.7.2 stable .NET** for Windows (zip with `mono` in the name). Unzip anywhere; the training script needs
  the `*_mono_win64_console.exe` file.
- .NET SDK **8.x** (`dotnet --list-sdks` must show 8.x).
- Python **3.12** on PATH (3.11 should also work; 3.12.10 is what the project uses).
- Git.

Shell: PowerShell. Repo must be on a normal Windows drive path.

## Setup (run from the repo root)

```powershell
git clone https://github.com/kurliko/arena-duel-2.git
cd arena-duel-2
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt   # torch is large; takes several minutes
dotnet build godot\ArenaDuel.csproj               # builds OnnxRuntime glue for the plugin; must print 0 errors
```

Point the training script at Godot (default path is Filip's: `C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`):

```powershell
$env:GODOT_BIN = "<absolute path to Godot_v4.7.2-stable_mono_win64_console.exe>"
```

`GODOT_BIN` is per-shell; set it in the same shell/command that starts training.

## Verify before the long run (all must pass)

```powershell
# 1. Godot imports the project without script errors (first run also builds the .godot cache)
& $env:GODOT_BIN --headless --path godot --import
# 2. Fuzzy engine unit tests: last line must be "test_fuzzy: 32 OK, 0 BŁĘDÓW" (3 ERROR lines above it are expected)
& $env:GODOT_BIN --headless --path godot --script res://tests/test_fuzzy.gd
# 3. Two quick matches without RL: prints "mecz 0: ..." lines and "koniec serii: ..."
& $env:GODOT_BIN --headless --fixed-fps 60 --path godot -- --matches=2 --brain-a=fuzzy --brain-b=scripted --seed=1
# 4. Short training smoke run (~1 min): must print SB3 tables with total_timesteps and finish with "ONNX zapisany"
.\venv\Scripts\python training\train_rl.py --curriculum random:8192 --arenas 8 --run smoke --onnx training\runs\smoke\final.onnx
```

For step 4 check: `ep_len_mean` around 900 (= full 60 s matches). Values far below ~600 at the start mean bodies
are being reset into the wrong arena (a fixed bug; see Pitfalls) - stop and report. Delete `training\runs\smoke` afterwards.

## The long run

```powershell
.\venv\Scripts\python training\train_rl.py --curriculum random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
```

- 9M steps. On Filip's machine 8 arenas gave ~500-870 steps/s (about 3-5 h). Run it in the background and do not poll
  aggressively; check `training\runs\rigid_v3\train.log` occasionally.
- If the machine struggles, lower load with `--arenas 4` and/or `--speedup 4` (slower but lighter). Keep the curriculum.
- The machine must not sleep during training.
- Expected signals: `rollout/success_rate` vs random roughly 0.4+ early; against scripted/fuzzy it starts near 0.05.
  The previous run's bottleneck was aiming (rotational inertia): the bot collects ammo and dodges but rarely hits.
  Any improvement in hits/success_rate vs scripted/fuzzy is the point of this run.

Outputs (all under `training\runs\rigid_v3\`, gitignored):
- `train.log`, `tb\` (TensorBoard), `checkpoints\` (every 100k steps), `stageN_<opponent>.zip/.onnx` per stage,
  `godot_stageN_<opponent>.log`.
- The final model is also written to `godot\models\rl_brain.onnx` (this one is tracked in git).

Progress view: `.\venv\Scripts\tensorboard --logdir training\runs` then http://localhost:6006.

Resume after interruption: pass the latest checkpoint and only the remaining stages, e.g.
`--resume training\runs\rigid_v3\checkpoints\stage1_scripted_1500000_steps.zip --curriculum scripted:1500000,fuzzy:3000000`.
Use a new `--run` name if you want separate logs.

## Quick evaluation after training (optional, ~10 min)

```powershell
& $env:GODOT_BIN --headless --fixed-fps 60 --path godot -- --matches=10 --brain-a=rl --brain-b=scripted --seed=41 --quiet=1 --csv=results/eval_rigid_v3.csv
```

Repeat with `--brain-b=random` and `--brain-b=fuzzy` (same CSV file appends). Report wins and mean `hits_a`.

## Delivering

```powershell
git add godot/models/rl_brain.onnx results/eval_rigid_v3.csv
git commit -m "RL model rigid_v3 (9M-step curriculum) and evaluation"
git push origin main
Compress-Archive -Path training\runs\rigid_v3\tb -DestinationPath rigid_v3_tb.zip
```

If `git push` is rejected because `main` moved, run `git pull --rebase origin main` first (the model file will not
conflict with Filip's work). Never force-push.

## Rules (from CLAUDE.md, apply to you too)

- Commit as the user's own git identity. No `Co-Authored-By` or any Claude/AI attribution in commit messages or PRs.
- Commit and PR messages in English. Docs and code comments are Polish.
- Never rewrite history (rebase of pushed commits, filter-branch, force push).
- Do not commit `training/runs/`, `venv/`, `.godot/`.
- Do not modify `godot/scenes/*.tscn`, rules, rewards or `GameConfig` defaults during or for this task.

## Pitfalls already solved (do not reintroduce, useful for diagnosing)

- **Action order**: godot-rl sorts the action space alphabetically on the Python side; `RLController.ACTION_SPACE`
  keys are therefore alphabetical (`dash, move, shoot, turn`). Wrong order breaks only in-game ONNX inference.
- **ONNX export**: new PyTorch writes weights to a separate `.onnx.data`; the plugin loads from a byte buffer, so
  `training/onnx_export.py` merges them into one file. `onnxscript` must be installed (it is in requirements).
- **Unicode crash**: PyTorch's exporter prints emoji; `train_rl.py` reconfigures stdout/stderr to UTF-8.
- **Rigid-body reset**: `_integrate_forces` uses global transforms; training arenas are offset, so spawn transforms
  are composed with the parent transform (`Fighter.reset_at`, `Crate.reset_at`). Symptom if broken: episodes of 1-2 s.
- **SB3 seeding**: the Godot VecEnv does not support `env.seed()`; seeds are set via `set_random_seed`.
- Godot printing `WARNING: Unable to set TCP no delay option` is harmless.
- If Godot cannot connect to Python ("Couldn't connect to Python server"), the Python side was not listening yet or the
  port 11008 is busy (another training running). Kill leftover `python.exe` / `*_console.exe` processes and retry.

## Key files

| Path | What |
|---|---|
| `training/train_rl.py` | training entry point: launches Godot (`res://scenes/training.tscn`), curriculum, checkpoints, ONNX export |
| `godot/scripts/rl/rl_controller.gd` | observations to Python, reward computation, action decoding |
| `godot/scripts/rl/reward_config.gd` | reward weights (do not change for this task) |
| `godot/scripts/rl/training_scene.gd` | N parallel arenas, shared `ArenaSync` |
| `godot/scripts/rl/arena_sync.gd` | plugin Sync node driven by the game's decision clock |
| `godot/scripts/rl/observation_encoder.gd` | 66-value observation vector (incl. time left and opponent memory, `opponent_memory.gd`) |
| `godot/scripts/core/match_manager.gd` | matches, CLI args (`--brain-a`, `--matches`, `--csv`, `--rl-model`, ...) |
