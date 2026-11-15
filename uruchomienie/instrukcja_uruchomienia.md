## 1. Instalacja

1. **Godot 4.7.2 .NET** (Windows 64-bit) ze strony https://godotengine.org/download/archive/
   (wersja „.NET”, nie „Standard”). Rozpakuj archiwum, np. do `C:\Tools\Godot\`.
   W środku są dwa pliki: `Godot_v4.7.2-stable_mono_win64.exe` (edytor) i
   `Godot_v4.7.2-stable_mono_win64_console.exe` (to samo z konsolą; tego używamy w poleceniach).
2. **.NET SDK 8.0** ze strony https://dotnet.microsoft.com/download/dotnet/8.0.
3. **Python 3.12** ze strony https://www.python.org/downloads/ (zaznacz „Add python.exe to PATH”).
   Python jest potrzebny tylko do treningu i wykresów. Demo działa bez niego.

W poleceniach poniżej `GODOT` oznacza pełną ścieżkę do pliku `_console.exe`. Najwygodniej zapisać ją raz
w zmiennej (w tym samym oknie PowerShella):

```
$env:GODOT_BIN = "C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
$GODOT = $env:GODOT_BIN
```

Skrypty z katalogu `uruchomienie/` i skrypt treningowy czytają tę samą zmienną `GODOT_BIN`.

## 2. Przygotowanie projektu (raz)

```
dotnet build godot\ArenaDuel.csproj
& $GODOT --headless --path godot --import
```

Pierwsze polecenie buduje część C# (OnnxRuntime do uruchamiania modelu bota RL), drugie importuje zasoby
projektu (tworzy katalog `godot/.godot/`).

## 3. Demo: mecz botów z grafiką (bez treningu)

Wytrenowany model bota RL (`godot/models/rl_brain.onnx`) jest dołączony, więc mecz można obejrzeć od razu:

```
& $GODOT --path godot -- --brain-a=rl --brain-b=fuzzy --seed=41
```

albo skryptem (w archiwum z katalogu głównego archiwum: `.\uruchomienie\demo.ps1`):

```
powershell -ExecutionPolicy Bypass -File ..\uruchomienie\demo.ps1
powershell -ExecutionPolicy Bypass -File ..\uruchomienie\demo.ps1 -BrainA fuzzy -BrainB scripted
```

Mózgi botów: `rl` (uczenie ze wzmocnieniem), `fuzzy` (reguły rozmyte), `scripted` (maszyna stanów), `random` (losowy).
Mecze trwają w pętli, a strony areny zmieniają się co mecz. Na górze ekranu HUD pokazuje HP, amunicję i prędkość
botów, wynik serii, a dla bota rozmytego wybrane zachowanie i ocenę wszystkich zachowań. Grę kończy się,
zamykając okno.

Ten sam mecz w edytorze Godota: uruchom `Godot_v4.7.2-stable_mono_win64.exe`, kliknij **Importuj**, wskaż
`godot\project.godot`, potem **F5**. Mózgi zmienia się w węźle `MatchManager` (panel Inspektor: `Brain A Name`,
`Brain B Name`).

Inne przykładowe scenariusze (bez rykoszetów, model po 9 mln kroków, polityka deterministyczna i inne) są opisane
w pliku `scenariusze_testowe.md` w katalogu `kod/`.

## 4. Seria meczów bez grafiki i zapis wyników do CSV

```
& $GODOT --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --seed=41 --quiet=1 --csv=results/rl_vs_fuzzy.csv
```

Argumenty po `--`:

| Argument | Znaczenie |
|---|---|
| `--brain-a`, `--brain-b` | mózgi botów: `rl`, `fuzzy`, `scripted`, `random` |
| `--matches=N` | liczba meczów, potem wyjście (0 = bez końca) |
| `--seed=S` | ziarno; ten sam seed daje identyczne mecze |
| `--config=res://data/configs/....tres` | parametry gry i fizyki (`default.tres`, `no_ricochet.tres`) |
| `--csv=ŚCIEŻKA` | dopisywanie wyników do pliku CSV (ścieżka względna od katalogu `kod/`) |
| `--rl-model=res://models/....onnx` | inny model bota RL, np. `rl_brain_9M.onnx` |
| `--rl-deterministic=1` | bot RL zawsze wybiera najbardziej prawdopodobną akcję |
| `--quiet=1` | bez wypisywania wyniku każdego meczu |

Jeden wiersz CSV to jeden mecz: zwycięzca, powód końca, czas, a dla każdego bota strzały, trafienia, celność,
zużyta amunicja, zadane i otrzymane obrażenia, trafienia z rykoszetu, samotrafienia, uniki, podniesione pakiety
oraz parametry fizyki użyte w meczu.

## 5. Testy silnika logiki rozmytej

```
& $GODOT --headless --path godot --script res://tests/test_fuzzy.gd
```

Kod wyjścia 0 oznacza, że wszystkie testy przeszły.

## 6. Odtworzenie wyników z prezentacji

Wszystkie wyniki meczów z prezentacji (ziarno 41, 100 meczów na parę) odtwarza jeden skrypt: ewaluację bota RL
(modele po 9 i 15 mln kroków przeciw botom losowemu, skryptowemu i rozmytemu) oraz pozostałe pary turnieju każdy
z każdym (rozmyty, skryptowy, losowy):

```
powershell -ExecutionPolicy Bypass -File ..\uruchomienie\odtworz_wyniki.ps1
```

Skrypt uruchamia 9 serii meczów równolegle (ok. 15–30 minut), zapisuje CSV w `results/odtworzone/` i rysuje
wykresy i tabele (wymaga środowiska Pythona z punktu 7). Te same ziarna dają te same mecze, więc tabele
w `results/odtworzone/` powinny być identyczne z tymi w `results/wykresy/`.

Same wykresy z dołączonych wyników:

```
.\venv\Scripts\python analysis\wykresy.py
```

Tworzy w `results/wykresy/`: krzywą uczenia (`krzywa_uczenia.png`), porównanie modeli (`wygrane_rl_9M_15M.png`),
macierz turnieju (`turniej_macierz.png`, `.csv`) oraz tabele ewaluacji i turnieju (`tabela_ewaluacji.*`,
`tabela_turnieju.*`) z celnością, zużyciem amunicji i otrzymanymi obrażeniami.

## 7. Środowisko Pythona

```
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt
```

## 8. Trening bota RL (opcjonalnie)

Trening nie jest potrzebny do demo ani do odtworzenia wyników, bo wytrenowane modele są dołączone. Pełny trening
z projektu trwał ok. 6,5 h na laptopie z 16 wątkami CPU.

Etap 1: trening etapami, 9 mln kroków (przeciwnik losowy, skryptowy, rozmyty, po 3 mln):

```
.\venv\Scripts\python training\train_rl.py --etapy random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
```

Etap 2: dotrenowanie o 6 mln kroków z przeciwnikami mieszanymi na arenach (połowa skryptowy, połowa rozmyty):

```
.\venv\Scripts\python training\train_rl.py --resume training\runs\rigid_v3\stage2_fuzzy.zip --etapy scripted+fuzzy:6000000 --arenas 8 --seed 7 --run rigid_v3_ext
```

Zamiast własnego etapu 1 można dotrenowywać dołączony model: `--resume training\models\rl_brain_9M_sb3.zip`.

- Skrypt sam uruchamia grę w trybie bez grafiki. Ścieżkę do Godota bierze ze zmiennej `GODOT_BIN`.
- Na słabszym komputerze: `--arenas 4` albo `--speedup 4` (trening potrwa dłużej).
- Wyniki trafiają do `training/runs/<nazwa>/`: modele po każdym etapie, checkpointy co 100 tys. kroków, logi.
  Końcowy model jest zapisywany jako `godot/models/rl_brain.onnx`.
- Przerwany trening wznawia się od checkpointu: `--resume training\runs\<nazwa>\checkpoints\<plik>.zip`.
- Przebieg treningu: `.\venv\Scripts\tensorboard --logdir training\runs`, potem http://localhost:6006.
  Logi z treningów z projektu są w `results/rigid_v3_9M_tb.zip` i `results/rigid_v3_ext_15M_tb.zip`.

## 9. macOS i Linux

Projekt testowaliśmy tylko na Windows 11, ale umieszczamy tutaj tez instrukcje, które powinny zadziałać na macOS i Linux. Kod gry, trening i analiza nie zależą od systemu, a Godot .NET,
.NET SDK 8, OnnxRuntime i biblioteki Pythona są dostępne także na macOS i Linuksie, więc projekt powinien działać
również tam. Skrypty `demo.ps1` i `odtworz_wyniki.ps1` są pisane dla PowerShella na Windows, dlatego na macOS
i Linuksie polecenia wpisuje się ręcznie w terminalu (bash albo zsh), jak niżej.

**Instalacja**

1. Godot 4.7.2 .NET ze strony https://godotengine.org/download/archive/ (wersja „.NET”):
   - macOS: `Godot_v4.7.2-stable_mono_macos.universal.zip` (działa na procesorach Intel i Apple M).
     Rozpakuj i przenieś `Godot_mono.app` do `Applications`. Przy pierwszym uruchomieniu macOS może
     zablokować aplikację z nieznanego źródła: otwórz ją prawym przyciskiem myszy i wybierz „Otwórz”.
   - Linux: `Godot_v4.7.2-stable_mono_linux_x86_64.zip`. Rozpakuj, np. do `~/Godot/`.
2. .NET SDK 8.0 ze strony https://dotnet.microsoft.com/download/dotnet/8.0 (na Linuksie także z menedżera
   pakietów dystrybucji, np. `sudo apt install dotnet-sdk-8.0`).
3. Python 3.12 (tylko do treningu i wykresów): na macOS np. ze strony https://www.python.org/downloads/,
   na Linuksie z menedżera pakietów.

**Ścieżka do Godota** (w tym samym oknie terminala, w katalogu `kod/`):

```
# macOS
export GODOT_BIN=/Applications/Godot_mono.app/Contents/MacOS/Godot
# Linux (nazwa pliku zależy od rozpakowanego archiwum)
export GODOT_BIN=~/Godot/Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v4.7.2-stable_mono_linux.x86_64
```

**Przygotowanie projektu (raz)**

```
dotnet build godot/ArenaDuel.csproj
"$GODOT_BIN" --headless --path godot --import
```

**Demo z grafiką**

```
"$GODOT_BIN" --path godot -- --brain-a=rl --brain-b=fuzzy --seed=41
```

**Seria meczów bez grafiki i testy**

```
"$GODOT_BIN" --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --seed=41 --quiet=1 --csv=results/rl_vs_fuzzy.csv
"$GODOT_BIN" --headless --path godot --script res://tests/test_fuzzy.gd
```

Argumenty po `--` są takie same jak w punkcie 4.

**Środowisko Pythona**

```
python3.12 -m venv venv
venv/bin/pip install -r requirements.txt
```

**Odtworzenie wyników z prezentacji** (zamiast `odtworz_wyniki.ps1`; serie meczów idą po kolei, a nie
równolegle, więc trwa to dłużej niż na Windows):

```
mkdir -p results/odtworzone
for opp in random scripted fuzzy; do
  "$GODOT_BIN" --headless --fixed-fps 60 --path godot -- --matches=100 --brain-a=rl --brain-b=$opp --seed=41 --quiet=1 --rl-model=res://models/rl_brain.onnx --csv=results/odtworzone/eval_rigid_v3_15M_100x3.csv
  "$GODOT_BIN" --headless --fixed-fps 60 --path godot -- --matches=100 --brain-a=rl --brain-b=$opp --seed=41 --quiet=1 --rl-model=res://models/rl_brain_9M.onnx --csv=results/odtworzone/eval_rigid_v3_9M_100x3.csv
done
for pair in fuzzy:scripted fuzzy:random scripted:random; do
  a=${pair%%:*}; b=${pair##*:}
  "$GODOT_BIN" --headless --fixed-fps 60 --path godot -- --matches=100 --brain-a=$a --brain-b=$b --seed=41 --quiet=1 --csv=results/odtworzone/turniej_bez_rl_100.csv
done
venv/bin/python analysis/wykresy.py --eval-dir results/odtworzone --out results/odtworzone
```

**Wykresy z dołączonych wyników**

```
venv/bin/python analysis/wykresy.py
```

**Trening** (skrypt sam uruchamia Godota ze zmiennej `GODOT_BIN`):

```
venv/bin/python training/train_rl.py --etapy random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
venv/bin/python training/train_rl.py --resume training/models/rl_brain_9M_sb3.zip --etapy scripted+fuzzy:6000000 --arenas 8 --seed 7 --run rigid_v3_ext
```
