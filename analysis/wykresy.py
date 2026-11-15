"""Wykresy i tabele z wyników treningu i ewaluacji bota RL.

Czyta pliki CSV z katalogu results/ i zapisuje wykresy PNG oraz tabele (CSV i Markdown)
do results/wykresy/. Uruchomienie z katalogu repozytorium:

    .\\venv\\Scripts\\python analysis\\wykresy.py
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
OUT = RESULTS / "wykresy"
EVAL_DIR = RESULTS

# Pliki z przebiegiem treningu (każdy wiersz to jedna iteracja PPO).
TRAINING_FILES = ["training_rigid_v3_9M.csv", "training_rigid_v3_ext_15M.csv"]
# Ewaluacje po 100 meczów na przeciwnika; klucz to etykieta modelu.
EVAL_FILES = {"9M": "eval_rigid_v3_9M_100x3.csv", "15M": "eval_rigid_v3_15M_100x3.csv"}
OPPONENTS = ["random", "scripted", "fuzzy"]
OPPONENT_LABELS = {"random": "losowy", "scripted": "skryptowy", "fuzzy": "rozmyty"}
# Granice etapów treningu w krokach i ich opisy.
STAGES = [(0, 3e6, "losowy"), (3e6, 6e6, "skryptowy"), (6e6, 9e6, "rozmyty"), (9e6, 15e6, "skryptowy + rozmyty")]
BIN_STEPS = 250_000
Z_95 = 1.96

COLOR_9M = "#A78BFA"
COLOR_15M = "#2563EB"


def wilson(wins: int, n: int) -> tuple[float, float]:
    """Przedział ufności 95% Wilsona dla odsetka zwycięstw."""
    if n == 0:
        return 0.0, 0.0
    p = wins / n
    denom = 1 + Z_95**2 / n
    centre = (p + Z_95**2 / (2 * n)) / denom
    half = Z_95 * math.sqrt(p * (1 - p) / n + Z_95**2 / (4 * n * n)) / denom
    return centre - half, centre + half


def learning_curve() -> None:
    frames = [pd.read_csv(RESULTS / f) for f in TRAINING_FILES]
    data = pd.concat(frames).sort_values("total_timesteps")
    data["bin"] = data["total_timesteps"] // BIN_STEPS
    curve = data.groupby("bin").agg(steps=("total_timesteps", "mean"), success=("success_rate", "mean"),
                                    reward=("ep_rew_mean", "mean"))

    fig, axes = plt.subplots(2, 1, figsize=(11, 7), sharex=True)
    for ax in axes:
        for i, (start, end, label) in enumerate(STAGES):
            ax.axvspan(start / 1e6, end / 1e6, color="#EEEAF7" if i % 2 == 0 else "#FFFFFF", zorder=0)
    for start, end, label in STAGES:
        axes[0].text((start + end) / 2e6, 1.02, label, ha="center", va="bottom", fontsize=9,
                     transform=axes[0].get_xaxis_transform())
    axes[0].plot(curve["steps"] / 1e6, curve["success"] * 100, color=COLOR_15M, linewidth=2)
    axes[0].set_ylabel("wygrane mecze treningowe [%]")
    axes[0].set_ylim(0, 100)
    axes[0].yaxis.set_major_formatter(lambda v, _: f"{v:.0f}")
    axes[1].plot(curve["steps"] / 1e6, curve["reward"], color="#7C3AED", linewidth=2)
    axes[1].set_ylabel("średnia nagroda w epizodzie")
    axes[1].set_xlabel("kroki treningu [mln]")
    axes[0].set_title("Trening bota RL: curriculum (0–9 mln) i dotrenowanie (9–15 mln)", pad=22)
    fig.tight_layout()
    fig.savefig(OUT / "krzywa_uczenia.png", dpi=150)
    plt.close(fig)


def evaluation_table() -> pd.DataFrame:
    rows = []
    for model, file in EVAL_FILES.items():
        data = pd.read_csv(EVAL_DIR / file)
        for opp in OPPONENTS:
            d = data[data["brain_b"] == opp]
            n = len(d)
            wins = int((d["winner_brain"] == "rl").sum())
            draws = int((d["winner"] == "draw").sum())
            low, high = wilson(wins, n)
            rows.append({
                "model": model,
                "przeciwnik": OPPONENT_LABELS[opp],
                "mecze": n,
                "wygrane": wins,
                "przegrane": n - wins - draws,
                "remisy": draws,
                "odsetek_wygranych": round(wins / n, 3),
                "ci95_dol": round(low, 3),
                "ci95_gora": round(high, 3),
                "celnosc_rl": round(d["hits_a"].sum() / max(d["shots_a"].sum(), 1), 3),
                "celnosc_przeciwnika": round(d["hits_b"].sum() / max(d["shots_b"].sum(), 1), 3),
                "zuzyta_amunicja_rl": round(d["ammo_used_a"].mean(), 1),
                "obrazenia_otrzymane_rl": round(d["damage_taken_a"].mean(), 1),
                "obrazenia_otrzymane_przeciwnik": round(d["damage_taken_b"].mean(), 1),
                "samotrafienia_rl": round(d["self_hits_a"].mean(), 2),
                "sredni_czas_meczu_s": round(d["duration"].mean(), 1),
            })
    return pd.DataFrame(rows)


def win_rate_chart(table: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(9, 5))
    width = 0.36
    for i, (model, color) in enumerate([("9M", COLOR_9M), ("15M", COLOR_15M)]):
        t = table[table["model"] == model].set_index("przeciwnik").loc[[OPPONENT_LABELS[o] for o in OPPONENTS]]
        x = [j + (i - 0.5) * width for j in range(len(OPPONENTS))]
        rate = t["odsetek_wygranych"] * 100
        err = [(t["odsetek_wygranych"] - t["ci95_dol"]) * 100, (t["ci95_gora"] - t["odsetek_wygranych"]) * 100]
        ax.bar(x, rate, width, color=color, label=f"model po {model[:-1]} mln kroków", yerr=err, capsize=4)
        for xi, r in zip(x, rate):
            ax.text(xi, r / 2, f"{r:.0f}%", ha="center", va="center", fontsize=11, color="white",
                    fontweight="bold")
    ax.set_xticks(range(len(OPPONENTS)), [OPPONENT_LABELS[o] for o in OPPONENTS])
    ax.set_ylabel("zwycięstwa bota RL [%]")
    ax.set_ylim(0, 110)
    ax.axhline(50, color="#999999", linewidth=1, linestyle="--")
    ax.set_title("Bot RL kontra przeciwnicy: 100 meczów na parę, przedziały ufności 95%")
    ax.legend(loc="upper right")
    fig.tight_layout()
    fig.savefig(OUT / "wygrane_rl_9M_15M.png", dpi=150)
    plt.close(fig)


# Turniej każdy z każdym: pary bez bota RL z osobnego pliku, pary z botem RL z ewaluacji modelu 15M.
TOURNAMENT_FILE = "turniej_bez_rl_100.csv"
BRAINS = ["rl", "fuzzy", "scripted", "random"]
BRAIN_LABELS = {"rl": "RL (15M)", "fuzzy": "rozmyty", "scripted": "skryptowy", "random": "losowy"}


def _pair_stats(d: pd.DataFrame, a: str, b: str) -> dict:
    """Statystyki pary, gdzie a grał jako bot A, a b jako bot B."""
    n = len(d)
    wins_a = int((d["winner"] == "A").sum())
    wins_b = int((d["winner"] == "B").sum())
    low, high = wilson(wins_a, n)
    return {
        "bot_1": BRAIN_LABELS[a], "bot_2": BRAIN_LABELS[b], "mecze": n,
        "wygrane_1": wins_a, "wygrane_2": wins_b, "remisy": n - wins_a - wins_b,
        "odsetek_wygranych_1": round(wins_a / n, 3), "ci95_dol": round(low, 3), "ci95_gora": round(high, 3),
        "celnosc_1": round(d["hits_a"].sum() / max(d["shots_a"].sum(), 1), 3),
        "celnosc_2": round(d["hits_b"].sum() / max(d["shots_b"].sum(), 1), 3),
        "zuzyta_amunicja_1": round(d["ammo_used_a"].mean(), 1),
        "zuzyta_amunicja_2": round(d["ammo_used_b"].mean(), 1),
        "obrazenia_otrzymane_1": round(d["damage_taken_a"].mean(), 1),
        "obrazenia_otrzymane_2": round(d["damage_taken_b"].mean(), 1),
        "mecze_do_smierci": int((d["reason"] == "death").sum()),
    }


def tournament() -> pd.DataFrame | None:
    path = EVAL_DIR / TOURNAMENT_FILE
    if not path.exists():
        return None
    games = [pd.read_csv(path), pd.read_csv(EVAL_DIR / EVAL_FILES["15M"])]
    data = pd.concat(games)
    rows = [_pair_stats(g, a, b) for (a, b), g in data.groupby(["brain_a", "brain_b"])]
    table = pd.DataFrame(rows)
    order = {BRAIN_LABELS[b]: i for i, b in enumerate(BRAINS)}
    table = table.sort_values(by=["bot_1", "bot_2"], key=lambda s: s.map(order)).reset_index(drop=True)

    # Macierz: odsetek zwycięstw bota z wiersza nad botem z kolumny.
    labels = [BRAIN_LABELS[b] for b in BRAINS]
    matrix = pd.DataFrame(index=labels, columns=labels, dtype=float)
    for r in table.itertuples(index=False):
        matrix.loc[r.bot_1, r.bot_2] = r.wygrane_1 / r.mecze
        matrix.loc[r.bot_2, r.bot_1] = r.wygrane_2 / r.mecze

    fig, ax = plt.subplots(figsize=(7.5, 6))
    values = matrix.to_numpy(dtype=float)
    image = ax.imshow(values * 100, cmap="PuBu", vmin=0, vmax=100)
    for i in range(len(labels)):
        for j in range(len(labels)):
            if i == j:
                ax.text(j, i, "–", ha="center", va="center", color="#666666")
            else:
                v = values[i, j] * 100
                ax.text(j, i, f"{v:.0f}%", ha="center", va="center", fontsize=12,
                        color="white" if v > 55 else "#1b1b24")
    ax.set_xticks(range(len(labels)), labels)
    ax.set_yticks(range(len(labels)), labels)
    ax.set_xlabel("przeciwnik")
    ax.set_ylabel("bot")
    ax.set_title("Turniej: odsetek zwycięstw bota (wiersz) nad przeciwnikiem (kolumna)\n100 meczów na parę, reszta do 100% to remisy i porażki", fontsize=10)
    fig.colorbar(image, ax=ax, label="zwycięstwa [%]")
    fig.tight_layout()
    fig.savefig(OUT / "turniej_macierz.png", dpi=150)
    plt.close(fig)
    (matrix * 100).round(0).to_csv(OUT / "turniej_macierz.csv")
    return table


def main() -> None:
    global OUT, EVAL_DIR
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--eval-dir", default="results", help="katalog z plikami eval_rigid_v3_*_100x3.csv")
    parser.add_argument("--out", default="results/wykresy", help="katalog na wykresy i tabele")
    args = parser.parse_args()
    EVAL_DIR = ROOT / args.eval_dir
    OUT = ROOT / args.out
    OUT.mkdir(parents=True, exist_ok=True)
    learning_curve()
    table = evaluation_table()
    table.to_csv(OUT / "tabela_ewaluacji.csv", index=False)
    (OUT / "tabela_ewaluacji.md").write_text(table.to_markdown(index=False) if _has_tabulate() else _md(table),
                                            encoding="utf-8")
    win_rate_chart(table)
    pairs = tournament()
    if pairs is not None:
        pairs.to_csv(OUT / "tabela_turnieju.csv", index=False)
        (OUT / "tabela_turnieju.md").write_text(_md(pairs), encoding="utf-8")
    print(f"Zapisano wykresy i tabele w {OUT}")


def _has_tabulate() -> bool:
    try:
        import tabulate  # noqa: F401
        return True
    except ImportError:
        return False


def _md(table: pd.DataFrame) -> str:
    header = "| " + " | ".join(table.columns) + " |"
    sep = "|" + "---|" * len(table.columns)
    rows = ["| " + " | ".join(str(v) for v in row) + " |" for row in table.itertuples(index=False)]
    return "\n".join([header, sep, *rows]) + "\n"


if __name__ == "__main__":
    main()
