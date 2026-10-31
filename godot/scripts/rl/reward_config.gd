class_name RewardConfig
extends Resource
## Wagi funkcji nagrody bota RL (punkt startowy z kontekstu projektu, do strojenia).

@export_group("Events")
## Za każde trafienie przeciwnika.
@export var hit: float = 1.0
## Za każdy punkt utraconego HP (trafienie 20 HP = -1).
@export var damage_taken_per_hp: float = -0.05
## Dodatkowo za trafienie samego siebie rykoszetem.
@export var self_hit: float = -0.5
## Za każdy oddany strzał (oszczędzanie amunicji).
@export var shot: float = -0.03
## Za podniesienie pakietu amunicji.
@export var pickup: float = 0.2

@export_group("Shaping")
## Za każdą decyzję (żeby bot nie czekał w rogu).
@export var time_step: float = -0.002
## Za każdą decyzję z bronią skierowaną na widocznego przeciwnika (błąd mniejszy niż aim_tolerance_deg).
@export var aim_on_target: float = 0.002
@export var aim_tolerance_deg: float = 10.0

@export_group("Episode end")
@export var win: float = 5.0
@export var loss: float = -5.0
@export var draw: float = -1.0
