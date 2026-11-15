# Arena Duel: pojedynek na arenie, dwa boty, dwie strategie

Projekt nr 1 z przedmiotu *Sztuczna inteligencja w grach i rozszerzonej rzeczywistości*,
temat 1: „Pojedynek na arenie: dwa boty, dwie strategie”.

**Zespół nr 1, termin zajęć: poniedziałek 10:30**

## Skład zespołu i podział prac

| Osoba | Za co odpowiadała |
|---|---|
| Filip Opacki | implementacja gry, silnik logiki rozmytej i bot rozmyty, środowisko uczenia bota RL |
| Zofia Jedlińska | trening i ewaluacja bota RL, zebranie danych porównawczych |
| Julia Szymczycha | sprawozdanie, analiza porównawcza wyników, prezentacja projektu |

## Cel projektu

Na arenie 2D walczą dwa boty. Każdy sam decyduje, czy atakować, robić unik, schować się za przeszkodą, zebrać
amunicję czy się leczyć. Życie (100 HP) i amunicja (5 naboi na start, najwyżej 10) są ograniczone, a pakiety
amunicji i apteczki pojawiają się ponownie po pewnym czasie. Mecz trwa najwyżej 60 sekund. Kończy się śmiercią
jednego z botów albo upływem czasu; wtedy wygrywa bot z większą liczbą punktów życia, a przy równym HP jest remis.

Porównujemy dwie metody:

- **bot A** podejmuje decyzje na podstawie reguł rozmytych (wnioskowanie Mamdaniego),
- **bot B** uczy się przez uczenie ze wzmocnieniem (algorytm PPO - Proximal Policy Optimization).

Jako punkt odniesienia służą dwa prostsze boty: skryptowy (popularny w grach) i losowy. Mierzymy odsetek
zwycięstw, zużycie amunicji, otrzymane obrażenia i skuteczność przeciw różnym przeciwnikom.

Ważnym wymaganiem jest niezależność: decyzje jednego bota nie mogą zależeć od algorytmu drugiego. Dlatego każdy
bot dostaje tylko to, co sam może zobaczyć.

Najważniejsze wyniki (turniej każdy z każdym, 100 meczów na parę, ziarno 41): bot RL po 15 mln kroków treningu
wygrywa 96% meczów z botem losowym, 45% ze skryptowym i 39% z rozmytym. Bot rozmyty wygrywa 45% meczów ze skryptowym
i 100% z losowym. Wykresy i tabele są w `results/wykresy/`.

## Zawartość katalogów

### Archiwum oddania (`projekt_1_pon_10.30.zip`)

| Katalog / plik | Zawartość |
|---|---|
| `README.md` | ten plik |
| `sprawozdanie.pdf` | sprawozdanie |
| `prezentacja.pdf` | prezentacja z zajęć |
| `kod/` | kompletny kod projektu|
| `dane/` | dane wejściowe gry (reguły rozmyte, konfiguracje fizyki, układ areny, wagi nagród) i przykładowe scenariusze testowe |
| `modele/` | wytrenowane modele bota RL: ONNX (do gry) i zip Stable-Baselines3 (do dalszego treningu) |
| `wyniki/` | wykresy, tabele, surowe wyniki meczów (CSV) i logi TensorBoarda |
| `uruchomienie/` | `instrukcja_uruchomienia.pdf`, `wymagania.txt` i skrypty uruchamiające demo i ewaluację |

### Kod

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
| `results/` | surowe wyniki (CSV), logi TensorBoarda (zip), wykresy i tabele (`wykresy/`) |
| `uruchomienie/` | instrukcja uruchomienia, wymagania, skrypty demo i odtwarzania wyników |
| `scenariusze_testowe.md` | przykładowe scenariusze testowe z poleceniami do uruchomienia |

## Środowisko i wersje

| Składnik | Wersja |
|---|---|
| System | Windows 10/11 (testowane na Windows 11); macOS i Linux powinny działać (nietestowane, polecenia w instrukcji uruchomienia, punkt 9) |
| Godot (build .NET) | 4.7.2 stable |
| .NET SDK | 8.0 |
| Python | 3.12 (Python 3.13 nie zainstaluje `numpy==1.26.4`) |
| Plugin `godot_rl_agents` | commit `998c357` (13.06.2026), w `godot/addons/godot_rl_agents/` |
| Microsoft.ML.OnnxRuntime | 1.20.1 (NuGet, w `godot/ArenaDuel.csproj`) |
| Biblioteki Pythona | `requirements.txt` (godot-rl 0.8.2, Stable-Baselines3 2.4.0, PyTorch 2.15.0, pandas, matplotlib i inne) |

Kod gry jest w GDScript. Build .NET jest potrzebny tylko do uruchamiania modelu ONNX w grze.
Pełna lista wymagań: `uruchomienie/wymagania.txt`.

## Skrócona instrukcja uruchomienia

Pełna instrukcja: `uruchomienie/instrukcja_uruchomienia.pdf`. Polecenia wpisuj w PowerShellu w katalogu `kod/`. `GODOT` oznacza pełną ścieżkę do `Godot_v4.7.2-stable_mono_win64_console.exe`.

1. Zainstaluj Godota 4.7.2 .NET i .NET SDK 8, potem zbuduj część C#:
   ```
   dotnet build godot\ArenaDuel.csproj
   ```
2. **Demo bez treningu**: mecz wytrenowanego bota RL z botem rozmytym, z grafiką (model ONNX jest w projekcie):
   ```
   & GODOT --path godot -- --brain-a=rl --brain-b=fuzzy
   ```
   albo skrypt `uruchomienie\demo.ps1`. Inne pary: `--brain-a` / `--brain-b` = `rl`, `fuzzy`, `scripted`, `random`.
3. **Seria meczów bez grafiki** z zapisem do CSV:
   ```
   & GODOT --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --seed=41 --quiet=1 --csv=results/rl_vs_fuzzy.csv
   ```
4. **Odtworzenie wyników z prezentacji** (ewaluacja obu modeli i turniej, po 100 meczów na parę) i wykresów: `uruchomienie\odtworz_wyniki.ps1`
   (wymaga środowiska Pythona, punkt 5).
5. **Trening** (opcjonalny, ok. 6,5 h): środowisko Pythona i skrypt treningowy:
   ```
   python -m venv venv
   .\venv\Scripts\pip install -r requirements.txt
   .\venv\Scripts\python training\train_rl.py --etapy random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
   ```

## Silnik gry

Gra powstała w silniku **Godot 4.7.2 (.NET)**. Z silnika korzystamy z: symulacji fizyki 2D (ciała sztywne,
kolizje, ciągłe wykrywanie kolizji), raycastów do linii wzroku, edytora scen, renderowania i trybu bez grafiki
(`--headless`) do treningu i serii meczów. Sceny i skrypty to pliki tekstowe w gicie.

## Elementy fizyki

Postacie, pociski i skrzynie to ciała sztywne (`RigidBody2D`). Gra przykłada tylko siły, momenty sił i impulsy,
a ruch liczy silnik fizyki przy stałym kroku 60 Hz. Trening przyspieszamy, zwiększając liczbę kroków fizyki na
sekundę, a nie wydłużając sam krok, bo dłuższy krok psuje kolizje i odbicia.

| Zjawisko | Jak działa | Wpływ na walkę |
|---|---|---|
| Ruch postaci | siła napędu i tłumienie, prędkość maksymalna 220 px/s, stała czasowa 0,25 s | postać nie skręca w miejscu, jej ruch da się przewidzieć |
| Obrót i celowanie | moment siły i moment bezwładności, broń ma pęd kątowy | trzeba hamować obrót przed celem, inaczej broń przestrzeli |
| Unik | impuls dający ok. 480 px/s w bok, odnowienie 1,5 s | unik trzeba zacząć z wyprzedzeniem |
| Odrzut | strzał popycha strzelca do tyłu (ok. 40 px/s) | seria strzałów spycha strzelca z toru |
| Lot pocisku | 500 px/s na starcie, prędkość maleje przez opór; ciągłe wykrywanie kolizji | pocisk widać i można go uniknąć, trzeba celować z wyprzedzeniem |
| Rykoszet | współczynnik odbicia 0,8, najwyżej 2 odbicia | można trafić zza osłony, ale też samego siebie |
| Obrażenia | z energii kinetycznej: D = 35 · (v/v₀)² | strzał z daleka i po odbiciu jest słabszy |
| Skrzynie | ciała o masie 15, można je pchać i obracać | ruchoma osłona zasłania albo odsłania widok |

Przeciwnika i pociski bot widzi tylko wtedy, gdy nic ich nie zasłania (sprawdzane raycastem).

Parametry fizyki są w `godot/data/configs/default.tres` (wersja bez rykoszetów: `no_ricochet.tres`).
Szczegóły i wzory są w sprawozdaniu (`sprawozdanie.pdf`).

## Gotowe narzędzia a własny wkład

| Gotowe (opisujemy, nie przypisujemy sobie) | Własne |
|---|---|
| Godot 4.7.2: silnik, fizyka 2D, raycasty, edytor | model gry i fizyki: siły, masy, momenty bezwładności, tłumienia, restytucja, obrażenia z energii, odrzut, skrzynie |
| Godot RL Agents: węzły `Sync`, `AIController2D`, inferencja ONNX | architektura gry, kontrakty `Brain`/`Observation`/`Action`, percepcja z linią wzroku |
| Stable-Baselines3: algorytm PPO | silnik logiki rozmytej z parserem reguł i testami, baza reguł, bot skryptowy, wspólne zachowania |
| PyTorch, ONNX, OnnxRuntime, pandas, matplotlib | środowisko RL: obserwacje, funkcja nagrody, `ArenaSync`, trening na wielu arenach, trening etapami z kolejnymi przeciwnikami; tryb wsadowy, statystyki, wykresy |

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

**Trening etapami** (każdy etap uruchamia grę w trybie `--headless` z innym przeciwnikiem):
```
.\venv\Scripts\python training\train_rl.py --etapy random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
```
- `--arenas`: liczba równoległych aren w jednej instancji gry, `--speedup`: przyspieszenie symulacji (domyślnie 8),
  `--resume model.zip`: kontynuacja treningu (z tą samą liczbą aren co zapisany model; modele z projektu mają 8).
- Przeciwnicy mieszani na arenach: `scripted+fuzzy` (połowa aren z każdym), np. dotrenowanie użyte w projekcie:
  `--resume training\models\rl_brain_9M_sb3.zip --etapy scripted+fuzzy:6000000 --arenas 8 --seed 7 --run rigid_v3_ext`.
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
| `godot/models/rl_brain.onnx` | model domyślny w grze: 15 mln kroków (trening etapami 9 mln + dotrenowanie 6 mln z mieszanymi przeciwnikami) |
| `godot/models/rl_brain_9M.onnx` | model po 9 mln kroków (do porównania) |
| `training/models/rl_brain_15M_sb3.zip`, `rl_brain_9M_sb3.zip` | te same modele w formacie Stable-Baselines3 (do `--resume`) |
