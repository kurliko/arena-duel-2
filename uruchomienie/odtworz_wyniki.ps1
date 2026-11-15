# Odtwarza ewaluację bota RL z prezentacji: modele po 9 i 15 mln kroków, po 100 meczów
# z każdym przeciwnikiem (losowy, skryptowy, rozmyty), ziarno 41. Sześć serii działa równolegle
# w trybie bez grafiki (ok. 15–30 min). Potem rysuje wykresy i tabele.
# Wyniki: results\odtworzone\ (CSV, wykresy, tabele). Te same ziarna dają identyczne mecze,
# więc tabele powinny być takie same jak w results\wykresy\.
param(
    [int]$Matches = 100,
    [int]$Seed = 41
)
. (Join-Path $PSScriptRoot "wspolne.ps1")

$Out = Join-Path $KodDir "results\odtworzone"
New-Item -ItemType Directory -Force $Out | Out-Null
$Models = @{ "15M" = "res://models/rl_brain.onnx"; "9M" = "res://models/rl_brain_9M.onnx" }
$Opponents = @("random", "scripted", "fuzzy")

Push-Location $KodDir
try {
    $procs = @()
    foreach ($tag in $Models.Keys) {
        foreach ($opp in $Opponents) {
            $csv = "results/odtworzone/_${tag}_$opp.csv"
            Remove-Item (Join-Path $KodDir $csv) -ErrorAction SilentlyContinue
            $argList = "--headless --fixed-fps 60 --path godot -- --matches=$Matches --brain-a=rl --brain-b=$opp --seed=$Seed --quiet=1 --rl-model=$($Models[$tag]) --csv=$csv"
            $procs += Start-Process -FilePath $Godot -ArgumentList $argList -NoNewWindow -PassThru `
                -RedirectStandardOutput (Join-Path $Out "_${tag}_$opp.log") -RedirectStandardError (Join-Path $Out "_${tag}_$opp.err")
        }
    }
    Write-Host "Trwa $($procs.Count) serii meczów..."
    $procs | Wait-Process

    # Łączenie serii w jeden plik na model (nazwy jak w results\).
    foreach ($tag in $Models.Keys) {
        $rows = foreach ($opp in $Opponents) { Import-Csv (Join-Path $Out "_${tag}_$opp.csv") }
        $rows | Export-Csv (Join-Path $Out "eval_rigid_v3_${tag}_100x3.csv") -NoTypeInformation -Encoding utf8
    }
    Remove-Item (Join-Path $Out "_*") -ErrorAction SilentlyContinue

    $Python = Join-Path $KodDir "venv\Scripts\python.exe"
    if (-not (Test-Path $Python)) { $Python = "python" }
    & $Python analysis\wykresy.py --eval-dir results/odtworzone --out results/odtworzone
} finally {
    Pop-Location
}
