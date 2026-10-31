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

- **Zapis wyników do CSV** w trybie wsadowym (`--csv=...`): jeden wiersz na mecz z wynikiem, statystykami obu
  botów i parametrami fizyki, dopisywanie kolejnych serii do jednego pliku. Druga konfiguracja `no_ricochet.tres`
  (bez rykoszetów) jako pierwszy wariant do eksperymentów z fizyką. Poprawka kolejności argumentów
  (`--config` przed `--seed`) i dokładności limitu czasu meczu.

- **Silnik logiki rozmytej i bot rozmyty** (`FuzzyBrain`):
  - własny silnik Mamdaniego w GDScript (zbiory trójkątne i trapezowe, reguły tekstowe z AND/OR/NOT i wagami,
    implikacja min, agregacja max, defuzzyfikacja środkiem ciężkości), 32 testy jednostkowe,
  - baza 24 reguł w `data/fuzzy_rules.json` (8 wejść, 4 wyjścia),
  - wspólny moduł zachowań `Behaviors` wydzielony z bota skryptowego (refaktoryzacja zweryfikowana: identyczne
    wyniki serii kontrolnej przed i po zmianie), nowe zachowania: osłona i unik bez zrywu,
  - percepcja rozszerzona o punkt osłony za przeszkodą,
  - HUD pokazuje bieżące zachowanie botów i opłacalności akcji bota rozmytego.
- Wyniki (20 meczów, seed 1): rozmyty kontra losowy 20:0; rozmyty kontra skryptowy: wersja 1 reguł 3:12
  (5 remisów), po strojeniu 8:10 (2 remisy).

- **Środowisko RL i trening bota RL**:
  - `RLController` (rozszerzenie `AIController2D` z Godot RL Agents), `RLBrain`, koder obserwacji (47 wartości),
    funkcja nagrody z wagami w zasobie `RewardConfig`,
  - `ArenaSync`: węzeł Sync pluginu wywoływany w tickach decyzji gry (bot RL decyduje razem z pozostałymi mózgami),
  - scena treningowa z wieloma arenami w jednej instancji gry, skrypt `training/train_rl.py` z curriculum
    (losowy → skryptowy → rozmyty), logami TensorBoard, checkpointami i eksportem ONNX po każdym etapie,
  - inferencja ONNX w meczu: mózg `rl` dostępny w grze i w trybie wsadowym bez Pythona,
  - wydajność: 8 aren, przyspieszenie 8×, około 860 kroków decyzji na sekundę (1,6 mln kroków w około 35 min).

- **Pierwszy trening RL** (`curriculum_v1`: losowy 400 tys., skryptowy 600 tys., rozmyty 600 tys. kroków, 8 aren,
  około 35 min): średnia nagroda w etapie z losowym wzrosła z −3,3 do −2,4, ale odsetek zwycięstw był 0 we wszystkich
  etapach. Analiza nieudanej wersji nagród opisana w sekcji 3.7.

- **Nagrody RL v2 (kształtowanie nagrody)** i poprawka błędu kolejności akcji przy inferencji ONNX (sekcja 3.7).
  Test 400 tys. kroków z losowym przeciwnikiem: średnia nagroda w epizodzie z −4,8 do +0,6; w meczach testowych
  bot RL zbiera amunicję, trafia i wygrywa z losowym 4:2; ze skryptowym przegrywa 0:6 (nie trenował jeszcze z nim).

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

### 3.6. Bot rozmyty

**Silnik** (`scripts/fuzzy/`, własna implementacja):
1. *Fuzzyfikacja*: każda zmienna wejściowa ma zakres i nazwane zbiory z funkcją przynależności trapezową
   (trójkąt jako szczególny przypadek, ramiona na krańcach zakresu). Wartość spoza zakresu jest obcinana.
2. *Reguły* zapisane tekstem: `IF hp IS low AND visible IS yes THEN cover IS high`. Parser obsługuje AND, OR,
   NOT i wagi reguł oraz sprawdza, czy zmienne i zbiory istnieją.
3. *Wnioskowanie*: siła reguły to min (AND) albo max (OR) stopni przynależności. Zbiór wyjściowy jest obcinany
   do siły reguły (implikacja min), a reguły prowadzące do tego samego zbioru łączy max.
4. *Defuzzyfikacja* metodą środka ciężkości: zakres wyjścia próbkowany w 101 punktach.
5. *Wybór akcji*: zachowanie o największej opłacalności, z premią 0,05 dla zachowania z poprzedniej decyzji
   (histereza ogranicza przeskakiwanie przy zbliżonych ocenach).

**Wejścia** (liczone z `Observation`): odległość do przeciwnika, własne HP, amunicja, widoczność przeciwnika,
zagrożenie pociskiem, prędkość przeciwnika, HP przeciwnika, odległość do pakietu amunicji.
Zagrożenie pociskiem to wielkość fizyczna: dla każdego nadlatującego pocisku liczymy czas do największego
zbliżenia i odległość minięcia, a zagrożenie = (1 − t/1 s) · (1 − odległość/(4 · promień)), obcięte do 0..1.

**Wyjścia**: opłacalność (0..1) czterech zachowań: atak, unik, osłona, zbieranie amunicji.

**Reguły związane z fizyką**, np.:
- `IF visible IS yes AND distance IS far AND opponent_speed IS fast THEN attack IS low`: pocisk leci długo,
  a szybki przeciwnik zdąży zmienić tor (czas lotu i bezwładność),
- `IF threat IS medium AND distance IS near THEN dodge IS high`: z bliska jest mniej czasu na reakcję,
- `IF threat IS high THEN attack IS low`: nadlatujący pocisk obniża opłacalność ataku.

**Wspólne zachowania.** Bot skryptowy i rozmyty korzystają z tego samego modułu `Behaviors` (celowanie
z wyprzedzeniem, utrzymywanie dystansu, szukanie, osłona, unik). Różnią się wyłącznie sposobem wyboru
zachowania: maszyna stanów z ostrymi progami kontra wnioskowanie rozmyte. Porównanie w turnieju mierzy więc
metodę decyzyjną, a nie jakość niskopoziomowego sterowania. Przed wydzieleniem modułu zapisaliśmy wyniki serii
kontrolnej (skryptowy kontra skryptowy, 8 meczów, seed 7). Po zmianie wyniki były identyczne.

**Osłona.** Percepcja wylicza punkt osłony: dla każdej przeszkody punkt tuż za nią po stronie przeciwnej do
przeciwnika, wewnątrz areny, poza przeszkodami i niewidoczny dla przeciwnika (raycast). Wybierany jest najbliższy
botowi. Układ przeszkód to wiedza o mapie wspólna dla wszystkich botów.

**Strojenie reguł (przykład).** Wersja 1 bazy przegrywała z botem skryptowym 3:12 (5 remisów). Licznik wyborów
zachowań pokazał, że unik był wybierany rzadko (kilka razy na kilkaset decyzji), a bot rozmyty wykonywał mniej
zrywów niż skryptowy, który robi unik odruchowo w każdym stanie. Przyczyna: przy nadlatującym pocisku atak
nadal miał wysoką opłacalność i wygrywał z unikiem. Dodanie reguł `IF threat IS high THEN attack IS low`
i `IF threat IS high THEN collect IS low` sprawia, że środek ciężkości ataku spada przy zagrożeniu (agregat
„wysoko” i „nisko”) i wygrywa unik. Wynik po zmianie: 8:10 (2 remisy). To pokazuje zaletę bazy reguł
w pliku: zmianę zachowania uzyskaliśmy bez zmian w kodzie.

### 3.7. Bot RL: środowisko uczenia w Godocie

**Przepływ danych w jednej decyzji** (co 4 ticki fizyki, wspólnie dla obu botów):
1. `MatchManager.collect_observations()`: `Perception` buduje `Observation` dla obu botów; `RLBrain.observe()`
   przekazuje ją do `RLController` i dolicza nagrodę za zdarzenia od poprzedniej decyzji.
2. `ArenaSync.step()`: węzeł Sync z Godot RL Agents odczytuje obserwacje (`get_obs`), nagrody i flagi końca epizodu,
   wysyła je do Pythona (trening) albo podaje modelowi ONNX (gra) i ustawia otrzymane akcje (`set_action`).
3. `MatchManager.apply_decisions()`: wszystkie mózgi zwracają akcje, a `RLBrain` zwraca akcję ustawioną w kroku 2.

**Dlaczego własna nakładka na Sync.** Oryginalny węzeł Sync wymienia dane z Pythonem co `action_repeat` ticków
liczonych od startu sceny, niezależnie od tego, kiedy decydują pozostałe mózgi. Bot RL decydowałby wtedy
w innych tickach niż przeciwnik i na podstawie obserwacji spóźnionej o kilka ticków. `ArenaSync` wyłącza własny
licznik Sync i udostępnia `step()`, który gra wywołuje między zebraniem obserwacji a wykonaniem akcji.
Bot RL ma więc tę samą częstotliwość decyzji i to samo opóźnienie (zero) co pozostałe boty: porównanie jest uczciwe.

**Obserwacje** (47 wartości, `ObservationEncoder`): spłaszczona ta sama `Observation`, którą dostają inne mózgi:
własna pozycja, prędkość, kierunek celowania (cos, sin), HP, amunicja, czasy odnowienia; przeciwnik (widoczność,
pozycja i prędkość względna, HP, kąt do przeciwnika względem celowania); 3 najbliższe widoczne pociski (pozycja
i prędkość względna); 8 raycastów; najbliższy pakiet amunicji; punkt osłony. Pola niewidocznych obiektów są zerowane
z flagą obecności, więc bot RL nie dostaje więcej informacji niż bot rozmyty.

**Akcje**: ta sama dyskretna przestrzeń co u innych botów (MultiDiscrete: ruch 9, obrót 5, strzał 2, unik 2).

**Nagroda, wersja 1** (`RewardConfig`, wartości startowe):

| Zdarzenie | Waga |
|---|---|
| trafienie przeciwnika | +1,0 |
| utrata HP | −0,05 za punkt (−1 za trafienie) |
| trafienie samego siebie | −0,5 (dodatkowo do utraty HP) |
| oddany strzał | −0,03 |
| podniesienie amunicji | +0,2 |
| każda decyzja (upływ czasu) | −0,002 |
| broń skierowana na widocznego przeciwnika (błąd < 10°) | +0,002 za decyzję |
| wygrana / przegrana / remis | +5 / −5 / −1 |

Nagroda jest liczona z przyrostów statystyk bota (`FighterStats`) między decyzjami, więc korzysta z tych samych
liczników, które trafiają do CSV. Kara za remis i upływ czasu ma zniechęcać do czekania do końca meczu.

**Epizod = mecz.** Koniec meczu dodaje nagrodę za wynik i ustawia flagę końca epizodu; nowy mecz zaczyna się
w tym samym ticku, więc kolejna obserwacja wysłana do Pythona jest już pierwszą obserwacją nowego epizodu.
Do logów trafia `is_success` (wygrana), z którego Stable-Baselines3 liczy `rollout/success_rate`.

**Trening równoległy.** Scena `training.tscn` tworzy N kopii sceny meczu przesuniętych w przestrzeni (jeden
świat fizyki, areny się nie stykają). Raycasty areny działają we współrzędnych globalnych, a logika gry
w lokalnych. Jeden `ArenaSync` obsługuje wszystkie areny naraz, a Python widzi je jako N równoległych środowisk.
Każda arena ma własne ziarno. Przyspieszenie uzyskujemy argumentem `--speedup` (więcej ticków fizyki na sekundę
czasu rzeczywistego przy stałym kroku 1/60 s), a nie przez wydłużenie kroku fizyki.

**Curriculum**: najpierw przeciwnik losowy (nauka podstaw: celowanie, strzał, ruch), potem skryptowy (przeciwnik
celujący z wyprzedzeniem i robiący uniki), potem rozmyty. Każdy etap uruchamia grę z innym przeciwnikiem
i kontynuuje trening tego samego modelu.

**PPO** (Stable-Baselines3): sieć 2×128, `n_steps` 512 na środowisko, `batch_size` 512, 10 epok, lr 3·10⁻⁴,
γ = 0,99, λ = 0,95, współczynnik entropii 0,01.

**Wyniki pierwszego treningu (wersja 1 nagród) i analiza.** Po 1,6 mln kroków bot RL nie wygrał żadnego meczu
treningowego. Mecze testowe (6 na parę): z losowym 2:3 (1 remis), ze skryptowym 0:6. Statystyki z CSV pokazały,
czego bot się nauczył:
- oddaje dokładnie 5 strzałów, czyli całą amunicję startową, na początku meczu, bez celowania,
- nigdy nie podnosi amunicji, więc przez resztę meczu nie może strzelać,
- robi zryw przy każdej możliwości (39 na mecz, maksimum przy czasie odnowienia 1,5 s), co ogranicza otrzymane trafienia.

Przyczyny: nagroda za trafienie jest rzadka (zdarza się dopiero, gdy bot jednocześnie widzi przeciwnika, wyceluje
i trafi poruszający się cel pociskiem z czasem lotu), więc sygnał uczący do celowania prawie nie występuje. Kara
za strzał (−0,03) jest za mała, żeby zniechęcić do strzałów na ślepo, a pakiety amunicji nie mają nagrody
prowadzącej do nich (+0,2 dopiero po podniesieniu, którego losowa eksploracja prawie nie osiąga). Zrywy nic nie
kosztują, a zmniejszają otrzymane obrażenia, więc polityka szybko się na nich zatrzymała.

Wniosek: przy fizyce z czasem lotu pocisku i ograniczoną amunicją sama nagroda za wynik i trafienia jest za rzadka.
Potrzebne jest kształtowanie nagrody (reward shaping), które daje sygnał za kroki pośrednie: poprawę celowania,
strzały oddane przy dobrym celowaniu, zbliżanie się do amunicji, gdy jej brakuje.

**Wersja 2 nagród (kształtowanie nagrody).** Do nagród z wersji 1 doszły składniki za kroki pośrednie:

| Składnik | Waga | Cel |
|---|---|---|
| strzał na ślepo (przeciwnik niewidoczny albo błąd celowania > 8°) | −0,15 | koniec ze strzelaniem bez celu |
| strzał przy dobrym celowaniu (błąd ≤ 8°) | +0,05 | strzelać wtedy, gdy ma to sens |
| zmniejszenie błędu celowania na widocznego przeciwnika | +0,1 za radian | ciągły sygnał do obracania broni w stronę przeciwnika |
| zbliżenie się do pakietu, gdy amunicji jest mało (≤ 20%) | +0,001 za piksel | droga do amunicji |
| podniesienie pakietu przy małej amunicji (przy dużej) | +1,0 (+0,1) | uzupełnianie amunicji, gdy jest potrzebne |
| zryw | −0,02 | unik nie jest darmowy |

Zdarzenia między decyzjami (np. strzał) są oceniane względem obserwacji z decyzji, która do nich doprowadziła:
strzał oddany po decyzji podjętej, gdy przeciwnik był niewidoczny, jest strzałem na ślepo. Nagroda za poprawę
celowania jest różnicą „potencjału” (błędu celowania) między decyzjami, więc obracanie broni tam i z powrotem
nic nie daje; opłaca się tylko trwałe naprowadzenie na cel.

**Błąd kolejności akcji przy inferencji ONNX.** Po treningu z nagrodami v2 średnia nagroda rosła, ale bot w grze
zachowywał się tak samo jak po wersji 1. Porównanie modelu z Pythona i eksportu ONNX na tych samych danych dało
pełną zgodność (200/200), za to przestrzeń akcji po stronie Pythona miała postać `MultiDiscrete([2 9 2 5])`:
godot-rl sortuje akcje alfabetycznie (`dash, move, shoot, turn`), a węzeł Sync w grze dekodował wyjście ONNX
w kolejności słownika akcji w GDScript (`move, turn, shoot, dash`). W treningu błąd nie występował, bo Python
odsyła akcje z nazwami; dotyczył tylko gry z modelem ONNX. Poprawka: klucze przestrzeni akcji w kolejności
alfabetycznej (z komentarzem w kodzie). Ponowna ocena modelu z wersji 1 po poprawce potwierdziła, że ten model
rzeczywiście nauczył się złej strategii (5 strzałów na start, zryw przy każdej możliwości), więc analiza
nagród v1 była trafna, a błąd kolejności był osobnym problemem.

**Wyniki wersji 2** (400 tys. kroków, tylko przeciwnik losowy): średnia nagroda w epizodzie wzrosła z −4,8 do +0,6.
W meczach testowych bot RL podnosi 2–5 pakietów amunicji na mecz, trafia do 4 razy i wygrywa z losowym 4:2.
Ze skryptowym przegrywa 0:6, czego należy się spodziewać przed etapem curriculum z tym przeciwnikiem.

### 3.8. Zbieranie danych do eksperymentów

Każdy mecz trybu wsadowego zapisuje wiersz CSV z metrykami wymaganymi w temacie (zwycięzca, zużycie amunicji,
celność, otrzymane obrażenia) oraz metrykami związanymi z fizyką (trafienia z rykoszetu, samotrafienia, uniki).
W każdym wierszu zapisujemy też parametry fizyki z konfiguracji, więc wyniki różnych eksperymentów można
połączyć w jednym pliku i grupować w analizie (pandas) bez dodatkowych metadanych.

### 3.9. Powtarzalność wyników

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
| | silnik logiki rozmytej (Mamdani) z parserem reguł i testami, baza reguł, `FuzzyBrain`, wspólny moduł zachowań, punkty osłony |
| | środowisko RL: koder obserwacji, funkcja nagrody, `ArenaSync` (synchronizacja z zegarem decyzji gry), trening równoległy na wielu arenach, curriculum |
| | (w planach) eksperymenty, wizualizacje |

## 7. Do zrobienia (stan na 31.10.2026)

- dalsze strojenie reguł bota rozmytego na podstawie turnieju,
- ocena bota RL, strojenie nagród, ewentualnie self-play,
- turniej, eksperymenty z parametrami fizyki, wykresy,
- wizualizacja „myślenia” botów, menu meczu, sprawozdanie.
