"""Exercise the exporter with fake tools; never export or launch the real game."""
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/export_macos.command'
FAKE = r'''#!/usr/bin/env python3
import os, pathlib, plistlib, sys, zipfile
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
mode = os.environ.get('EXPORT_TEST_MODE', 'success')
if name == 'godot':
    if '--version' in args:
        print('4.6.stable.official' if mode == 'version' else '4.7.2.stable.official.fixture')
        sys.exit(0)
    stage = 'import' if '--import' in args else 'export'
    log = pathlib.Path(args[args.index('--log-file') + 1])
    if mode != stage + '_missing_log': log.write_text('Godot fixture\n')
    if mode == stage + '_fail': sys.exit(7)
    if mode == stage + '_error':
        log.write_text('SCRIPT ERROR: intentional failure\n')
    if mode == stage + '_stderr': print('ERROR: intentional failure', file=sys.stderr)
    if stage == 'export' and mode != 'missing_output':
        dest = pathlib.Path(args[args.index('--export-release') + 2])
        (dest / 'Contents/MacOS').mkdir(parents=True)
        (dest / 'Contents/Resources').mkdir()
        executable = '午夜工坊 · Midnight Workshop' if mode == 'unicode_bundle' else 'Game'
        (dest / 'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':executable}))
        (dest / ('Contents/MacOS/' + executable)).write_bytes(b'new executable')
        (dest / ('Contents/MacOS/' + executable)).chmod(0o755)
        if mode != 'missing_pck': (dest / ('Contents/Resources/' + executable + '.pck')).write_bytes(b'PCK fixture')
elif name == 'codesign': sys.exit(9 if mode == 'sign_fail' else 0)
elif name == 'lipo':
    if args[1:] != ['-verify_arch','arm64','x86_64']: sys.exit(11)
    sys.exit(9 if mode == 'arch_fail' else 0)
elif name == 'ditto':
    if '-x' in args:
        with zipfile.ZipFile(args[-2]) as archive: archive.extractall(args[-1])
        sys.exit(0)
    if mode == 'pack_fail': sys.exit(8)
    src, dest = map(pathlib.Path, args[-2:])
    if mode == 'bad_zip': dest.write_bytes(b'invalid'); sys.exit(0)
    with zipfile.ZipFile(dest, 'w') as archive:
        if mode != 'empty_zip':
            for p in src.rglob('*'):
                if p.is_file(): archive.write(p, str(pathlib.Path(src.name) / p.relative_to(src)))
elif name == 'mv':
    if mode == 'publish_fail' and args[-1].endswith('/MidnightWorkshop-macOS.zip') and '/previous-' not in args[-2]:
        sys.exit(8)
    os.execv('/bin/mv', ['/bin/mv'] + args)
'''


class ExportMacTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='export 测试 space ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'project 中文'
        self.bin = Path(self.temp.name) / 'fake tools'
        self.home = Path(self.temp.name) / 'isolated home'
        self.bin.mkdir()
        (self.root / 'tools').mkdir(parents=True)
        self.assertTrue(SCRIPT.exists(), 'macOS exporter must exist')
        (self.root / 'project.godot').write_text('config_version=5\n')
        (self.root / 'export_presets.cfg').write_text('[preset.1]\nname="macOS"\n')
        template = self.home / 'Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip'
        template.parent.mkdir(parents=True)
        template.write_bytes(b'template fixture')
        self.template = template
        # Isolate the standard template location in the disposable script copy.
        # No user home/environment settings are overwritten.
        script_text = SCRIPT.read_text().replace(
            '"$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"',
            shlex.quote(str(template)))
        (self.root / 'tools' / SCRIPT.name).write_text(script_text)
        for name in ['godot', 'codesign', 'lipo', 'ditto', 'mv']:
            p = self.bin / name
            p.write_text(FAKE)
            p.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        GODOT=str(self.bin / 'godot'))
        self.build = self.root / 'build'
        (self.build / 'MidnightWorkshop.app').mkdir(parents=True)
        (self.build / 'MidnightWorkshop.app/old.txt').write_text('previous app')
        (self.build / 'MidnightWorkshop-macOS.zip').write_bytes(b'previous zip')

    def run_export(self, mode='success'):
        env = dict(self.env, EXPORT_TEST_MODE=mode)
        return subprocess.run(['/bin/bash', str(self.root / 'tools' / SCRIPT.name)],
                              cwd=self.temp.name, env=env, capture_output=True, text=True, timeout=15)

    def assert_old_preserved(self):
        self.assertEqual((self.build / 'MidnightWorkshop.app/old.txt').read_text(), 'previous app')
        self.assertEqual((self.build / 'MidnightWorkshop-macOS.zip').read_bytes(), b'previous zip')

    def test_failures_preserve_previous_release(self):
        for mode in ['version', 'import_fail', 'export_fail', 'import_error', 'export_error',
                     'import_stderr', 'export_stderr', 'import_missing_log', 'export_missing_log',
                     'missing_output', 'missing_pck', 'sign_fail', 'arch_fail', 'pack_fail', 'bad_zip',
                     'empty_zip', 'publish_fail']:
            with self.subTest(mode=mode):
                run = self.run_export(mode)
                self.assertNotEqual(run.returncode, 0, run.stdout + run.stderr)
                self.assert_old_preserved()
                self.assertFalse((self.build / '.export.lock').exists())

    def test_missing_godot(self):
        self.env['GODOT'] = str(self.bin / 'missing executable')
        self.assertNotEqual(self.run_export().returncode, 0)
        self.assert_old_preserved()

    def test_missing_template(self):
        self.template.unlink()
        run = self.run_export()
        self.assertNotEqual(run.returncode, 0)
        self.assertIn('macos.zip', run.stdout + run.stderr)
        self.assert_old_preserved()

    def test_lock_is_not_removed_by_second_export(self):
        lock = self.build / '.export.lock'
        lock.write_text('other export')
        self.assertNotEqual(self.run_export().returncode, 0)
        self.assertEqual(lock.read_text(), 'other export')
        self.assert_old_preserved()

    def test_unicode_bundle(self):
        run = self.run_export('unicode_bundle')
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_success_repeat_unicode_and_external_directory(self):
        for _ in range(2):
            run = self.run_export()
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertEqual((self.build / 'MidnightWorkshop.app/Contents/MacOS/Game').read_bytes(), b'new executable')
            self.assertFalse((self.build / '.export.lock').exists())
            self.assertFalse(list(self.build.glob('.export-macos.*')))


if __name__ == '__main__':
    unittest.main(verbosity=2)
