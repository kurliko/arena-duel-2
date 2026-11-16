# demo z grafika, np. .\demo.ps1 -BrainA fuzzy -BrainB scripted
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
