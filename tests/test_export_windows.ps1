# Exercises the real exporter with an external Godot stand-in; no engine/templates needed.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$exporter = Join-Path $repo 'tools/export_windows.ps1'
if (-not (Test-Path -LiteralPath $exporter)) { throw 'FAIL: Windows exporter is missing' }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('windows export ' + [char]0x6E38 + ' ' + [guid]::NewGuid().ToString('N'))
$hostExe = (Get-Process -Id $PID).Path
$oldGodot = $env:GODOT
try {
    foreach ($dir in @('tools','build/export_templates/templates','assets/fonts','assets/audio/expansion','docs/production')) {
        [IO.Directory]::CreateDirectory((Join-Path $fixture $dir)) | Out-Null
    }
    Copy-Item -LiteralPath $exporter -Destination (Join-Path $fixture 'tools/export_windows.ps1')
    Copy-Item -LiteralPath (Join-Path $repo 'export_presets.cfg') -Destination $fixture
    foreach ($file in @('project.godot','README.md','docs/production/expansion-assets.md','assets/fonts/OFL.txt','assets/audio/expansion/LICENSE.txt','build/export_templates/templates/windows_release_x86_64.exe')) {
        [IO.File]::WriteAllText((Join-Path $fixture $file), 'fixture')
    }
    $mock = Join-Path $fixture 'mock godot.ps1'
    @'
$mode = $env:EXPORT_TEST_MODE
if ($args.Count -eq 1 -and $args[0] -eq '--version') {
    if ($mode -eq 'version') { '4.6.stable.mock' } else { '4.7.2.stable.mock' }
    exit 0
}
$logIndex = [Array]::IndexOf($args, '--log-file')
$projectIndex = [Array]::IndexOf($args, '--path')
if ($projectIndex -lt 0 -or $args[$projectIndex + 1] -ne $PSScriptRoot -or $logIndex -lt 0) { exit 91 }
$stage = 'import'
if ($args -contains '--export-release') { $stage = 'export' }
if ($mode -ne "$stage-missing-log") { [IO.File]::WriteAllText($args[$logIndex + 1], 'Godot clean log') }
if ($mode -eq "$stage-error") { [IO.File]::AppendAllText($args[$logIndex + 1], "`nERROR: simulated") }
if ($mode -eq "$stage-stderr") { [Console]::Error.WriteLine('SCRIPT ERROR: simulated') ; Write-Error 'SCRIPT ERROR: simulated' -ErrorAction Continue }
if ($mode -eq "$stage-exit") { exit 9 }
if ($stage -eq 'export' -and $mode -ne 'missing-output') {
    $idx = [Array]::IndexOf($args, '--export-release')
    if ($args[$idx + 1] -ne 'Windows Desktop') { exit 92 }
    $bytes = New-Object byte[] 512
    $bytes[0] = 0x4d; $bytes[1] = 0x5a; $bytes[60] = 128
    $bytes[128] = 0x50; $bytes[129] = 0x45; $bytes[132] = 0x64; $bytes[133] = 0x86
    # Godot embedded pack footer: uint64 pack size followed by GDPC magic.
    $bytes[500] = 100; $bytes[508] = 0x47; $bytes[509] = 0x44; $bytes[510] = 0x50; $bytes[511] = 0x43
    if ($mode -eq 'bad-pe') { $bytes[132] = 0 }
    if ($mode -eq 'missing-pack') { $bytes[508] = 0 }
    [IO.File]::WriteAllBytes($args[$idx + 2], $bytes)
    if ($mode -eq 'zip-failure') { [IO.Directory]::CreateDirectory((Join-Path (Split-Path -Parent (Split-Path -Parent $args[$idx + 2])) 'MidnightWorkshop-Windows.zip')) | Out-Null }
    if ($mode -eq 'package') { Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'README.md') }
}
exit 0
'@ | Set-Content -LiteralPath $mock -Encoding UTF8
    # On Unix use a real native executable boundary, including stderr and exit codes.
    if ($env:OS -ne 'Windows_NT') {
        $mockScript = $mock
        $mock = Join-Path $fixture 'mock godot'
        $quote = "'"
        $quotedHost = $quote + $hostExe.Replace($quote, "'\''") + $quote
        $quotedScript = $quote + $mockScript.Replace($quote, "'\''") + $quote
        [IO.File]::WriteAllText($mock, "#!/bin/sh`nexec $quotedHost -NoProfile -File $quotedScript " + '"$@"' + "`n")
        & chmod +x $mock
        if ($LASTEXITCODE -ne 0) { throw 'Could not make mock executable' }
    }
    function Invoke-Case([string]$Mode, [bool]$Success, [string]$Path = $mock) {
        $env:EXPORT_TEST_MODE = $Mode
        $exe = Join-Path $fixture 'build/MidnightWorkshop.exe'
        $zip = Join-Path $fixture 'build/MidnightWorkshop-Windows.zip'
        [IO.File]::WriteAllText($exe, 'old exe')
        [IO.File]::WriteAllText($zip, 'old zip')
        if ($Mode -eq 'publication') {
            Remove-Item -LiteralPath $zip
            [IO.Directory]::CreateDirectory($zip) | Out-Null
            [IO.File]::WriteAllText((Join-Path $zip 'sentinel'), 'old zip')
        }
        $invokeArgs = @('-NoProfile', '-File', (Join-Path $fixture 'tools/export_windows.ps1'))
        if ($Mode -eq 'success-environment') { $env:GODOT = $mock } else { $invokeArgs += @('-GodotPath', $Path) }
        $output = & $hostExe @invokeArgs 2>&1
        $code = $LASTEXITCODE
        if (($code -eq 0) -ne $Success) { throw "FAIL: $Mode exit $code`n$output" }
        if (-not $Success) {
            $oldZipPath = $zip
            if ($Mode -eq 'publication') { $oldZipPath = Join-Path $zip 'sentinel' }
            if ([IO.File]::ReadAllText($exe) -ne 'old exe' -or [IO.File]::ReadAllText($oldZipPath) -ne 'old zip') { throw "FAIL: $Mode replaced old artifacts" }
        } else {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $archive = [IO.Compression.ZipFile]::OpenRead($zip)
            try {
                $names = @($archive.Entries | ForEach-Object { $_.FullName } | Sort-Object)
                if (($names -join ',') -ne 'ASSETS.md,CC0-LICENSE.txt,MidnightWorkshop.exe,NotoSansSC-OFL.txt,README.md') { throw "FAIL: package entries $names" }
                $entryStream = $archive.GetEntry('MidnightWorkshop.exe').Open()
                $memory = New-Object IO.MemoryStream
                try {
                    $entryStream.CopyTo($memory)
                    if ([Convert]::ToBase64String($memory.ToArray()) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($exe))) { throw 'FAIL: packaged EXE differs from published EXE' }
                } finally { $entryStream.Dispose(); $memory.Dispose() }
                if ((Get-Item -LiteralPath $exe).Length -ne 512) { throw 'FAIL: did not publish exported PE' }
            } finally { $archive.Dispose() }
        }
        if ($Mode -eq 'publication') { Remove-Item -LiteralPath $zip -Recurse -Force }
        Write-Output "PASS: $Mode"
    }
    Push-Location ([IO.Path]::GetTempPath())
    try {
        $env:GODOT = 'does-not-exist'
        Invoke-Case 'missing-godot' $false (Join-Path $fixture 'absent')
        foreach ($mode in @('version','import-exit','export-exit','import-error','export-error','import-stderr','export-stderr','import-missing-log','export-missing-log','missing-output','bad-pe','missing-pack','zip-failure','publication','package')) { Invoke-Case $mode $false }
        [IO.File]::WriteAllText((Join-Path $fixture 'README.md'), 'fixture')
        $template = Join-Path $fixture 'build/export_templates/templates/windows_release_x86_64.exe'
        Remove-Item -LiteralPath $template
        Invoke-Case 'missing-template' $false
        [IO.File]::WriteAllText($template, 'fixture')
        $lock = Join-Path $fixture 'build/.export.lock'
        [IO.File]::WriteAllText($lock, 'another run')
        Invoke-Case 'locked' $false
        if (-not (Test-Path -LiteralPath $lock)) { throw 'FAIL: removed foreign lock' }
        Remove-Item -LiteralPath $lock -Force
        Invoke-Case 'success-explicit-precedence' $true
        Invoke-Case 'success-repeat' $true
        Invoke-Case 'success-environment' $true
    } finally { Pop-Location }
} finally {
    $env:GODOT = $oldGodot
    Remove-Item Env:EXPORT_TEST_MODE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
