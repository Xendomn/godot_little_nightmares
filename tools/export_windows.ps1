# Requires Godot 4.7.2.stable and the configured local Windows release template.
[CmdletBinding()]
param([string]$GodotPath = '')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runId = [guid]::NewGuid().ToString('N')
$logDirectory = Join-Path $projectRoot "artifacts/export-windows-$runId"
$buildDirectory = Join-Path $projectRoot 'build'
$stageDirectory = Join-Path $buildDirectory ".export-windows-$runId"
$lockPath = Join-Path $buildDirectory '.export.lock'
$lock = $null
$exitCode = 1

function Write-Status([string]$Message) {
    Write-Host $Message
    Add-Content -LiteralPath (Join-Path $logDirectory 'console.log') -Value $Message -Encoding UTF8
}

function Invoke-Godot([string[]]$Arguments) {
    # Windows PowerShell treats native stderr as ErrorRecords. Collect both streams
    # without letting benign stderr bypass our explicit exit/log checks.
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $global:LASTEXITCODE = 0
        $lines = @(& $script:engine @Arguments 2>&1)
        $nativeExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    $content = ($lines | ForEach-Object { $_.ToString() }) -join "`n"
    if ($content) { Write-Status $content }
    if ($nativeExit -ne 0) { throw "Godot exited with code $nativeExit" }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|^FAIL:') { throw 'Godot reported an error in console output' }
    return $content
}

function Invoke-Stage([string]$Name, [string[]]$Arguments) {
    Write-Status "Stage: $Name"
    $engineLog = Join-Path $logDirectory "$Name-engine.log"
    Invoke-Godot (@('--headless', '--path', $projectRoot, '--log-file', $engineLog) + $Arguments) | Out-Null
    if (-not (Test-Path -LiteralPath $engineLog -PathType Leaf)) { throw "Missing Godot log: $engineLog" }
    $content = [IO.File]::ReadAllText($engineLog)
    if ([string]::IsNullOrWhiteSpace($content)) { throw "Empty Godot log: $engineLog" }
    Add-Content -LiteralPath (Join-Path $logDirectory 'engine.log') -Value "Stage: $Name`n$content" -Encoding UTF8
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|^FAIL:') { throw "Godot reported an error in $engineLog" }
}

function Assert-WindowsExport([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing exported executable: $Path" }
    $stream = [IO.File]::OpenRead($Path)
    $reader = New-Object IO.BinaryReader($stream)
    try {
        if ($stream.Length -lt 80 -or $reader.ReadUInt16() -ne 0x5a4d) { throw 'Export is not a PE executable' }
        $stream.Position = 60
        $peOffset = $reader.ReadUInt32()
        if ($peOffset -gt $stream.Length - 6) { throw 'Invalid PE header offset' }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664) { throw 'Export is not a Windows AMD64 PE executable' }
        $stream.Position = $stream.Length - 12
        $packSize = $reader.ReadUInt64()
        if ($reader.ReadUInt32() -ne 0x43504447 -or $packSize -eq 0 -or $packSize -gt $stream.Length - 12) { throw 'Export has no valid nonempty embedded Godot pack' }
    } finally { $reader.Dispose(); $stream.Dispose() }
}

try {
    [IO.Directory]::CreateDirectory($logDirectory) | Out-Null
    [IO.File]::WriteAllText((Join-Path $logDirectory 'console.log'), '')
    [IO.File]::WriteAllText((Join-Path $logDirectory 'engine.log'), '')
    Write-Status "Logs: $logDirectory"
    Write-Status 'Stage: preflight'
    if (-not $GodotPath) { $GodotPath = $env:GODOT }
    if (-not $GodotPath) { $GodotPath = 'godot' }
    $command = Get-Command -Name $GodotPath -CommandType Application,ExternalScript -ErrorAction Stop | Select-Object -First 1
    $script:engine = $command.Source
    $version = Invoke-Godot @('--version')
    if ($version.Trim() -notmatch '^4\.7\.2\.stable(?:\.|$)') { throw "Godot 4.7.2.stable is required; found: $version" }
    $required = @('project.godot', 'export_presets.cfg', 'build/export_templates/templates/windows_release_x86_64.exe', 'README.md', 'docs/production/expansion-assets.md', 'assets/fonts/OFL.txt', 'assets/audio/expansion/LICENSE.txt')
    foreach ($relative in $required) {
        $path = Join-Path $projectRoot $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "Missing or empty prerequisite: $path" }
    }
    $presets = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg'))
    if ($presets -notmatch '(?m)^name="Windows Desktop"\s*$' -or $presets -notmatch '(?m)^custom_template/release="res://build/export_templates/templates/windows_release_x86_64.exe"\s*$') { throw 'The configured Windows Desktop preset/local release template is missing' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
    try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
    catch { throw "Cannot acquire export lock: $lockPath. Another export may be running. An abandoned lock must be removed manually after checking no exporter is running." }
    [IO.Directory]::CreateDirectory($stageDirectory) | Out-Null
    Invoke-Stage 'import' @('--editor', '--import', '--quit')
    $packageDirectory = Join-Path $stageDirectory 'package'
    [IO.Directory]::CreateDirectory($packageDirectory) | Out-Null
    $stagedExe = Join-Path $packageDirectory 'MidnightWorkshop.exe'
    Invoke-Stage 'export' @('--export-release', 'Windows Desktop', $stagedExe)
    Write-Status 'Stage: validate and package'
    Assert-WindowsExport $stagedExe
    $documents = @{
        'README.md' = 'README.md'
        'ASSETS.md' = 'docs/production/expansion-assets.md'
        'NotoSansSC-OFL.txt' = 'assets/fonts/OFL.txt'
        'CC0-LICENSE.txt' = 'assets/audio/expansion/LICENSE.txt'
    }
    foreach ($name in $documents.Keys) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $documents[$name]) -Destination (Join-Path $packageDirectory $name)
    }
    $stagedZip = Join-Path $stageDirectory 'MidnightWorkshop-Windows.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($packageDirectory, $stagedZip)
    $archive = [IO.Compression.ZipFile]::OpenRead($stagedZip)
    try {
        if ($archive.Entries.Count -ne 5) { throw 'ZIP has unexpected entries' }
        foreach ($name in @('MidnightWorkshop.exe') + @($documents.Keys)) {
            $entry = $archive.GetEntry($name)
            if ($null -eq $entry -or $entry.Length -eq 0) { throw "ZIP entry missing or empty: $name" }
            $inputStream = $entry.Open()
            try {
                if ($entry.Length -ne (Get-Item -LiteralPath (Join-Path $packageDirectory $name)).Length) { throw "ZIP entry length mismatch: $name" }
                if ($name -eq 'MidnightWorkshop.exe') {
                    $hash = [Security.Cryptography.SHA256]::Create()
                    $sourceStream = [IO.File]::OpenRead($stagedExe)
                    try {
                        $packedHash = [Convert]::ToBase64String($hash.ComputeHash($inputStream))
                        $sourceHash = [Convert]::ToBase64String($hash.ComputeHash($sourceStream))
                        if ($packedHash -ne $sourceHash) { throw 'Packaged executable differs from validated export' }
                    } finally { $sourceStream.Dispose(); $hash.Dispose() }
                } else { $inputStream.CopyTo([IO.Stream]::Null) }
            } finally { $inputStream.Dispose() }
        }
    } finally { $archive.Dispose() }
    Write-Status 'Stage: publish'
    $publications = @(
        @{ Source = $stagedExe; Target = (Join-Path $buildDirectory 'MidnightWorkshop.exe'); Backup = (Join-Path $stageDirectory 'previous.exe'); Saved = $false; Published = $false },
        @{ Source = $stagedZip; Target = (Join-Path $buildDirectory 'MidnightWorkshop-Windows.zip'); Backup = (Join-Path $stageDirectory 'previous.zip'); Saved = $false; Published = $false }
    )
    try {
        foreach ($item in $publications) {
            if (Test-Path -LiteralPath $item.Target) {
                if (-not (Test-Path -LiteralPath $item.Target -PathType Leaf)) { throw "Output path is not a file: $($item.Target)" }
                [IO.File]::Move($item.Target, $item.Backup)
                $item.Saved = $true
            }
            [IO.File]::Move($item.Source, $item.Target)
            $item.Published = $true
        }
    } catch {
        $publicationError = $_.Exception.Message
        $rollbackErrors = @()
        foreach ($item in $publications) {
            try {
                if ($item.Published) { [IO.File]::Delete($item.Target) }
                if ($item.Saved) { [IO.File]::Move($item.Backup, $item.Target) }
            } catch { $rollbackErrors += "$($item.Target): $($_.Exception.Message)" }
        }
        if ($rollbackErrors.Count -gt 0) { throw "Publication failed: $publicationError. Rollback needs recovery from $stageDirectory : $($rollbackErrors -join '; ')" }
        throw $publicationError
    }
    foreach ($item in $publications) { Write-Status "Created: $($item.Target)" }
    $exitCode = 0
} catch {
    $message = "FAIL: $($_.Exception.Message)"
    if (Test-Path -LiteralPath $logDirectory) { Write-Status $message } else { Write-Output $message }
} finally {
    # Retain backups if rollback itself failed, so recovery data is never deleted.
    if (Test-Path -LiteralPath $stageDirectory) {
        $hasBackup = (Test-Path -LiteralPath (Join-Path $stageDirectory 'previous.exe')) -or (Test-Path -LiteralPath (Join-Path $stageDirectory 'previous.zip'))
        if ($exitCode -eq 0 -or -not $hasBackup) { Remove-Item -LiteralPath $stageDirectory -Recurse -Force -ErrorAction SilentlyContinue }
        else { Write-Output "Recovery files retained: $stageDirectory" }
    }
    if ($null -ne $lock) { $lock.Dispose(); Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
exit $exitCode
