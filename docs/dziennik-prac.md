# Dziennik prac i decyzje projektowe

Materiał roboczy do sprawozdania. Wpisy chronologiczne, a pod nimi opis decyzji projektowych
i rozwiązań SI zastosowanych w Godocie, z uzasadnieniem.

Autor wpisów: Filip Opacki (na razie całość prac wykonuje jedna osoba).

---

## 1. Dziennik prac

### 26.10.2026

- Analiza kontekstu projektu i planu działania. Wybór Godota 4 w miejsce Unreal Engine 5 z przedstawionej
  koncepcji (powód: wbudowana fizyka 2D, tryb `--headless` do treningu i eksperymentów, sceny i skrypty jako
  pliki tekstowe w gicie, gotowy most do RL w Pythonie przez Godot RL Agents).
- Instalacja środowiska: Godot 4.7.2 w buildzie .NET, .NET SDK 8.0.427, Python 3.12.10.
- Inicjalizacja repozytorium.

### 31.10.2026

- **Szkielet repozytorium** zgodny ze strukturą z kontekstu projektu, `project.godot` ze stałym krokiem fizyki 60 Hz,
  README, `.gitignore`, `.gitattributes`.
- **Kontrakty** wspólne dla wszystkich botów: `Brain`, `Observation`, `Action`, `GameConfig` oraz pierwszy mózg `RandomBrain`.
- **Integracja Godot RL Agents i smoke test** całego łańcucha RL:
  - plugin `godot_rl_agents` (commit `998c357`) w `addons/`, projekt C# `ArenaDuel.csproj` z pakietem
    `Microsoft.ML.OnnxRuntime` 1.20.1 (inferencja ONNX w pluginie jest napisana w C#),
  - środowisko Pythona: `godot-rl` 0.8.2, `stable-baselines3` 2.4.0, PyTorch 2.15,
  - scena testowa: agent uczy się dochodzić do celu przy dyskretnych akcjach (9 kierunków ruchu + strzał),
  - wynik: trening PPO 20 tys. kroków (średnia nagroda w epizodzie 0,8 → 4,6), eksport do ONNX, inferencja
    w Godocie bez Pythona (7 dojść do celu w 50 s gry).
- **Rdzeń gry**: arena ze ścianami i przeszkodami, postać `Fighter` z bezwładnością, unikiem i strzałem,
  pociski z czasem lotu i rykoszetami, odnawiające się pakiety amunicji, linia wzroku przez raycast,
  `Perception` (budowa obserwacji), `MatchManager` (przebieg meczów, seria ze zmianą stron), HUD,
  `ScriptedBrain` (maszyna stanów), tryb wsadowy z linii poleceń.
- Weryfikacja: skryptowy kontra losowy 6:0; skryptowy kontra skryptowy 4:4 w 8 meczach, w meczach występują
  trafienia z rykoszetu, trafienia własnym pociskiem, uniki i zbieranie amunicji; dwa przebiegi z tym samym
  ziarnem dają identyczne wyniki.

---

## 2. Architektura: wspólne ciało, wymienny mózg

Oba boty to ta sama postać (`Fighter`): to samo życie, prędkość, broń i fizyka. Różnią się tylko modułem
decyzyjnym (`Brain`). Mózg dostaje wyłącznie obiekt `Observation` i zwraca `Action`. Nie ma dostępu do węzłów
sceny ani do stanu i decyzji przeciwnika.

```
MatchManager ── co N ticków ──► Perception.build(bot, ...) ──► Observation ──► Brain.decide() ──► Action
                                                                                                    │
Fighter (CharacterBody2D) ◄────────────── apply_action() ◄───────────────────────────────────────────┘
   └─► ruch z bezwładnością, obrót, strzał, unik ──► fizyka 2D Godota ──► nowy stan świata
```

Uzasadnienie:
- **uczciwe porównanie strategii**: różnice w wynikach wynikają z decyzji, a nie z parametrów postaci,
- **wymóg niezależności decyzji spełniony z konstrukcji**: żaden mózg nie ma dostępu do drugiego,
- **wymienność**: ten sam mecz, tryb wsadowy i turniej działają dla każdej pary mózgów (`BrainFactory`).

## 3. Decyzje dotyczące SI w Godocie

### 3.1. Wspólna, dyskretna przestrzeń akcji

`Action` ma cztery pola dyskretne: ruch (stop + 8 kierunków), obrót (brak, lewo, prawo, precyzyjnie lewo,
precyzyjnie prawo), strzał (tak/nie), unik (tak/nie).

- Akcja jest dyskretna, bo ta sama przestrzeń musi pasować do bota RL. Wrapper Stable-Baselines3 w Godot RL Agents
  obsługuje akcje dyskretne (MultiDiscrete) albo ciągłe, a mieszanie typów jest kłopotliwe. Smoke test potwierdził,
  że akcje wielodyskretne przechodzą przez cały łańcuch, łącznie z inferencją ONNX w grze.
- **Obrót precyzyjny** dodaliśmy po analizie: przy prędkości obrotu 240°/s i decyzji co 4 ticki zwykły obrót zmienia
  celowanie o 16° na decyzję. Na dystansie 350 px oznacza to błąd rzędu 100 px przy promieniu postaci 16 px, czyli
  celne strzały byłyby niemożliwe. Obrót precyzyjny (25% prędkości) daje krok 4°.
- Akcje „wysokiego poziomu” botów skryptowego i rozmytego („atakuj”, „idź po amunicję”) są tłumaczone na akcje
  bazowe przez wspólny moduł `Steering`, więc wszystkie boty fizycznie sterują postacią tak samo.

### 3.2. Decyzje co stałą liczbę ticków fizyki

Mózgi decydują co `decision_interval_ticks` = 4 ticki (15 decyzji na sekundę), jednakowo dla obu botów, a postać
między decyzjami wykonuje ostatnią akcję. `MatchManager` ma ujemny `process_physics_priority`, więc w każdym ticku
decyzje zapadają przed ruchem postaci i pocisków. Kolejność przetwarzania jest stała.

### 3.3. Percepcja ograniczona do tego, co bot widzi

`Perception.build()` tworzy obserwację z perspektywy jednego bota:
- **linia wzroku przez raycast** (`PhysicsDirectSpaceState2D.intersect_ray` na warstwie ścian): przeciwnik
  i pociski są widoczne tylko wtedy, gdy nic ich nie zasłania; inaczej pola przeciwnika są „nieznane”,
- **raycasty w 8 kierunkach** zgodnych z kierunkami ruchu: odległości do ścian i przeszkód,
- **k najbliższych widocznych pocisków** (pozycja i prędkość względna), także własnych, bo rykoszet może trafić strzelca,
- wartości znormalizowane do zakresu około -1..1 (gotowe jako wejście sieci RL).

Przeszkody pełnią więc dwie funkcje: zatrzymują pociski i ruch oraz ograniczają informację, którą bot ma
do podjęcia decyzji.

### 3.4. Bot skryptowy (FSM) jako punkt odniesienia

`ScriptedBrain` to klasyczna maszyna stanów z gier:
- **ATAK**: celowanie z wyprzedzeniem (pozycja przeciwnika po czasie lotu pocisku = odległość / prędkość pocisku),
  strzał przy błędzie celowania poniżej 4°, utrzymywanie dystansu około 350 px i krążenie wokół przeciwnika,
- **AMUNICJA**: przy braku amunicji idź do najbliższego dostępnego pakietu,
- **SZUKANIE**: idź do ostatniej znanej pozycji przeciwnika, a bez niej w losowym kierunku z wolną przestrzenią,
- **unik** niezależnie od stanu: dla każdego nadlatującego pocisku liczony jest moment największego zbliżenia
  (`t = -r·v / |v|²`). Jeśli pocisk minie bota bliżej niż 2,5 promienia w ciągu 0,5 s, bot robi zryw prostopadle do toru pocisku.

Bot pełni trzy role: przeciwnik referencyjny w turnieju, etap curriculum dla bota RL i test, czy obserwacje
zawierają wystarczająco informacji do sensownej gry.

### 3.5. Wnioski z testów: symetria areny a deterministyczne boty

Pierwsza wersja bota skryptowego w trybie szukania szła w kierunku najdłuższego promienia. W meczu dwóch
takich botów **żaden nie oddał strzału przez 6 meczów**. Arena jest środkowo-symetryczna, boty startują
w symetrycznych punktach, a obaj byli deterministyczni, więc poruszali się jak lustrzane odbicia. Odcinek
łączący dwa punkty symetryczne względem środka zawsze przechodzi przez środek areny, gdzie stoi przeszkoda,
więc boty nigdy się nie widziały.

Rozwiązanie: losowy wybór kierunku szukania z generatora z ziarnem przydzielanym każdemu mózgowi osobno.
Po zmianie mecze są wyrównane (4:4), a wyniki dalej w pełni powtarzalne. Wniosek do sprawozdania: symetria
areny zapewnia równe szanse, ale przy deterministycznych przeciwnikach potrzebny jest mechanizm łamania
symetrii, a percepcja oparta na linii wzroku silnie wpływa na zachowanie botów.

### 3.6. Powtarzalność wyników

Każdy mecz ma ziarno `rng_seed + numer meczu`. Ziarno ustawia globalny generator i generatory obu mózgów
(różne ziarna dla A i B). Strony areny zmieniają się co mecz. Dwa przebiegi serii z tym samym ziarnem dają
identyczne wyniki (sprawdzone porównaniem skrótów wyjścia).

## 4. Fizyka i jej wpływ na rozgrywkę (implementacja w Godocie)

| Element | Implementacja | Wpływ na grę i boty |
|---|---|---|
| Bezwładność | `CharacterBody2D`, prędkość zmieniana przez `move_toward` z przyspieszeniem i tarciem | zmiana kierunku trwa, unik trzeba zacząć wcześniej, ruch przeciwnika da się przewidzieć |
| Unik | impuls prędkości (480 px/s) z czasem odnowienia, potem wytracanie pędu | reakcja na pocisk ma sens tylko z wyprzedzeniem |
| Czas lotu pocisku | pocisk jako ciało z prędkością 500 px/s, ruch w `_physics_process` | celowanie z wyprzedzeniem, możliwość uniku |
| Brak „przeskakiwania” ścian | `move_and_collide` rzutuje kształt pocisku na cały odcinek ruchu w ticku (ciągłe wykrywanie kolizji) | stabilne rykoszety przy dużych prędkościach |
| Rykoszety | `velocity.bounce(normal)` × 0,8, limit odbić, kilka odbić w jednym ticku (rogi) | trafienia zza osłony; po pierwszym odbiciu pocisk może trafić strzelca |
| Własne pociski | wyjątek kolizji ze strzelcem zdejmowany po pierwszym odbiciu | strzelanie w ścianę z bliska jest ryzykowne |
| Linia wzroku | raycast na warstwie ścian | przeszkody ograniczają informację botów |
| Stały krok | 60 Hz; przyspieszenie treningu przez więcej ticków na sekundę, nie przez dłuższy krok | stabilne kolizje i odbicia |

Warstwy kolizji: ściany, postacie, pociski, pakiety. Pociski nie zderzają się ze sobą, a postacie przechodzą przez pociski
(trafienie wykrywa pocisk).

## 5. Integracja RL (Godot RL Agents)

- Most Godot ↔ Python: węzeł `Sync` (plugin) łączy się po TCP z procesem Pythona, a węzeł `AIController2D`
  udostępnia `get_obs()`, `get_reward()`, `get_action_space()` i `set_action()`.
- Trening: PPO ze Stable-Baselines3 w Pythonie; gra przyspieszona argumentem `--speedup` w trybie `--headless`.
- Inferencja w grze: wytrenowana polityka eksportowana do ONNX i uruchamiana w Godocie przez OnnxRuntime (C#),
  dlatego potrzebny jest build Godota .NET; kod gry pozostaje w GDScript.

Problemy napotkane w smoke teście i rozwiązania:
1. **Eksport ONNX w nowym PyTorchu** wymaga pakietu `onnxscript` (doinstalowany).
2. Nowy eksporter **zapisuje wagi do osobnego pliku** `.onnx.data`, a plugin wczytuje model z bufora bajtów,
   więc wagi nie były widoczne. Rozwiązanie: po eksporcie scalamy model do jednego pliku (`onnx.save(..., save_as_external_data=False)`).
3. Komunikaty eksportera zawierają emoji, których nie obsługuje konsola Windows (cp1250). Skrypt ustawia
   kodowanie UTF-8 dla wyjścia.
4. Krótko trenowana polityka w **inferencji deterministycznej** (zawsze akcja o najwyższym prawdopodobieństwie)
   oscylowała tuż obok celu. Inferencja stochastyczna, czyli losowanie z rozkładu jak podczas treningu, działała
   poprawnie. Wniosek dla właściwego bota RL: porównać oba tryby w eksperymentach.

## 6. Własny wkład a gotowe narzędzia

| Gotowe (opisujemy, nie przypisujemy sobie) | Własne |
|---|---|
| Godot 4.7.2: silnik, fizyka 2D, raycasty, edytor | model gry: arena, postać, bezwładność, unik, pociski z rykoszetami, amunicja |
| Godot RL Agents: węzły `Sync`, `AIController2D`, inferencja ONNX | architektura ciało/mózg, kontrakty `Brain`/`Observation`/`Action`, percepcja z linią wzroku |
| Stable-Baselines3: algorytm PPO | `ScriptedBrain` (FSM, celowanie z wyprzedzeniem, unik), moduł `Steering` |
| PyTorch, ONNX, OnnxRuntime | tryb wsadowy, statystyki meczów, powtarzalność przez ziarna |
| | (w planach) silnik rozmyty i reguły, funkcja nagrody i curriculum RL, eksperymenty, wizualizacje |

## 7. Do zrobienia (stan na 31.10.2026)

- zapis wyników meczów do CSV w trybie wsadowym,
- silnik logiki rozmytej i `FuzzyBrain`,
- środowisko RL na właściwej arenie (obserwacje, nagrody, curriculum) i trening,
- turniej, eksperymenty z parametrami fizyki, wykresy,
- wizualizacja „myślenia” botów, menu meczu, sprawozdanie.
