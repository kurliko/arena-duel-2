# Demo: mecz dwóch botów z grafiką, bez treningu (bot RL używa gotowego modelu ONNX).
# Przykłady:
#   .\uruchomienie\demo.ps1                              # bot RL kontra bot rozmyty
#   .\uruchomienie\demo.ps1 -BrainA fuzzy -BrainB scripted
#   .\uruchomienie\demo.ps1 -Config no_ricochet          # fizyka bez rykoszetów
# Mózgi: rl, fuzzy, scripted, random. Mecze trwają bez końca; zakończ, zamykając okno gry.
param(
    [string]$BrainA = "rl",
    [string]$BrainB = "fuzzy",
    [int]$Seed = 41,
    [string]$Config = "default"
)
. (Join-Path $PSScriptRoot "wspolne.ps1")

Push-Location $KodDir
try {
    & $Godot --path godot -- "--brain-a=$BrainA" "--brain-b=$BrainB" "--seed=$Seed" "--config=res://data/configs/$Config.tres"
} finally {
    Pop-Location
}
