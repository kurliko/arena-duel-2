class_name RewardConfig
extends Resource
## Wagi funkcji nagrody bota RL. Wersja 2: do nagród za wynik i trafienia dochodzi kształtowanie nagrody
## (sygnał za kroki pośrednie), bo w wersji 1 trafienia były zbyt rzadkie, żeby bot nauczył się celować.
## Wersja 3 (fizyka ciał sztywnych): nagroda za zadane obrażenia zamiast stałej za trafienie, bo obrażenia
## zależą od energii pocisku; nagroda za apteczkę.

@export_group("Events")
## Za każdy punkt obrażeń zadanych przeciwnikowi (trafienie z prędkością wylotową = 20 HP = +1).
@export var damage_dealt_per_hp: float = 0.05
## Za każdy punkt utraconego HP (trafienie 20 HP = -1).
@export var damage_taken_per_hp: float = -0.05
## Dodatkowo za trafienie samego siebie rykoszetem.
@export var self_hit: float = -0.5
## Za każdy oddany strzał (oszczędzanie amunicji).
@export var shot: float = -0.03
## Za strzał na ślepo: przeciwnik niewidoczny albo błąd celowania większy niż aimed_shot_tolerance_deg.
@export var blind_shot: float = -0.15
## Za strzał przy dobrym celowaniu na widocznego przeciwnika (zachęta do strzelania, gdy ma to sens).
@export var aimed_shot: float = 0.05
@export var aimed_shot_tolerance_deg: float = 8.0
## Za podniesienie pakietu amunicji, gdy bot miał jej mało (ammo_low_fraction) albo dużo.
@export var pickup_when_low: float = 1.0
@export var pickup: float = 0.1
@export var ammo_low_fraction: float = 0.2
## Za podniesienie apteczki przy HP nie większym niż hp_low_fraction (przy większym).
@export var medkit_when_low: float = 0.5
@export var medkit: float = 0.0
@export var hp_low_fraction: float = 0.5
## Za każdy zryw (unik nie jest darmowy).
@export var dash: float = -0.02
## Dodatkowo za zryw bez groźnego pocisku (zagrożenie z Behaviors.max_projectile_threat poniżej progu):
## żaden pocisk nie leci albo leci daleko lub obok.
@export var unnecessary_dash: float = -0.1
@export var dash_threat_threshold: float = 0.15

@export_group("Shaping")
## Za każdą decyzję (żeby bot nie czekał w rogu).
@export var time_step: float = -0.002
## Za każdą decyzję z bronią skierowaną na widocznego przeciwnika (błąd mniejszy niż aim_tolerance_deg).
@export var aim_on_target: float = 0.002
@export var aim_tolerance_deg: float = 10.0
## Za zmniejszenie błędu celowania na widocznego przeciwnika między decyzjami (za radian).
@export var aim_improvement_per_rad: float = 0.1
## Za zbliżenie się do pakietu amunicji, gdy bot ma jej mało (za piksel).
@export var ammo_approach_per_px: float = 0.001

@export_group("Episode end")
@export var win: float = 5.0
@export var loss: float = -5.0
@export var draw: float = -1.0
