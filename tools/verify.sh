#!/bin/bash
# macOS ships Bash 3.2; keep this runner compatible with it.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
mkdir -p artifacts
# Do not leave a previous successful summary after a failed run.
rm -f artifacts/verification-results.json
godot_bin="${GODOT:-godot}"
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf 'Godot not found. Set GODOT=/Applications/Godot.app/Contents/MacOS/Godot\n' >&2
    exit 1
fi

results="$(mktemp "$project_root/artifacts/verification-results.XXXXXX")"
trap 'rm -f "$results"' EXIT
printf '[\n' > "$results"
suites=(progress gameplay controls stealth save_store chapter_rules platform
    character_rig expansion routes campaign campaign_ui respawn crouch_states
    keeper_navigation input_devices controller_ui arrow_movement prop_visual
    mechanical_props)
separator=""
for suite in "${suites[@]}"; do
    log_path="$project_root/artifacts/verify-$suite.log"
    console_path="$project_root/artifacts/verify-$suite-console.log"
    rm -f "$log_path"
    if ! "$godot_bin" --headless --path "$project_root" --fixed-fps 60 \
        --log-file "$log_path" --script "tests/test_$suite.gd" > "$console_path" 2>&1; then
        cat "$console_path"
        printf 'Suite failed: %s (see %s)\n' "$suite" "$console_path" >&2
        exit 1
    fi
    cat "$console_path"
    if [[ ! -s "$log_path" ]]; then
        printf 'Missing engine log: %s\n' "$log_path" >&2
        exit 1
    fi
    if LC_ALL=C grep -Eq '^ERROR:|SCRIPT ERROR:|^FAIL:' "$log_path" "$console_path"; then
        printf 'Engine/test error in %s or %s\n' "$log_path" "$console_path" >&2
        exit 1
    fi
    checks="$(awk '/^PASS:/ {n++} END {print n+0}' "$log_path")"
    printf '%s  {"suite":"%s","passed":true,"checks":%s}' \
        "$separator" "$suite" "$checks" >> "$results"
    separator=$',\n'
done
printf '\n]\n' >> "$results"
mv "$results" artifacts/verification-results.json
printf 'ALL %s SUITES PASSED\n' "${#suites[@]}"
