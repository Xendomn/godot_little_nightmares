#!/bin/bash
# Double-click in Finder, or run with Bash 3.2+. Dependencies are never downloaded.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$project_root/build"
stage="dependency checks"
staging=""
logs=""
lock_owned=0
publishing=0
committed=0
old_app=0
old_zip=0
new_app=0
new_zip=0
app="$build_dir/MidnightWorkshop.app"
archive="$build_dir/MidnightWorkshop-macOS.zip"

fail() { printf 'Export failed (%s): %s\n' "$stage" "$*" >&2; exit 1; }
cleanup() {
    local status=$?
    local keep_staging=0
    set +e
    if [[ "$publishing" == 1 && "$committed" == 0 ]]; then
        [[ "$new_app" == 0 ]] || rm -rf "$app"
        [[ "$new_zip" == 0 ]] || rm -f "$archive"
        if [[ "$old_app" == 1 ]]; then
            mv "$staging/previous-app" "$app" || keep_staging=1
        fi
        if [[ "$old_zip" == 1 ]]; then
            mv "$staging/previous-zip" "$archive" || keep_staging=1
        fi
    fi
    if [[ -n "$staging" && "$keep_staging" == 0 ]]; then rm -rf "$staging"; fi
    if [[ "$keep_staging" == 1 ]]; then
        printf 'Recovery files retained at: %s\n' "$staging" >&2
    fi
    if [[ "$lock_owned" == 1 ]]; then rm -f "$build_dir/.export.lock"; fi
    if [[ "$status" != 0 ]]; then
        printf 'Export stopped during %s. Logs: %s\n' "$stage" "${logs:-not started}" >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[[ $# == 0 ]] || fail 'No arguments supported. Use GODOT=/full/path/to/Godot to select the editor.'
[[ -f "$project_root/project.godot" && -f "$project_root/export_presets.cfg" ]] || fail 'Project files are missing.'
grep -q '^name="macOS"$' "$project_root/export_presets.cfg" || fail 'The macOS export preset is missing.'
if [[ -n "${GODOT:-}" ]]; then
    godot_bin="$GODOT"
elif command -v godot >/dev/null 2>&1; then
    godot_bin="$(command -v godot)"
else
    godot_bin='/Applications/Godot.app/Contents/MacOS/Godot'
fi
command -v "$godot_bin" >/dev/null 2>&1 || fail "Godot not found: $godot_bin. Install Godot 4.7.2 or set GODOT to its executable."
# Resolve a supplied executable name/path before any child operation changes directory.
godot_bin="$(command -v "$godot_bin")"
if [[ "$godot_bin" != /* ]]; then godot_bin="$(pwd)/$godot_bin"; fi
version="$("$godot_bin" --version 2>&1)" || fail "Cannot read Godot version: $version"
case "$version" in
    4.7.2.stable|4.7.2.stable.*) ;;
    *) fail "Expected Godot 4.7.2.stable, found: $version" ;;
esac
template_file="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"
[[ -s "$template_file" ]] || fail "Missing template: $template_file. Install 4.7.2.stable Standard templates through Godot's Export Template Manager."
for tool in codesign lipo ditto unzip; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required macOS tool not found: $tool"
done
[[ -x /usr/libexec/PlistBuddy ]] || fail 'Required macOS tool not found: /usr/libexec/PlistBuddy'

mkdir -p "$build_dir" "$project_root/artifacts"
if ! (set -o noclobber; printf 'macOS export PID %s\n' "$$" > "$build_dir/.export.lock") 2>/dev/null; then
    fail "Another export holds $build_dir/.export.lock. If it was interrupted, verify no exporter is running before removing that lock."
fi
lock_owned=1
staging="$(mktemp -d "$build_dir/.export-macos.XXXXXX")"
logs="$(mktemp -d "$project_root/artifacts/export-macos.XXXXXX")"

run_godot() {
    local name=$1
    shift
    local engine_log="$logs/$name-engine.log"
    local console_log="$logs/$name-console.log"
    printf '%s...\n' "$name"
    if ! "$godot_bin" --headless --path "$project_root" --log-file "$engine_log" "$@" > "$console_log" 2>&1; then
        cat "$console_log" >&2
        fail "Godot returned an error. See $console_log"
    fi
    [[ -s "$engine_log" ]] || fail "Godot did not create its log: $engine_log"
    if LC_ALL=C grep -Eq '^ERROR:|SCRIPT ERROR:|^FAIL:' "$engine_log" "$console_log"; then
        cat "$console_log" >&2
        fail "Godot reported an error. See $engine_log"
    fi
}

stage="resource import"
run_godot import --editor --import --quit
stage="release export"
run_godot export --export-release macOS "$staging/MidnightWorkshop.app"
stage="application validation"
bundle="$staging/MidnightWorkshop.app"
[[ -s "$bundle/Contents/Info.plist" ]] || fail 'The exported app has no Info.plist.'
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")" || fail 'The app executable is not declared.'
[[ -n "$executable" && "$executable" != */* && "$executable" != '.' && "$executable" != '..' ]] || fail 'Invalid app executable name.'
[[ -s "$bundle/Contents/MacOS/$executable" && -x "$bundle/Contents/MacOS/$executable" ]] || fail 'The app executable is missing or not executable.'
[[ -s "$bundle/Contents/Resources/$executable.pck" ]] || fail 'The exported resource pack is missing.'
lipo "$bundle/Contents/MacOS/$executable" -verify_arch arm64 x86_64 > "$logs/architecture.log" 2>&1 || fail "Universal architecture check failed: $logs/architecture.log"
codesign --verify --deep --strict "$bundle" > "$logs/signature.log" 2>&1 || fail "App signature verification failed: $logs/signature.log"

stage="ZIP packaging"
zip_output="$staging/MidnightWorkshop-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$bundle" "$zip_output" > "$logs/package.log" 2>&1 || fail "ZIP packaging failed: $logs/package.log"
[[ -s "$zip_output" ]] || fail 'ZIP output is missing.'
unzip -t "$zip_output" >> "$logs/package.log" 2>&1 || fail 'ZIP integrity check failed.'
# Apple's unzip listing can misdecode UTF-8 filenames under C.UTF-8 locales.
# Check the actual extracted bytes using ditto instead of parsing listed names.
check_dir="$staging/archive-check"
ditto -x -k "$zip_output" "$check_dir" >> "$logs/package.log" 2>&1 || fail 'Cannot extract ZIP for validation.'
for entry in 'Contents/Info.plist' "Contents/MacOS/$executable" "Contents/Resources/$executable.pck"; do
    [[ -s "$check_dir/MidnightWorkshop.app/$entry" ]] || fail "ZIP is missing $entry"
    cmp -s "$bundle/$entry" "$check_dir/MidnightWorkshop.app/$entry" || fail "ZIP content differs: $entry"
done
codesign --verify --deep --strict "$check_dir/MidnightWorkshop.app" >> "$logs/signature.log" 2>&1 || fail 'The archived app signature is invalid.'

stage="publishing outputs"
publishing=1
if [[ -e "$app" || -L "$app" ]]; then mv "$app" "$staging/previous-app"; old_app=1; fi
if [[ -e "$archive" || -L "$archive" ]]; then mv "$archive" "$staging/previous-zip"; old_zip=1; fi
mv "$bundle" "$app"
new_app=1
mv "$zip_output" "$archive"
new_zip=1
committed=1
printf 'Export complete:\n  %s\n  %s\nLogs: %s\n' "$app" "$archive" "$logs"
