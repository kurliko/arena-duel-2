# szuka folderu z kodem i godota (mozna ustawic $env:GODOT_BIN)
$KodDir = Join-Path $PSScriptRoot "..\kod"
if (-not (Test-Path (Join-Path $KodDir "godot\project.godot"))) {
    $KodDir = Join-Path $PSScriptRoot ".."
}
$KodDir = (Resolve-Path $KodDir).Path

$DomyslnyGodot = "C:\Tools\Godot\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
if ($env:GODOT_BIN) { $Godot = $env:GODOT_BIN } else { $Godot = $DomyslnyGodot }
if (-not (Test-Path $Godot)) {
    Write-Error "Nie znaleziono Godota: $Godot. Ustaw ścieżkę do pliku _console.exe: `$env:GODOT_BIN = 'C:\...\Godot_v4.7.2-stable_mono_win64_console.exe'"
    exit 1
}
