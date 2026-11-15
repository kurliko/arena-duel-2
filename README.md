# Arena Duel: pojedynek na arenie, dwa boty, dwie strategie

Projekt nr 1 z przedmiotu *Sztuczna inteligencja w grach i rozszerzonej rzeczywistości*,
temat 1: „Pojedynek na arenie: dwa boty, dwie strategie”.

**Zespół nr [NR ZESPOŁU], termin zajęć: [DZIEŃ] [GODZINA]**

## Skład zespołu i podział prac

| Osoba | Za co odpowiadała |
|---|---|
| Filip Opacki | [DO UZUPEŁNIENIA] |
| Zofia Jedlińska | [DO UZUPEŁNIENIA] |
| Julia Szymczycha | [DO UZUPEŁNIENIA] |

## Cel projektu

Na arenie 2D z fizyką walczą dwa boty. Każdy sam decyduje, czy atakować, robić unik, chować się za przeszkodą,
zbierać amunicję czy się leczyć. Życie i amunicja są ograniczone.

- **Bot A** decyduje na podstawie reguł rozmytych (własny silnik wnioskowania Mamdaniego, 36 reguł w pliku JSON).
- **Bot B** uczy się strategii przez uczenie ze wzmocnieniem (PPO ze Stable-Baselines3, połączenie z grą przez Godot RL Agents).

Oba boty sterują tą samą postacią (to samo życie, broń i fizyka) i widzą tylko własne obserwacje, więc różnią się
wyłącznie algorytmem decyzji. Celem jest porównanie obu metod: odsetek zwycięstw, zużycie amunicji, otrzymane
obrażenia i skuteczność przeciw różnym przeciwnikom (losowemu i skryptowemu, czyli prostej maszynie stanów).

Najważniejsze wyniki (turniej każdy z każdym, 100 meczów na parę, ziarno 41): bot RL po 15 mln kroków treningu
wygrywa 96% meczów z botem losowym, 45% ze skryptowym i 39% z rozmytym. Bot rozmyty wygrywa 45% meczów ze skryptowym
i 100% z losowym. Wykresy i tabele są w `results/wykresy/`.

## Zawartość katalogów

### Archiwum oddania (`projekt_<zespół>_<dzień>_<godzina>.zip`)

| Katalog / plik | Zawartość |
|---|---|
| `README.md` | ten plik |
| `sprawozdanie.pdf` | sprawozdanie |
| `prezentacja.pdf` | prezentacja z zajęć |
| `kod/` | kompletny kod projektu, czyli kopia repozytorium (bez plików tymczasowych i przebiegów treningu) |
| `dane/` | dane wejściowe gry (reguły rozmyte, konfiguracje fizyki, układ areny, wagi nagród) i przykładowe scenariusze testowe |
| `modele/` | wytrenowane modele bota RL: ONNX (do gry) i zip Stable-Baselines3 (do dalszego treningu) |
| `wyniki/` | wykresy, tabele, zrzuty ekranu, surowe wyniki meczów (CSV) i logi TensorBoarda |
| `uruchomienie/` | `instrukcja_uruchomienia.pdf`, `wymagania.txt` i skrypty uruchamiające demo i ewaluację |

Archiwum tworzy skrypt `uruchomienie/pakuj_oddanie.py` (opis na końcu instrukcji uruchomienia).

### Repozytorium (katalog `kod/` w archiwum)

| Katalog | Zawartość |
|---|---|
| `godot/` | projekt Godota: sceny (`scenes/`), skrypty GDScript (`scripts/`), dane gry (`data/`), modele ONNX (`models/`), testy (`tests/`), plugin Godot RL Agents (`addons/`) |
| `godot/scripts/core/` | gra: postać, pociski, arena, skrzynie, przebieg meczu, percepcja, konfiguracja |
| `godot/scripts/brains/` | mózgi botów: interfejs `Brain`, `FuzzyBrain`, `RLBrain`, `ScriptedBrain`, `RandomBrain` |
| `godot/scripts/fuzzy/` | własny silnik logiki rozmytej |
| `godot/scripts/navigation/` | wspólne zachowania (atak, unik, osłona, szukanie, amunicja) i sterowanie |
| `godot/scripts/rl/` | środowisko RL: koder obserwacji, nagroda, synchronizacja z Pythonem, scena treningowa |
| `godot/scripts/stats/` | statystyki meczów i zapis CSV |
| `training/` | trening PPO (`train_rl.py`), eksport ONNX, modele SB3 (`models/`) |
| `analysis/` | wykresy i tabele z wyników (`wykresy.py`) |
| `results/` | surowe wyniki (CSV), logi TensorBoarda (zip), `wykresy/`, `zrzuty/` |
| `uruchomienie/` | instrukcja uruchomienia, wymagania, skrypty demo, ewaluacji i pakowania |
| `docs/` | dziennik prac i decyzje projektowe (`dziennik-prac.md`), założenia projektu (`project-context.md`), scenariusze testowe |

## Środowisko i wersje

| Składnik | Wersja |
|---|---|
| System | Windows 10/11 (testowane na Windows 11) |
| Godot (build .NET) | 4.7.2 stable |
| .NET SDK | 8.0 |
| Python | 3.12 (Python 3.13 nie zainstaluje `numpy==1.26.4`) |
| Plugin `godot_rl_agents` | commit `998c357` (13.06.2026), w `godot/addons/godot_rl_agents/` |
| Microsoft.ML.OnnxRuntime | 1.20.1 (NuGet, w `godot/ArenaDuel.csproj`) |
| Biblioteki Pythona | `requirements.txt` (godot-rl 0.8.2, Stable-Baselines3 2.4.0, PyTorch 2.15.0, pandas, matplotlib i inne) |

Kod gry jest w GDScript. Build .NET jest potrzebny tylko do uruchamiania modelu ONNX w grze.
Pełna lista wymagań: `uruchomienie/wymagania.txt`.

## Skrócona instrukcja uruchomienia

Pełna instrukcja: `uruchomienie/instrukcja_uruchomienia.pdf`. Polecenia wpisuj w PowerShellu w katalogu `kod/`
(w repozytorium: w katalogu głównym). `GODOT` oznacza pełną ścieżkę do `Godot_v4.7.2-stable_mono_win64_console.exe`.

1. Zainstaluj Godota 4.7.2 .NET i .NET SDK 8, potem zbuduj część C#:
   ```
   dotnet build godot\ArenaDuel.csproj
   ```
2. **Demo bez treningu**: mecz wytrenowanego bota RL z botem rozmytym, z grafiką (model ONNX jest w repozytorium):
   ```
   & GODOT --path godot -- --brain-a=rl --brain-b=fuzzy
   ```
   albo skrypt `uruchomienie\demo.ps1`. Inne pary: `--brain-a` / `--brain-b` = `rl`, `fuzzy`, `scripted`, `random`.
3. **Seria meczów bez grafiki** z zapisem do CSV:
   ```
   & GODOT --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --seed=41 --quiet=1 --csv=results/rl_vs_fuzzy.csv
   ```
4. **Odtworzenie wyników z prezentacji** (300 meczów na model) i wykresów: `uruchomienie\odtworz_wyniki.ps1`
   (wymaga środowiska Pythona, punkt 5).
5. **Trening** (opcjonalny, ok. 6,5 h): środowisko Pythona i skrypt treningowy:
   ```
   python -m venv venv
   .\venv\Scripts\pip install -r requirements.txt
   .\venv\Scripts\python training\train_rl.py --curriculum random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
   ```

## Silnik gry

Gra powstała w silniku **Godot 4.7.2 (.NET)**. Z silnika korzystamy z: symulacji fizyki 2D (ciała sztywne,
kolizje, ciągłe wykrywanie kolizji), raycastów do linii wzroku, edytora scen, renderowania i trybu bez grafiki
(`--headless`) do treningu i serii meczów. Sceny i skrypty to pliki tekstowe w gicie.

## Elementy fizyki

Postacie, pociski i skrzynie to ciała sztywne (`RigidBody2D`). Gra przykłada tylko siły, momenty sił i impulsy,
a ruch liczy silnik fizyki przy stałym kroku 60 Hz.

- **Bezwładność ruchu**: siła napędu i tłumienie liniowe, prędkość maksymalna 220 px/s; postać nie zmienia kierunku od razu.
- **Obrót i celowanie**: moment siły i moment bezwładności, więc broń ma pęd kątowy i trzeba ją hamować przed celem.
- **Unik**: impuls prędkości w bok, z czasem odnowienia 1,5 s.
- **Odrzut**: strzał daje strzelcowi impuls przeciwny do pocisku.
- **Lot pocisku**: prędkość 500 px/s malejąca przez tłumienie, ciągłe wykrywanie kolizji (CCD).
- **Rykoszety**: restytucja 0,8, najwyżej 2 odbicia; można trafić zza osłony, ale też samego siebie.
- **Obrażenia z energii kinetycznej**: D = 35 · (v/v₀)², więc strzał z daleka i po rykoszecie jest słabszy.
- **Trafienie**: zderzenie przekazuje pęd i spycha trafionego.
- **Skrzynie**: ruchome osłony o masie 15, które można pchać i obracać.
- **Linia wzroku**: raycast; przeszkody i skrzynie zasłaniają przeciwnika i pociski.

Parametry fizyki są w `godot/data/configs/default.tres` (wersja bez rykoszetów: `no_ricochet.tres`).
Szczegóły i wzory: `docs/dziennik-prac.md`, rozdział 4.

## Repozytorium

https://github.com/kurliko/arena-duel-2 (gałąź `main`). Oceniana wersja (numer commita) jest w pliku `kod/WERSJA.txt`
w archiwum.

## Gotowe narzędzia a własny wkład

| Gotowe (opisujemy, nie przypisujemy sobie) | Własne |
|---|---|
| Godot 4.7.2: silnik, fizyka 2D, raycasty, edytor | model gry i fizyki: siły, masy, momenty bezwładności, tłumienia, restytucja, obrażenia z energii, odrzut, skrzynie |
| Godot RL Agents: węzły `Sync`, `AIController2D`, inferencja ONNX | architektura gry, kontrakty `Brain`/`Observation`/`Action`, percepcja z linią wzroku |
| Stable-Baselines3: algorytm PPO | silnik logiki rozmytej z parserem reguł i testami, baza reguł, bot skryptowy, wspólne zachowania |
| PyTorch, ONNX, OnnxRuntime, pandas, matplotlib | środowisko RL: obserwacje, funkcja nagrody, `ArenaSync`, trening na wielu arenach, curriculum; tryb wsadowy, statystyki, wykresy |

---

# Szczegóły techniczne

## Pierwsze otwarcie w edytorze Godota

1. Uruchom `Godot_v4.7.2-stable_mono_win64.exe` (wersja bez `_console`). Otworzy się Menedżer projektów.
2. Kliknij **Importuj**, wskaż plik `godot\project.godot` i kliknij **Importuj i edytuj**.
   Pierwsze otwarcie chwilę trwa (Godot generuje cache `.godot/`).
3. Scenę główną (`res://scenes/match.tscn`) uruchamiasz klawiszem **F5**, bieżącą scenę klawiszem **F6**. **F8** zatrzymuje grę.
4. Komunikaty i błędy widać w panelu **Wyjście** na dole edytora.

## Mecz botów

Boty walczą w serii meczów, a strony areny zmieniają się co mecz.

- Mózgi wybiera się w węźle `MatchManager` (Inspektor): `Brain A Name`, `Brain B Name` (`rl`, `fuzzy`, `scripted`, `random`)
  albo argumentami `--brain-a`, `--brain-b`.
- HUD pokazuje HP, amunicję i prędkość botów, a dla bota rozmytego wybrane zachowanie i ocenę wszystkich zachowań.
- Parametry gry i fizyki: `res://data/configs/default.tres`. Układ areny: `res://data/arenas/default_layout.tres`.

Argumenty po `--`: `--brain-a`, `--brain-b`, `--matches` (0 = bez końca), `--seed`, `--config=res://data/configs/....tres`,
`--csv=results/plik.csv` (ścieżka względna liczona od katalogu repozytorium), `--rl-model=res://models/....onnx`,
`--rl-deterministic=1` (zawsze najbardziej prawdopodobna akcja), `--quiet=1` (bez wypisywania każdego meczu).
Ten sam seed daje identyczne wyniki.

### Format CSV

Jeden wiersz na mecz; kolejne serie dopisują się do istniejącego pliku (nagłówek tylko raz).

| Kolumny | Znaczenie |
|---|---|
| `match_index`, `seed`, `config` | numer meczu w serii, ziarno, nazwa pliku konfiguracji |
| `brain_a`, `brain_b`, `sides_swapped` | mózgi i czy A startował ze strony B |
| `winner` (`A`/`B`/`draw`), `winner_brain`, `reason` (`death`/`time`), `duration` | wynik meczu |
| `hp`, `shots`, `hits`, `accuracy`, `ammo_used`, `damage_dealt`, `damage_taken`, `medkits` z sufiksem `_a`/`_b` | statystyki botów |
| `ricochet_hits`, `self_hits`, `dashes`, `pickups` z sufiksem `_a`/`_b` | trafienia z rykoszetu, samotrafienia, uniki, podniesione pakiety |
| `projectile_speed`, `max_bounces`, masy, tłumienia, restytucja | parametry fizyki użyte w meczu |

## Bot rozmyty

Własny silnik wnioskowania rozmytego (Mamdani) w `godot/scripts/fuzzy/`, baza reguł w `godot/data/fuzzy_rules.json`.
Reguły zapisuje się tekstem, np. `IF hp IS low AND visible IS yes THEN cover IS high`; zmiana reguł nie wymaga zmian w kodzie.

Testy jednostkowe silnika (kod wyjścia 0 = wszystkie przeszły):
```
& GODOT --headless --path godot --script res://tests/test_fuzzy.gd
```

## Bot RL

Kod po stronie gry w `godot/scripts/rl/`, trening w `training/train_rl.py`.

**Trening z curriculum** (każdy etap uruchamia grę w trybie `--headless` z innym przeciwnikiem):
```
.\venv\Scripts\python training\train_rl.py --curriculum random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
```
- `--arenas`: liczba równoległych aren w jednej instancji gry, `--speedup`: przyspieszenie symulacji (domyślnie 8),
  `--resume model.zip`: kontynuacja treningu.
- Przeciwnicy mieszani na arenach: `scripted+fuzzy` (połowa aren z każdym), np. dotrenowanie użyte w projekcie:
  `--resume training\models\rl_brain_9M_sb3.zip --curriculum scripted+fuzzy:6000000 --arenas 8 --seed 7 --run rigid_v3_ext`.
- Skrypt szuka Godota w `C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\`;
  inną ścieżkę podaje się zmienną `$env:GODOT_BIN`.
- Wyniki w `training/runs/<nazwa>/` (poza gitem): modele `.zip` i `.onnx` po każdym etapie, checkpointy co 100 tys. kroków,
  logi gry, TensorBoard. Końcowy model trafia do `godot/models/rl_brain.onnx`.

**Podgląd przebiegu treningu**: `.\venv\Scripts\tensorboard --logdir training\runs`, potem http://localhost:6006.
Logi z treningów użytych w projekcie są spakowane w `results/*_tb.zip`.

**Podgląd treningu w edytorze:** scena `res://scenes/training.tscn` pokazuje wszystkie areny naraz. Uruchom najpierw
skrypt treningowy z `--arenas` zgodnym ze sceną (domyślnie 8), potem F6 w edytorze. Bez Pythona boty RL stoją.

## Modele

| Plik | Opis |
|---|---|
| `godot/models/rl_brain.onnx` | model domyślny w grze: 15 mln kroków (curriculum 9 mln + dotrenowanie 6 mln z mieszanymi przeciwnikami) |
| `godot/models/rl_brain_9M.onnx` | model po 9 mln kroków (do porównania) |
| `training/models/rl_brain_15M_sb3.zip`, `rl_brain_9M_sb3.zip` | te same modele w formacie Stable-Baselines3 (do `--resume`) |
| `godot/models/smoke_test.onnx` | model ze smoke testu Godot RL Agents |

## Smoke test Godot RL Agents

Sprawdza cały łańcuch: gra łączy się z Pythonem, PPO się uczy, polityka trafia do ONNX i gra wczytuje ją z powrotem.
```
.\venv\Scripts\python training\smoke_train.py --timesteps 20000
```
Potem w edytorze scena `res://smoke_test/smoke_test.tscn` i **F6**. Inferencja bez Pythona:
```
& GODOT --headless --fixed-fps 60 --path godot res://smoke_test/smoke_test.tscn --quit-after 3000 -- --onnx=res://models/smoke_test.onnx
```
