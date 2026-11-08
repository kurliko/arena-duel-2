# Arena Duel: pojedynek na arenie, dwa boty, dwie strategie

Projekt na przedmiot *Sztuczna inteligencja w grach i rozszerzonej rzeczywistości*.
Autorzy: Filip Opacki, Zofia Jedlińska, Julia Szymczycha.

Dwa boty walczą na arenie 2D z fizyką ciał sztywnych (siły, momenty bezwładności, odrzut, rykoszety, obrażenia z energii
kinetycznej, przesuwane skrzynie):
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

- Mózgi wybiera się w węźle `MatchManager` (Inspektor): `Brain A Name`, `Brain B Name` (`fuzzy`, `scripted` albo `random`).
- HUD pokazuje bieżące zachowanie bota: dla bota rozmytego wybraną akcję i opłacalność wszystkich czterech, dla skryptowego stan maszyny.
- Parametry gry i fizyki są w `res://data/configs/default.tres` (dwuklik otwiera je w Inspektorze).
- Układ areny jest w `res://data/arenas/default_layout.tres`. Arena jest widoczna w edytorze bez uruchamiania gry.

Seria meczów bez grafiki (tryb wsadowy), np. 20 meczów skryptowy kontra losowy z ziarnem 7:
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=scripted --brain-b=random --seed=7
```
Argumenty po `--`: `--brain-a`, `--brain-b`, `--matches` (0 = bez końca), `--seed`, `--config=res://data/configs/....tres`,
`--csv=results/plik.csv` (zapis wyników; ścieżka względna liczona od katalogu repozytorium).
Ten sam seed daje identyczne wyniki.

Przykład: 50 meczów bez rykoszetów z zapisem do CSV:
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path godot -- --matches=50 --brain-a=scripted --brain-b=random --config=res://data/configs/no_ricochet.tres --csv=results/no_ricochet.csv
```

### Format CSV

Jeden wiersz na mecz; kolejne serie dopisują się do istniejącego pliku (nagłówek tylko raz).

| Kolumny | Znaczenie |
|---|---|
| `match_index`, `seed`, `config` | numer meczu w serii, ziarno, nazwa pliku konfiguracji |
| `brain_a`, `brain_b`, `sides_swapped` | mózgi i czy A startował ze strony B |
| `winner` (`A`/`B`/`draw`), `winner_brain`, `reason` (`death`/`time`), `duration` | wynik meczu |
| `hp`, `shots`, `hits`, `accuracy`, `ammo_used`, `damage_taken` z sufiksem `_a`/`_b` | statystyki botów |
| `ricochet_hits`, `self_hits`, `dashes`, `pickups` z sufiksem `_a`/`_b` | trafienia z rykoszetu, samotrafienia, uniki, podniesione pakiety |
| `projectile_speed`, `max_bounces`, `bounce_speed_loss`, `acceleration`, `friction`, `max_speed` | parametry fizyki użyte w meczu |

Gotowe konfiguracje: `default.tres`, `no_ricochet.tres` (pociski znikają na pierwszej ścianie).
Kolumny `damage_dealt`, `medkits` oraz parametry fizyki (masy, tłumienia, restytucja) opisują model z ciałami sztywnymi.

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

## Bot rozmyty

Własny silnik wnioskowania rozmytego (Mamdani) w `godot/scripts/fuzzy/`, baza reguł w `godot/data/fuzzy_rules.json`.
Reguły zapisuje się tekstem, np. `IF hp IS low AND visible IS yes THEN cover IS high`; zmiana reguł nie wymaga zmian w kodzie.

Testy jednostkowe silnika:
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --path godot --script res://tests/test_fuzzy.gd
```

## Bot RL

Bot uczony przez PPO (Stable-Baselines3) przez Godot RL Agents. Kod po stronie gry w `godot/scripts/rl/`,
trening w `training/train_rl.py`.

**Trening z curriculum** (każdy etap uruchamia grę w trybie `--headless` z innym przeciwnikiem):
```
.\venv\Scripts\python training\train_rl.py --curriculum random:400000,scripted:600000,fuzzy:600000 --arenas 8 --run nazwa_przebiegu
```
- `--arenas`: liczba równoległych aren w jednej instancji gry, `--speedup`: przyspieszenie symulacji (domyślnie 8),
  `--resume model.zip`: kontynuacja treningu.
- Wyniki w `training/runs/<nazwa>/`: modele `.zip` i `.onnx` po każdym etapie, checkpointy, logi gry, TensorBoard.
- Końcowy model trafia do `godot/models/rl_brain.onnx`.

**Podgląd przebiegu treningu** (średnia nagroda, długość epizodu, odsetek zwycięstw `rollout/success_rate`):
```
.\venv\Scripts\tensorboard --logdir training\runs
```
i otwórz w przeglądarce http://localhost:6006.

**Mecz z wytrenowanym botem** (model ONNX w grze, bez Pythona): w `MatchManager` ustaw `Brain A Name` = `rl`
albo z konsoli:
```
Godot_v4.7.2-stable_mono_win64_console.exe --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --csv=results/rl_vs_fuzzy.csv
```
Opcje: `--rl-model=res://models/....onnx`, `--rl-deterministic=1` (zawsze najbardziej prawdopodobna akcja).

**Podgląd treningu w edytorze:** scena `res://scenes/training.tscn` pokazuje wszystkie areny naraz. Uruchom najpierw
skrypt treningowy z `--arenas` zgodnym ze sceną (domyślnie 8), potem F6 w edytorze. Bez Pythona boty RL stoją.

### Trening na innym komputerze

1. Zainstaluj Godota 4.7.2 .NET, .NET SDK 8, Pythona 3.12 (z „Add to PATH”) i Gita.
2. Sklonuj repo i przygotuj środowisko (PowerShell):
   ```
   git clone https://github.com/kurliko/arena-duel-2.git
   cd arena-duel-2
   python -m venv venv
   .\venv\Scripts\pip install -r requirements.txt
   dotnet build godot\ArenaDuel.csproj
   ```
3. Skrypt treningowy domyślnie szuka Godota w `C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\`.
   Jeśli Godot leży gdzie indziej, przed treningiem wskaż plik `_console.exe` (w tym samym oknie PowerShella):
   ```
   $env:GODOT_BIN = "C:\sciezka\do\Godot_v4.7.2-stable_mono_win64_console.exe"
   ```
4. Uruchom trening (przykład z długim curriculum, ok. 9 mln kroków):
   ```
   .\venv\Scripts\python training\train_rl.py --curriculum random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
   ```
   Na słabszym komputerze zmniejsz obciążenie: `--arenas 4` albo `--speedup 4` (trening potrwa dłużej).
   Komputer nie może przejść w uśpienie w trakcie treningu.
5. Po treningu:
   - zacommituj i wypchnij `godot/models/rl_brain.onnx` (opis commita po angielsku),
   - folder `training/runs/<nazwa>/` jest w `.gitignore` i **nie trafia na GitHuba**; logi TensorBoarda
     (`training/runs/<nazwa>/tb/`) potrzebne do wykresów w sprawozdaniu przekaż osobno (np. spakowane).

Przerwany trening można wznowić od ostatniego checkpointu (zapis co 100 tys. kroków):
`--resume training\runs\<nazwa>\checkpoints\<plik>.zip`, z pozostałymi etapami w `--curriculum`.

## Struktura

Patrz sekcja 11 w [docs/project-context.md](docs/project-context.md).

## Co jest własnym wkładem, a co gotowym narzędziem

- Gotowe: Godot (silnik i fizyka 2D), Godot RL Agents, Stable-Baselines3.
- Własne: model gry i fizyki, silnik rozmyty i reguły, nagrody i curriculum, tryb wsadowy, eksperymenty, wizualizacje.
