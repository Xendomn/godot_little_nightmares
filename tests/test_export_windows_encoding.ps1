# Native UTF-8 boundary regression; Windows PowerShell 5.1 and PowerShell 7.
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { Write-Output 'SKIP: Windows native encoding regression'; return }
$repo = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('export encoding ' + [char]0x6e38 + ' ' + [guid]::NewGuid().ToString('N'))
$hostExe = (Get-Process -Id $PID).Path
try {
    foreach ($dir in @('tools','build/export_templates/templates','assets/fonts','assets/audio/expansion','docs/production')) {
        [IO.Directory]::CreateDirectory((Join-Path $fixture $dir)) | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $repo 'tools/export_windows.ps1') -Destination (Join-Path $fixture 'tools/export_windows.ps1')
    Copy-Item -LiteralPath (Join-Path $repo 'export_presets.cfg') -Destination $fixture
    foreach ($file in @('project.godot','README.md','docs/production/expansion-assets.md','assets/fonts/OFL.txt','assets/audio/expansion/LICENSE.txt','build/export_templates/templates/windows_release_x86_64.exe')) {
        [IO.File]::WriteAllText((Join-Path $fixture $file), 'fixture')
    }
    $source = @'
using System;
using System.IO;
using System.Text;
class NativeGodot {
    static void Emit(Stream stream, string text) {
        byte[] bytes = new UTF8Encoding(false).GetBytes(text + "\n");
        stream.Write(bytes, 0, bytes.Length); stream.Flush();
    }
    static int Main(string[] args) {
        if (Array.IndexOf(args, "--version") >= 0) { Console.WriteLine("4.7.2.stable.mock"); return 0; }
        string text = "\u9879\u76ee\u521d\u59cb\u5316 \u8def\u5f84: " + AppDomain.CurrentDomain.BaseDirectory;
        Emit(Console.OpenStandardOutput(), "\x1b[32mSTDOUT " + text + "\x1b[0m");
        Emit(Console.OpenStandardError(), "\x1b[33mSTDERR " + text + "\x1b[0m");
        string mode = File.ReadAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "mode.txt"));
        if (mode == "error") Emit(Console.OpenStandardOutput(), "\x1b[31mERROR: " + text + "\x1b[0m");
        if (mode == "exit") return 9;
        File.WriteAllText(args[Array.IndexOf(args, "--log-file") + 1], text, new UTF8Encoding(false));
        int export = Array.IndexOf(args, "--export-release");
        if (export >= 0) {
            byte[] bytes = new byte[512];
            bytes[0]=0x4d; bytes[1]=0x5a; bytes[60]=128;
            bytes[128]=0x50; bytes[129]=0x45; bytes[132]=0x64; bytes[133]=0x86;
            bytes[500]=100; bytes[508]=0x47; bytes[509]=0x44; bytes[510]=0x50; bytes[511]=0x43;
            File.WriteAllBytes(args[export+2], bytes);
        }
        return 0;
    }
}
'@
    $sourcePath = Join-Path $fixture 'native.cs'
    [IO.File]::WriteAllText($sourcePath, $source)
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    & $compiler /nologo /target:exe ("/out:" + (Join-Path $fixture 'native godot.exe')) $sourcePath
    if ($LASTEXITCODE -ne 0) { throw 'Native encoding fixture compilation failed' }
    $runner = Join-Path $fixture 'runner.ps1'
    @'
param([int]$CodePage)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::GetEncoding($CodePage)
$OutputEncoding = [Text.Encoding]::ASCII
$outputBefore = $OutputEncoding
$consoleBefore = [Console]::OutputEncoding
$captured = @(& (Join-Path $PSScriptRoot 'tools/export_windows.ps1') -GodotPath (Join-Path $PSScriptRoot 'native godot.exe') 6>&1)
$code = $LASTEXITCODE
if ([Console]::OutputEncoding.CodePage -ne $consoleBefore.CodePage -or $OutputEncoding.CodePage -ne $outputBefore.CodePage) { throw 'Caller encoding not restored' }
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'captured.txt'), (($captured | ForEach-Object { $_.ToString() }) -join "`n"))
exit $code
'@ | Set-Content -LiteralPath $runner -Encoding UTF8
    $expected = -join ([char[]]@(0x9879,0x76ee,0x521d,0x59cb,0x5316))
    foreach ($cp in @(936,65001)) {
        foreach ($mode in @('success','error','exit')) {
            [IO.File]::WriteAllText((Join-Path $fixture 'mode.txt'), $mode)
            [IO.File]::Delete((Join-Path $fixture 'captured.txt'))
            & $hostExe -NoProfile -ExecutionPolicy Bypass -File $runner $cp
            $code = $LASTEXITCODE
            if (($code -eq 0) -ne ($mode -eq 'success')) { throw "FAIL: $cp/$mode exit $code" }
            if (-not (Test-Path -LiteralPath (Join-Path $fixture 'captured.txt'))) { throw "FAIL: caller restoration assertion failed $cp/$mode" }
            $log = Get-ChildItem -LiteralPath (Join-Path $fixture 'artifacts') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            foreach ($name in @('console.log','engine.log')) {
                $bytes = [IO.File]::ReadAllBytes((Join-Path $log.FullName $name))
                if ($bytes.Length -lt 3 -or $bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191) { throw "FAIL: missing UTF-8 BOM $name" }
            }
            foreach ($text in @([IO.File]::ReadAllText((Join-Path $log.FullName 'console.log')), [IO.File]::ReadAllText((Join-Path $fixture 'captured.txt')))) {
                if (-not $text.Contains("STDOUT $expected") -or -not $text.Contains("STDERR $expected") -or -not $text.Contains($fixture)) { throw "FAIL: corrupted native output $cp/$mode" }
                if ($text.Contains([string][char]27)) { throw "FAIL: ANSI escapes $cp/$mode" }
            }
            if ($mode -eq 'success' -and -not ([IO.File]::ReadAllText((Join-Path $log.FullName 'engine.log'))).Contains($expected)) { throw 'FAIL: engine log encoding' }
            Write-Output "PASS: native UTF-8 $cp/$mode, clean logs and restored caller encoding"
        }
    }
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture outside temporary directory' }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force -ErrorAction SilentlyContinue
}
