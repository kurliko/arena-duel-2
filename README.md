# Arena Duel: pojedynek na arenie, dwa boty, dwie strategie

Projekt na przedmiot *Sztuczna inteligencja w grach i rozszerzonej rzeczywistości*.
Autorzy: Filip Opacki, Zofia Jedlińska, Julia Szymczycha.

Dwa boty walczą na arenie 2D z fizyką (pociski z czasem lotu i rykoszetami, bezwładność, przeszkody):
bot rozmyty (własny silnik reguł rozmytych) kontra bot uczony przez RL (PPO).
Szczegóły: [docs/project-context.md](docs/project-context.md).

## Wersje

| Składnik | Wersja |
|---|---|
| Godot (build .NET) | 4.7.2 stable |
| .NET SDK | 8.0 |
| Python | 3.12 |
| Plugin `godot_rl_agents` | commit `998c357` (13.06.2026), w `godot/addons/godot_rl_agents/` |
| Microsoft.ML.OnnxRuntime | 1.20.1 (NuGet, w `godot/ArenaDuel.csproj`) |
| Biblioteki Pythona | `requirements.txt` |

Kod gry jest w GDScript. Build .NET jest potrzebny tylko do inferencji ONNX w pluginie.

## Instalacja od zera

1. Zainstaluj Godota 4.7.2 .NET, .NET SDK 8 i Pythona.
2. W katalogu repo utwórz środowisko Pythona (PowerShell):
   ```
   python -m venv venv
   .\venv\Scripts\pip install -r requirements.txt
   ```
3. Zbuduj część C# (OnnxRuntime dla pluginu):
   ```
   dotnet build godot\ArenaDuel.csproj
   ```

## Pierwsze otwarcie w edytorze Godota

1. Uruchom `Godot_v4.7.2-stable_mono_win64.exe` (wersja bez `_console`). Otworzy się Menedżer projektów.
2. Kliknij **Importuj**, wskaż plik `godot\project.godot` i kliknij **Importuj i edytuj**.
   Pierwsze otwarcie chwilę trwa (Godot generuje cache `.godot/`).
3. Po lewej na dole jest panel **System plików** (`res://` to folder `godot/`). Dwuklik na scenie `.tscn` otwiera ją w edytorze, dwuklik na `.gd` otwiera skrypt.
4. Scenę uruchamiasz klawiszem **F6** (bieżąca scena) albo przyciskiem z „klapsem” w prawym górnym rogu. **F8** zatrzymuje grę.
5. Komunikaty `print()` i błędy widać w panelu **Wyjście** na dole edytora.
6. Po przełączeniu na zakładkę **2D** (góra okna, środek) widać otwartą scenę.

## Mecz botów

Scena główna to `res://scenes/match.tscn`. W edytorze uruchamia się ją klawiszem **F5** (scena główna).
Boty walczą w serii meczów bez końca, a strony areny zmieniają się co mecz. Wynik po każdym meczu widać w panelu **Wyjście**.

- Mózgi wybiera się w węźle `MatchManager` (Inspektor): `Brain A Name`, `Brain B Name` (`scripted` albo `random`).
- Parametry gry i fizyki są w `res://data/configs/default.tres` (dwuklik otwiera je w Inspektorze).
- Układ areny jest w `res://data/arenas/default_layout.tres`. Arena jest widoczna w edytorze bez uruchamiania gry.

Seria meczów bez grafiki (tryb wsadowy), np. 20 meczów skryptowy kontra losowy z ziarnem 7:
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=scripted --brain-b=random --seed=7
```
Argumenty po `--`: `--brain-a`, `--brain-b`, `--matches` (0 = bez końca), `--seed`, `--config=res://data/configs/....tres`.
Ten sam seed daje identyczne wyniki.

## Smoke test Godot RL Agents

Sprawdza cały łańcuch: gra łączy się z Pythonem, PPO się uczy, polityka trafia do ONNX i gra wczytuje ją z powrotem.
Agent (niebieski kwadrat) uczy się dochodzić do celu (czerwony kwadrat).

**Trening (z podglądem w edytorze):**
1. W PowerShellu w katalogu repo:
   ```
   .\venv\Scripts\python training\smoke_train.py --timesteps 20000
   ```
   Skrypt czeka na połączenie z grą.
2. W edytorze otwórz `res://smoke_test/smoke_test.tscn` i naciśnij **F6**. Agent najpierw błądzi, z czasem idzie prosto do celu.
   W konsoli Pythona rośnie `ep_rew_mean`.
3. Po treningu powstaje `godot\models\smoke_test.onnx`.

**Inferencja ONNX w grze:** w edytorze zaznacz węzeł `Sync` w scenie smoke testu, w panelu **Inspektor** ustaw
`Control Mode` na `Onnx Inference`, `Onnx Model Path` na `res://models/smoke_test.onnx` i odznacz `Deterministic Inference`, potem **F6** (bez Pythona).
Nie zapisuj tej zmiany w scenie, albo przywróć `Training` przed commitem.

To samo bez edytora (konsola, bez grafiki):
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path godot res://smoke_test/smoke_test.tscn --quit-after 3000 -- --onnx=res://models/smoke_test.onnx
```
W wyjściu pojawiają się linie `smoke_test: cel osiągnięty (N)`. `--fixed-fps 60` sprawia, że 3000 klatek to 50 s gry.

Wynik weryfikacji (31.10.2026): trening 20 tys. kroków (średnia nagroda 0,8 → 4,6), eksport ONNX, inferencja w Godocie: 7 dojść do celu w 50 s.

## Struktura

Patrz sekcja 11 w [docs/project-context.md](docs/project-context.md).

## Co jest własnym wkładem, a co gotowym narzędziem

- Gotowe: Godot (silnik i fizyka 2D), Godot RL Agents, Stable-Baselines3.
- Własne: model gry i fizyki, silnik rozmyty i reguły, nagrody i curriculum, tryb wsadowy, eksperymenty, wizualizacje.
