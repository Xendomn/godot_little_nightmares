"""Package an already exported Windows build and verify its archive contents."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
shutil.copy2(ROOT / 'README.md', BUILD / 'README.md')
shutil.copy2(ROOT / 'docs' / 'windows-quickstart.txt', BUILD / '开始游戏.txt')
files = ['MidnightWorkshop.exe', 'README.md', '开始游戏.txt',
         'Godot-LICENSE.txt', 'Godot-COPYRIGHT.txt', 'NotoSansSC-OFL.txt']
archive = BUILD / 'MidnightWorkshop-Windows.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as output:
    for name in files:
        output.write(BUILD / name, name)
with zipfile.ZipFile(archive) as output:
    assert output.testzip() is None
    assert set(output.namelist()) == set(files)
    assert hashlib.sha256(output.read('MidnightWorkshop.exe')).digest() == hashlib.sha256((BUILD / 'MidnightWorkshop.exe').read_bytes()).digest()
report = {name: {'bytes': (BUILD / name).stat().st_size,
                 'sha256': hashlib.sha256((BUILD / name).read_bytes()).hexdigest()}
          for name in ['MidnightWorkshop.exe', archive.name]}
(ROOT / 'artifacts' / 'release-v2.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
