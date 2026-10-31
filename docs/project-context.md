# Pojedynek na arenie: kontekst projektu (Godot 4)

**Przedmiot:** Sztuczna inteligencja w grach i rozszerzonej rzeczywistości
**Temat:** 1. Pojedynek na arenie: dwa boty, dwie strategie
**Zespół:** Filip Opacki, Zofia Jedlińska, Julia Szymczycha
**Cel:** ocena 5,0, czyli wariant podstawowy plus oba podwyższenia (silnik gry i fizyka). Według prowadzącego fizyka zaimplementowana w silniku gry zalicza oba punkty.

---

## 1. Opis zadania

Na niewielkiej arenie walczą dwa boty. Każdy samodzielnie decyduje, czy zaatakować, wykonać unik, schować się za przeszkodą, czy zebrać amunicję. Celem jest pokonanie przeciwnika przy ograniczonych zasobach (życie, amunicja).

- **Bot A** podejmuje decyzje na podstawie **reguł rozmytych**.
- **Bot B** uczy się strategii przez **uczenie ze wzmocnieniem** (RL).
- Decyzje jednego bota **nie mogą być sterowane przez algorytm przeciwnika**. Każdy bot działa wyłącznie na podstawie własnych obserwacji.

Projekt jest symulacją bot kontra bot. Sterowanie przez gracza nie jest wymagane.

### Wymagania wynikające z oceniania

- Działający projekt z **uzasadnionym** zastosowaniem metod SI.
- Fizyka musi być **poprawna, odpowiednio rozbudowana i istotnie wpływać na rozgrywkę oraz działanie algorytmów**. Pojedyncza kolizja albo gotowa scena z samouczka nie wystarczą.
- Integracja z silnikiem obejmuje **działającą rozgrywkę, interakcję i prezentację rezultatów** w grze.
- Eksperymenty mierzą to, czego wymaga temat: **odsetek zwycięstw, zużycie amunicji, otrzymane obrażenia, skuteczność przeciw różnym przeciwnikom**.
- Użyte biblioteki i gotowe rozwiązania są opisane, a **własny wkład zespołu jest wyraźnie oddzielony** od tego, co daje silnik i narzędzia.

---

## 2. Technologie

| Obszar | Wybór |
|---|---|
| Silnik gry | **Godot 4.x** (konkretna wersja ustalona na starcie i zapisana w README) |
| Język gry | **GDScript** ze statycznym typowaniem |
| Widok | **2D z góry** (top-down) |
| Fizyka | wbudowany silnik fizyki 2D Godota |
| RL: most gra ↔ Python | **Godot RL Agents** (plugin `godot_rl_agents` + pakiet Pythona `godot-rl`) |
| RL: algorytm | **PPO** ze **Stable-Baselines3** |
| Logika rozmyta | **własny silnik** w GDScript, reguły w zewnętrznym pliku |
| Analiza wyników | Python (pandas, matplotlib) |
| Repozytorium | git, dostępne dla prowadzącego |

Uzasadnienie wyboru Godota: pełny silnik gry z wbudowaną fizyką 2D, edytorem scen i trybem bez grafiki (`--headless`). Sceny (`.tscn`) i skrypty są plikami tekstowymi, więc cały projekt da się wersjonować w gicie i edytować narzędziami do kodu. Godot RL Agents łączy grę z ekosystemem RL w Pythonie.

---

## 3. Architektura: wspólne „ciało”, wymienny „mózg”

Najważniejsza decyzja projektowa: **oba boty to ta sama postać** z tym samym życiem, prędkością, bronią i fizyką. Różnią się wyłącznie modułem decyzyjnym („mózgiem”).

```
         obserwacje                 akcja
Arena ──────────────► Mózg (Brain) ─────────► Ciało (Fighter) ──► fizyka Godota
  ▲                                                                     │
  └─────────────────────────── nowy stan świata ◄───────────────────────┘
```

- **`Fighter`** (`CharacterBody2D`) to ciało: ruch z bezwładnością, strzał, życie, amunicja, zbieranie pakietów. Nie podejmuje decyzji.
- **`Brain`** to wspólny interfejs mózgu: dostaje `Observation`, zwraca `Action`.
  - `FuzzyBrain`: reguły rozmyte.
  - `RLBrain`: polityka RL (trening i inferencja przez Godot RL Agents).
  - `RandomBrain`: losowe akcje, przeciwnik referencyjny.
  - `ScriptedBrain`: prosta maszyna stanów (FSM), przeciwnik referencyjny i treningowy.
- **`Observation`** jest budowana przez grę **z perspektywy danego bota**: tylko to, co ten bot może wiedzieć. Żaden mózg nie ma dostępu do stanu ani decyzji drugiego mózgu.
- **Decyzje zapadają co stałą liczbę kroków fizyki** (np. co 4 ticki przy 60 Hz), jednakowo dla obu botów.

Dzięki temu porównanie strategii jest uczciwe, a wymóg niezależności decyzji spełniony z konstrukcji.

### Przestrzeń akcji (wspólna dla wszystkich mózgów)

- **Ruch**: kierunek (8 kierunków + stop) albo wektor ciągły. Postać przyspiesza w tym kierunku, nie teleportuje się.
- **Obrót / celowanie**: kąt lub zmiana kąta.
- **Strzał**: tak/nie (z cooldownem broni).
- **Unik**: krótki zryw prędkości w bok (z cooldownem).

Akcje wysokiego poziomu bota rozmytego („atakuj”, „chowaj się”, „idź po amunicję”, „unikaj”) są tłumaczone na powyższe akcje bazowe przez wspólny moduł nawigacji i celowania, więc oba boty fizycznie robią to samo.

---

## 4. Gra i arena

- Prostokątna arena 2D ze **ścianami** (granice) i kilkoma **przeszkodami** (osłony).
- **Punkty z amunicją** odnawiające się po czasie.
- Dwie postacie startujące w symetrycznych pozycjach (losowanie stron, opcjonalnie losowy układ przeszkód z puli).
- **Koniec meczu**: śmierć jednego bota albo limit czasu (wtedy remis albo wygrana według HP).
- Wszystkie parametry (HP, obrażenia, prędkości, cooldowny, liczba odbić, czas odnowienia amunicji) trzymane w **jednym pliku konfiguracyjnym** (`Resource` `.tres` lub JSON), żeby łatwo przeprowadzać eksperymenty.
- **Ziarno losowości** (seed) ustawiane na starcie meczu, żeby wyniki były odtwarzalne.

---

## 5. Fizyka i jej wpływ na rozgrywkę

Fizyka pochodzi z silnika Godota, ale jest zaprojektowana tak, żeby **realnie zmieniała przebieg walki i decyzje obu botów**, a nie była tylko dodatkiem graficznym.

### 5.1. Prędkość i czas lotu pocisków

- Pociski to obiekty fizyczne z **określoną prędkością**, a nie natychmiastowe trafienia (hitscan).
- Konsekwencje dla rozgrywki: pocisk można zobaczyć i **uniknąć**, a żeby trafić ruchomy cel, trzeba **celować z wyprzedzeniem** w miejsce, w którym przeciwnik dopiero będzie.
- Implementacja: pocisk jako `CharacterBody2D` lub `RigidBody2D`, ruch w `_physics_process`, **ciągłe wykrywanie kolizji (CCD)**, żeby szybki pocisk nie „przeskakiwał” cienkich ścian.

### 5.2. Rykoszety

- Pociski **odbijają się od ścian i przeszkód** zgodnie z prawem odbicia (`velocity.bounce(normal)`), z **utratą części prędkości** przy każdym odbiciu i **limitem odbić**.
- Konsekwencje: można trafić przeciwnika **zza osłony**, ale można też **oberwać własnym pociskiem**. Osłona nie daje pełnego bezpieczeństwa, a strzelanie w ścianę z bliska jest ryzykowne.

### 5.3. Bezwładność ruchu

- Postać ma **przyspieszenie, prędkość maksymalną i tarcie/hamowanie**. Nie zmienia kierunku natychmiast.
- Unik to krótki impuls prędkości, po którym postać wytraca pęd.
- Konsekwencje: **unik trzeba zacząć odpowiednio wcześnie**, szybki ruch utrudnia precyzyjne celowanie, a przewidywanie pozycji przeciwnika ma sens.

### 5.4. Przeszkody blokujące ostrzał i widoczność

- Kolizje z przeszkodami blokują pociski (albo powodują rykoszet) i ruch.
- **Linia wzroku** liczona raycastem (`RayCast2D` / `PhysicsDirectSpaceState2D.intersect_ray`): bot widzi przeciwnika tylko wtedy, gdy nic ich nie zasłania.

### 5.5. Jak fizyka trafia do botów

- **Bot rozmyty** ma reguły uwzględniające fizykę: czas dolotu pocisku zależny od odległości, prędkość przeciwnika, nadlatujący pocisk, możliwość strzału z rykoszetu.
- **Bot RL** dostaje w obserwacjach własną prędkość, prędkość przeciwnika i pozycje/prędkości najbliższych pocisków, więc musi **nauczyć się** unikania i celowania z wyprzedzeniem.
- **Eksperymenty fizyczne**: zmiana prędkości pocisków, liczby odbić i bezwładności i pomiar wpływu na skuteczność i zachowanie botów (szczegóły w sekcji 9).

### 5.6. Stabilność symulacji

- **Stały krok fizyki** (np. 60 Hz). Przyspieszenie treningu uzyskujemy przez wielokrotność kroków na klatkę i tryb bez grafiki, **nie** przez zwiększanie kroku czasu, bo to psuje kolizje i rykoszety.

---

## 6. Bot rozmyty (`FuzzyBrain`)

**Własna implementacja** systemu wnioskowania rozmytego w GDScript (typu Mamdaniego albo uproszczony wariant oparty na „opłacalności” akcji). To jeden z głównych elementów własnego wkładu zespołu.

### Elementy silnika

1. **Fuzzyfikacja**: funkcje przynależności (trójkątne i trapezowe) dla każdego wejścia.
2. **Baza reguł** wczytywana z pliku (JSON lub `Resource`), żeby stroić reguły bez zmian w kodzie.
3. **Wnioskowanie**: AND = min, OR = max, agregacja wyników reguł.
4. **Defuzzyfikacja** (np. metoda środka ciężkości) do wartości opłacalności każdej akcji wysokiego poziomu.
5. **Wybór akcji** o najwyższej opłacalności i przekazanie jej do modułu nawigacji/celowania.

### Wejścia (propozycja)

- odległość do przeciwnika: *blisko / średnio / daleko*
- własne HP: *mało / średnio / dużo*
- amunicja: *brak / mało / dużo*
- widoczność przeciwnika: *widoczny / niewidoczny*
- zagrożenie pociskiem (odległość i czas do zderzenia z najbliższym nadlatującym pociskiem): *niskie / średnie / wysokie*
- prędkość przeciwnika: *wolno / szybko*

### Wyjścia

Opłacalność akcji w skali 0–1: **atak**, **unik**, **osłona**, **zbieranie amunicji**.

### Przykładowe reguły

- JEŚLI HP *mało* I przeciwnik *blisko* TO osłona *wysoko*
- JEŚLI amunicja *brak* TO zbieranie amunicji *wysoko*
- JEŚLI HP *dużo* I amunicja *dużo* I przeciwnik *widoczny* TO atak *wysoko*
- JEŚLI zagrożenie pociskiem *wysokie* TO unik *wysoko*
- JEŚLI przeciwnik *daleko* I prędkość przeciwnika *szybko* TO atak *nisko* (pocisk nie doleci na czas)

Baza obejmuje kilkanaście do dwudziestu kilku sensownych reguł, a nie wszystkie kombinacje. Reguły są strojone na podstawie obserwacji meczów.

**Inspiracja i bibliografia:** M. Buckland, *Programming Game AI by Example*, rozdział o logice rozmytej (wybór broni przez bota w strzelance); prace o logice rozmytej w botach do gier FPS.

**Rozszerzenie opcjonalne:** automatyczne strojenie parametrów funkcji przynależności algorytmem genetycznym (fitness = odsetek zwycięstw w serii meczów) i porównanie z wersją strojoną ręcznie.

---

## 7. Bot RL (`RLBrain`)

### Narzędzia

- **Godot RL Agents**: w scenie Godota węzeł `AIController2D` przypięty do postaci oraz węzeł synchronizacji łączący grę z procesem Pythona.
- W `AIController2D` implementujemy: `get_obs()`, `get_reward()`, `get_action_space()`, `set_action()` oraz obsługę końca epizodu i resetu.
- Trening w Pythonie: **Stable-Baselines3, algorytm PPO**.

### Obserwacje (znormalizowane do zakresu ok. −1…1)

- własna pozycja, prędkość, kierunek celowania, HP, amunicja, cooldowny broni i uniku
- względna pozycja i prędkość przeciwnika (lub wartości „nieznane”, gdy go nie widać), HP przeciwnika, jeśli jest widoczne
- względne pozycje i prędkości **k najbliższych pocisków**
- **raycasty** w kilku kierunkach (odległość do ścian i przeszkód)
- kierunek i odległość do najbliższego pakietu amunicji

### Akcje

Ta sama przestrzeń akcji co w sekcji 3 (ruch, celowanie, strzał, unik).

### Nagrody (punkt startowy, do strojenia)

- **+** za trafienie przeciwnika, **duży +** za wygraną
- **−** za otrzymane obrażenia, **duży −** za przegraną
- **małe −** za każdy strzał (oszczędzanie amunicji) i za upływ czasu (żeby bot nie „czekał w rogu”)
- **małe +** za podniesienie amunicji, gdy jej brakuje
- **−** za trafienie samego siebie rykoszetem

### Trening

- **Wiele aren równolegle** w jednej scenie (np. 8–16 kopii) plus kilka instancji gry, sterowane parametrami Godot RL Agents (m.in. przyspieszenie symulacji i liczba równoległych środowisk).
- Trening na **wyeksportowanej grze w trybie bez grafiki** (`--headless`), a w edytorze tylko do podglądu.
- **Curriculum**: najpierw przeciwnik losowy, potem skryptowy (FSM), następnie bot rozmyty, na końcu **self-play** z zamrożonymi wcześniejszymi wersjami polityki.
- Logowanie przebiegu treningu (TensorBoard: średnia nagroda, długość epizodu, odsetek zwycięstw).
- Zapis checkpointów i **eksport wytrenowanej polityki do ONNX**.

### Inferencja w grze

- Docelowo wytrenowany model ONNX jest uruchamiany **w samej grze** (wsparcie inferencji ONNX w Godot RL Agents; **do zweryfikowania na starcie**: wymagania co do wersji Godota, m.in. możliwa konieczność użycia wersji .NET).
- Plan awaryjny: mecze z botem RL rozgrywane z polityką uruchomioną w procesie Pythona połączonym z grą (tak jak w treningu, ale bez uczenia).

---

## 8. Przeciwnicy referencyjni

- **`RandomBrain`**: losowe akcje, dolna granica skuteczności.
- **`ScriptedBrain`**: prosta maszyna stanów (atak / ucieczka / amunicja), „klasyczne” AI z gier jako punkt odniesienia.

Służą zarówno jako przeciwnicy w turnieju, jak i jako etapy curriculum dla bota RL.

---

## 9. Eksperymenty i ocena wyników

### Tryb wsadowy (batch)

- Gra uruchamiana z linii poleceń (`--headless`) rozgrywa **N meczów** dla zadanej pary mózgów, konfiguracji fizyki i ziarna losowości.
- Każdy mecz zapisuje wiersz do **CSV**: zwycięzca, czas meczu, oddane strzały, trafienia, zużyta amunicja, otrzymane obrażenia, trafienia z rykoszetu, samotrafienia, liczba uników, podniesione pakiety amunicji.

### Turniej

Każdy z każdym: **Rozmyty, RL, Skryptowy, Losowy**, po kilkaset meczów na parę, ze zmianą stron areny.

### Metryki (zgodnie z tematem)

- **odsetek zwycięstw** (z przedziałami ufności)
- **zużycie amunicji** i **celność** (trafienia / strzały)
- **otrzymane obrażenia**
- **skuteczność przeciw różnym przeciwnikom** (macierz wyników turnieju)

### Eksperymenty z fizyką

Ten sam turniej przy zmienionych parametrach, np.:
- wolne vs szybkie pociski,
- rykoszety wyłączone / 1 odbicie / 3 odbicia,
- mała vs duża bezwładność.

Pytania badawcze: jak parametry fizyki zmieniają przewagę jednej strategii nad drugą? Czy bot RL wytrenowany przy jednych parametrach radzi sobie przy innych? Które reguły bota rozmytego zależą od fizyki?

### Analiza

Skrypty w Pythonie (pandas + matplotlib) generują wykresy i tabele do sprawozdania: macierz zwycięstw, rozkłady obrażeń i zużycia amunicji, krzywe uczenia RL, wpływ parametrów fizyki.

---

## 10. Prezentacja rezultatów w grze

- **Tryb widza**: kamera nad całą areną, możliwość pauzy i spowolnienia.
- **HUD**: HP, amunicja, nazwy mózgów, licznik zwycięstw w serii.
- **Wizualizacja „myślenia” botów** (przełączana klawiszem):
  - bot rozmyty: wartości wejść, aktywne reguły i opłacalność każdej akcji nad postacią,
  - bot RL: wybrana akcja i opcjonalnie rozkład prawdopodobieństw akcji,
  - linie wzroku, raycasty, przewidywane trajektorie pocisków z odbiciami.
- **Menu meczu**: wybór pary mózgów i konfiguracji fizyki przed startem.

---

## 11. Struktura repozytorium (propozycja)

```
arena-duel/
├── godot/                      # projekt Godota
│   ├── project.godot
│   ├── addons/godot_rl_agents/ # plugin (zewnętrzny, opisany w README)
│   ├── scenes/                 # arena, fighter, projectile, hud, training_arena
│   ├── scripts/
│   │   ├── core/               # Fighter, Projectile, Arena, MatchManager, Config
│   │   ├── brains/             # Brain (interfejs), FuzzyBrain, RLBrain, ScriptedBrain, RandomBrain
│   │   ├── fuzzy/              # własny silnik rozmyty
│   │   ├── navigation/         # tłumaczenie akcji wysokiego poziomu na ruch i celowanie
│   │   └── stats/              # zbieranie statystyk, zapis CSV
│   ├── data/
│   │   ├── fuzzy_rules.json
│   │   └── configs/            # zestawy parametrów fizyki i gry
│   └── models/                 # wytrenowane polityki (.onnx)
├── training/                   # Python: trening PPO, konfiguracje, eksport ONNX
├── analysis/                   # Python: analiza CSV, wykresy
├── results/                    # surowe wyniki eksperymentów
├── docs/                       # sprawozdanie, rysunki
└── README.md                   # instrukcja uruchomienia od zera
```

---

## 12. Konwencje implementacyjne

- GDScript ze **statycznym typowaniem**, jedna klasa na plik, `class_name` dla klas wielokrotnego użytku.
- Logika gry w `_physics_process` (stały krok), nie w `_process`.
- **Żadnych „magicznych liczb”**: wszystkie parametry w konfiguracji.
- Mózgi nie odwołują się bezpośrednio do węzłów sceny. Dostają tylko `Observation` i zwracają `Action`.
- Gra musi działać identycznie w edytorze, w trybie `--headless` i w trybie treningu.
- Każdy mecz ma ustawiony seed, a wyniki są odtwarzalne.
- Zależności Pythona przypięte w `requirements.txt` (lub `pyproject.toml`), wersja Godota i pluginu zapisana w README.

---

## 13. Etapy realizacji

Zgodnie z harmonogramem zajęć (konsultacje 28.10 i 9.11, oddanie 16.11, termin rezerwowy 23.11), tak żeby na każdych konsultacjach było coś do pokazania:

1. **Arena z fizyką**: postacie z bezwładnością, pociski z czasem lotu i rykoszetami, przeszkody, linia wzroku. Szybki test Godot RL Agents (połączenie gry z Pythonem, inferencja ONNX).
2. **Pełny mecz** dwóch prostych botów (losowy, skryptowy), interfejs `Brain`, tryb wsadowy i zapis CSV.
3. **Bot rozmyty**: silnik, baza reguł, strojenie.
4. **Bot RL**: środowisko, nagrody, curriculum, trening, eksport modelu.
5. **Eksperymenty**: turniej, eksperymenty z fizyką, wykresy.
6. **Prezentacja i sprawozdanie**: HUD, wizualizacja „myślenia”, dokument.

---

## 14. Materiały do oddania

- **Sprawozdanie (5–10 stron)**: opis zadania, cel i założenia; metody i architektura; sposób przeprowadzenia eksperymentów; wyniki z interpretacją; wnioski, ograniczenia i kierunki rozwoju. Bez całego kodu, tylko architektura i wybrane, interesujące fragmenty.
- **Kod źródłowy lub link do repozytorium** dostępnego dla prowadzącego.
- **Instrukcja uruchomienia od zera**: wersja Godota, instalacja pluginu i zależności Pythona, uruchomienie meczu, treningu, turnieju i analizy.
- **Wytrenowany model** i konfiguracje pozwalające odtworzyć wyniki.
- Imiona i nazwiska wykonawców w sprawozdaniu i opisie repozytorium.
- **Wyraźne oddzielenie** tego, co daje silnik Godot, Godot RL Agents i Stable-Baselines3, od własnego wkładu: silnik rozmyty i reguły, model gry i fizyki, funkcja nagrody i curriculum, tryb wsadowy, eksperymenty, wizualizacje.
- Prezentacja działającego rozwiązania: demonstracja, architektura, metody, wyniki i wnioski. Każdy członek zespołu omawia swój wkład.

---

## 15. Ryzyka i kwestie do sprawdzenia na starcie

- **Inferencja ONNX w Godot RL Agents**: sprawdzić wymagania co do wersji Godota (.NET) i działanie z naszą wersją. Plan awaryjny: inferencja przez proces Pythona.
- **Trening w trybie `--headless`** z wieloma instancjami: sprawdzić, czy działa stabilnie i jak szybko.
- **Funkcja nagrody**: pierwsza wersja prawie na pewno da niepożądane zachowania (stanie w rogu, ciągłe strzelanie). Trening uruchomić jak najwcześniej, żeby zostawić czas na kilka iteracji.
- **Stabilność fizyki** przy szybkich pociskach: CCD, stały krok, testy rykoszetów.
- **Zgoda prowadzącego**: koncepcja przedstawiona 26.10 zakładała Unreal Engine 5, więc zmianę na Godota trzeba zgłosić na konsultacjach.
