"""Verify repeat generation and safe failure for a partially missing project."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = shutil.which('godot')
assert GODOT, 'Godot must be on PATH'

for iteration in range(2):
    run = subprocess.run([GODOT, '--headless', '--path', str(ROOT), '--script', 'res://tools/build_expansion.gd',
                          '--log-file', str(ROOT / 'artifacts' / f'builder-repeat-{iteration}.log')],
                         capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    assert run.returncode == 0 and 'BUILT FOUR CHAPTER CAMPAIGN' in run.stdout, run.stdout + run.stderr
    for chapter in ['workshop', 'laundry', 'thread_vault', 'clocktower']:
        assert (ROOT / 'scenes' / 'chapters' / (chapter + '.tscn')).stat().st_size > 1000
print('PASS: complete expansion generation can run twice')

fixture = ROOT / 'artifacts' / 'builder-fixture'
(fixture / 'tools').mkdir(parents=True, exist_ok=True)
(fixture / 'scenes').mkdir(exist_ok=True)
(fixture / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Builder test"\n', encoding='utf-8')
main_text = '[gd_scene format=3]\n[node name="Campaign" type="Node"]\n'
(fixture / 'scenes' / 'main.tscn').write_text(main_text, encoding='utf-8')
for name in ['build_scene.gd', 'build_expansion.gd']:
    shutil.copy2(ROOT / 'tools' / name, fixture / 'tools' / name)
run = subprocess.run([GODOT, '--headless', '--path', str(fixture), '--script', 'res://tools/build_expansion.gd',
                      '--log-file', str(ROOT / 'artifacts' / 'builder-missing-workshop.log')],
                     capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
assert run.returncode == 1 and 'Missing workshop.tscn' in run.stdout + run.stderr, run.stdout + run.stderr
assert (fixture / 'scenes' / 'main.tscn').read_text(encoding='utf-8') == main_text
assert not (fixture / 'scenes' / 'chapters' / 'workshop.tscn').exists()
print('PASS: missing workshop fails explicitly without copying campaign into a chapter')
