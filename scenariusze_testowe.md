# Przykładowe scenariusze testowe

Każdy scenariusz uruchamia się z katalogu `kod/` (w repozytorium: z katalogu głównego). `GODOT` to ścieżka do
`Godot_v4.7.2-stable_mono_win64_console.exe`. Żaden scenariusz nie wymaga treningu: bot RL używa gotowego modelu
`godot/models/rl_brain.onnx`. Ten sam seed daje zawsze te same mecze.

| Nr | Scenariusz | Polecenie (argumenty po `--`) | Oczekiwany wynik |
|---|---|---|---|
| 1 | Demo z grafiką: RL kontra rozmyty | `& GODOT --path godot -- --brain-a=rl --brain-b=fuzzy --seed=41` | okno gry, HUD z HP, amunicją i decyzjami bota rozmytego |
| 2 | Rozmyty kontra skryptowy | `& GODOT --path godot -- --brain-a=fuzzy --brain-b=scripted` | mecz dwóch botów projektowanych ręcznie |
| 3 | Bez rykoszetów | `... -- --brain-a=rl --brain-b=fuzzy --config=res://data/configs/no_ricochet.tres` | pociski znikają na pierwszej ścianie |
| 4 | Seria 20 meczów bez grafiki z CSV | `& GODOT --headless --fixed-fps 60 --path godot -- --matches=20 --brain-a=rl --brain-b=fuzzy --seed=41 --quiet=1 --csv=results/test.csv` | plik `results/test.csv`, jeden wiersz na mecz |
| 5 | Model po 9 mln kroków | `... -- --brain-a=rl --brain-b=fuzzy --rl-model=res://models/rl_brain_9M.onnx` | słabszy bot RL (22% wygranych z rozmytym zamiast 39%) |
| 6 | Polityka deterministyczna | `... -- --brain-a=rl --brain-b=scripted --rl-deterministic=1` | bot RL zawsze wybiera najbardziej prawdopodobną akcję |
| 7 | Testy silnika rozmytego | `& GODOT --headless --path godot --script res://tests/test_fuzzy.gd` | kod wyjścia 0 = wszystkie testy przeszły |
| 8 | Odtworzenie ewaluacji | `.\uruchomienie\odtworz_wyniki.ps1` (w archiwum: `..\uruchomienie\odtworz_wyniki.ps1`) | `results/odtworzone/` z tymi samymi tabelami co `results/wykresy/` |

Dane wejściowe gry (kopie są w katalogu `dane/` archiwum):

| Plik | Zawartość |
|---|---|
| `godot/data/fuzzy_rules.json` | zmienne, zbiory rozmyte i 36 reguł bota rozmytego |
| `godot/data/configs/default.tres` | parametry gry i fizyki (HP, amunicja, siły, masy, tłumienia, rykoszety) |
| `godot/data/configs/no_ricochet.tres` | te same parametry, ale bez rykoszetów |
| `godot/data/arenas/default_layout.tres` | układ areny: przeszkody, skrzynie, amunicja, apteczki, punkty startu |
| `godot/data/rl/reward_default.tres` | wagi nagród bota RL |
