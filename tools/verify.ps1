$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Path 'artifacts' -Force | Out-Null
    $suites = @('progress', 'gameplay', 'controls', 'stealth', 'save_store', 'chapter_rules', 'platform', 'character_rig', 'expansion', 'routes', 'campaign', 'campaign_ui', 'respawn', 'crouch_states', 'keeper_navigation', 'input_devices', 'controller_ui', 'arrow_movement')
    $results = @()
    foreach ($suite in $suites) {
        $logPath = Join-Path $projectRoot "artifacts/verify-$suite.log"
        & godot --headless --path . --fixed-fps 60 --log-file $logPath --script "tests/test_$suite.gd"
        if ($LASTEXITCODE -ne 0) { throw "Suite failed: $suite (exit $LASTEXITCODE)" }
        $content = Get-Content -LiteralPath $logPath -Raw -Encoding UTF8
        if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|^FAIL:') { throw "Engine/test error in $logPath" }
        $results += [PSCustomObject]@{suite=$suite; passed=$true; checks=([regex]::Matches($content, '(?m)^PASS:')).Count}
    }
    $results | ConvertTo-Json | Set-Content -LiteralPath 'artifacts/verification-results.json' -Encoding UTF8
    Write-Output "ALL $($suites.Count) SUITES PASSED"
} finally {
    Pop-Location
}
