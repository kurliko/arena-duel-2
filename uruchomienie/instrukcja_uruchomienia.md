# Arena Duel: instrukcja uruchomienia

Projekt nr 1, temat „Pojedynek na arenie: dwa boty, dwie strategie”.
Zespół: Filip Opacki, Zofia Jedlińska, Julia Szymczycha.

Instrukcja dotyczy systemu Windows i PowerShella. Polecenia wpisuj w katalogu `kod/` z archiwum
(w repozytorium: w katalogu głównym repozytorium), chyba że napisano inaczej.

## 1. Instalacja

1. **Godot 4.7.2 .NET** (Windows 64-bit) ze strony https://godotengine.org/download/archive/
   (wersja „.NET”, nie „Standard”). Rozpakuj archiwum, np. do `C:\Tools\Godot\`.
   W środku są dwa pliki: `Godot_v4.7.2-stable_mono_win64.exe` (edytor) i
   `Godot_v4.7.2-stable_mono_win64_console.exe` (to samo z konsolą; tego używamy w poleceniach).
2. **.NET SDK 8.0** ze strony https://dotnet.microsoft.com/download/dotnet/8.0.
3. **Python 3.12** ze strony https://www.python.org/downloads/ (zaznacz „Add python.exe to PATH”).
   Python jest potrzebny tylko do treningu, wykresów i pakowania. Demo działa bez niego.

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
w `docs/scenariusze_testowe.md` (w archiwum też w `dane/scenariusze_testowe.md`).

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

Wyniki ewaluacji (modele po 9 i 15 mln kroków, po 100 meczów z każdym przeciwnikiem, ziarno 41) odtwarza skrypt:

```
powershell -ExecutionPolicy Bypass -File ..\uruchomienie\odtworz_wyniki.ps1
```

Skrypt uruchamia 6 serii meczów równolegle (ok. 15–30 minut), zapisuje CSV w `results/odtworzone/` i rysuje
wykresy i tabele (wymaga środowiska Pythona z punktu 7). Te same ziarna dają te same mecze, więc tabela
`results/odtworzone/tabela_ewaluacji.csv` powinna być identyczna z `results/wykresy/tabela_ewaluacji.csv`.

Same wykresy z dołączonych wyników:

```
.\venv\Scripts\python analysis\wykresy.py
```

Tworzy w `results/wykresy/`: krzywą uczenia (`krzywa_uczenia.png`), porównanie modeli (`wygrane_rl_9M_15M.png`)
i tabelę ewaluacji (`tabela_ewaluacji.csv`, `.md`).

## 7. Środowisko Pythona

```
python -m venv venv
.\venv\Scripts\pip install -r requirements.txt
```

## 8. Trening bota RL (opcjonalnie)

Trening nie jest potrzebny do demo ani do odtworzenia wyników, bo wytrenowane modele są dołączone. Pełny trening
z projektu trwał ok. 6,5 h na laptopie z 16 wątkami CPU.

Etap 1: curriculum, 9 mln kroków (przeciwnik losowy, skryptowy, rozmyty, po 3 mln):

```
.\venv\Scripts\python training\train_rl.py --curriculum random:3000000,scripted:3000000,fuzzy:3000000 --arenas 8 --run rigid_v3
```

Etap 2: dotrenowanie o 6 mln kroków z przeciwnikami mieszanymi na arenach (połowa skryptowy, połowa rozmyty):

```
.\venv\Scripts\python training\train_rl.py --resume training\runs\rigid_v3\stage2_fuzzy.zip --curriculum scripted+fuzzy:6000000 --arenas 8 --seed 7 --run rigid_v3_ext
```

Zamiast własnego etapu 1 można dotrenowywać dołączony model: `--resume training\models\rl_brain_9M_sb3.zip`.

- Skrypt sam uruchamia grę w trybie bez grafiki. Ścieżkę do Godota bierze ze zmiennej `GODOT_BIN`.
- Na słabszym komputerze: `--arenas 4` albo `--speedup 4` (trening potrwa dłużej).
- Wyniki trafiają do `training/runs/<nazwa>/`: modele po każdym etapie, checkpointy co 100 tys. kroków, logi.
  Końcowy model jest zapisywany jako `godot/models/rl_brain.onnx`.
- Przerwany trening wznawia się od checkpointu: `--resume training\runs\<nazwa>\checkpoints\<plik>.zip`.
- Przebieg treningu: `.\venv\Scripts\tensorboard --logdir training\runs`, potem http://localhost:6006.
  Logi z treningów z projektu są w `results/rigid_v3_9M_tb.zip` i `results/rigid_v3_ext_15M_tb.zip`.

## 9. Pakowanie archiwum do oddania

Z katalogu głównego repozytorium (wymaga Pythona i Gita):

```
.\venv\Scripts\python uruchomienie\pakuj_oddanie.py --zespol 3 --dzien pon --godzina 8 --prezentacja C:\sciezka\prezentacja.pdf --sprawozdanie C:\sciezka\sprawozdanie.pdf
```

Skrypt tworzy `projekt_<zespół>_<dzień>_<godzina>.zip` z jednym katalogiem głównym o tej samej nazwie i
podkatalogami `kod/`, `dane/`, `modele/`, `wyniki/`, `uruchomienie/`. Do `kod/WERSJA.txt` wpisuje adres
repozytorium i numer commita.

## 10. Najczęstsze problemy

| Objaw | Rozwiązanie |
|---|---|
| „running scripts is disabled on this system” | uruchamiaj skrypty przez `powershell -ExecutionPolicy Bypass -File ...` |
| bot RL stoi w miejscu albo błąd ładowania ONNX | brakuje `dotnet build godot\ArenaDuel.csproj` albo użyto Godota bez .NET |
| błąd instalacji `numpy` | użyj Pythona 3.12, nie 3.13 |
| skrypt nie znajduje Godota | ustaw `$env:GODOT_BIN` na pełną ścieżkę do `_console.exe` |
