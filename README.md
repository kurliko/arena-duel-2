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
| Plugin `godot_rl_agents` | do uzupełnienia po smoke teście |

Kod gry jest w GDScript. Build .NET jest potrzebny tylko do inferencji ONNX w pluginie.

## Uruchomienie

1. Zainstaluj Godota 4.7.2 .NET, .NET SDK 8 i Pythona.
2. Otwórz folder `godot/` w edytorze Godota (pierwsze otwarcie generuje cache `.godot/`).
3. Sprawdzenie bez grafiki:
   ```
   Godot_v4.7.2-stable_mono_win64_console.exe --headless --path godot --quit
   ```

## Struktura

Patrz sekcja 11 w [docs/project-context.md](docs/project-context.md).

## Co jest własnym wkładem, a co gotowym narzędziem

- Gotowe: Godot (silnik i fizyka 2D), Godot RL Agents, Stable-Baselines3.
- Własne: model gry i fizyki, silnik rozmyty i reguły, nagrody i curriculum, tryb wsadowy, eksperymenty, wizualizacje.
