#!/usr/bin/env python3
"""Read-only validation of the staged project files before a main push.

Run from the workspace with TMPDIR=$WS/temp. Does not compile, contact a
board, change Git configuration, stage files, commit, or push.
"""
import fnmatch
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

files = git('ls-files', '-z').decode().split('\0')
errors = []
sizes = []
patterns = ['*.rpm', '*.o', '*.ko', 'zImage', 'Image', 'Image.gz',
            'vmlinux*', 'GBS-ROOT*', '*.a', '*.so', '*.so.*', '*.bin', '*.elf',
            '*.dtb', '*.dtbo', '*.pyc']
for name in filter(None, files):
    p = pathlib.PurePosixPath(name)
    if p.parts[0] in {'linux-rpi', 'temp', 'build', 'dist'}:
        errors.append(f'forbidden tree: {name}')
    if any(fnmatch.fnmatch(part, pat) for part in p.parts for pat in patterns):
        errors.append(f'forbidden artifact: {name}')
    blob = git('show', ':' + name)
    sizes.append((len(blob), name))
    if len(blob) >= 1_000_000:
        errors.append(f'file must be <1 MB: {name} ({len(blob)} bytes)')
    if b'\0' in blob:
        errors.append(f'binary NUL: {name}')
    try:
        blob.decode('utf-8')
    except UnicodeDecodeError:
        errors.append(f'non-UTF-8 text: {name}')
for required in ['docs/RULES.md', 'docs/STATUS.md',
                 'docs/01_kernel_inventory.md', 'docs/02_gerrit_overlap.md']:
    if required not in files:
        errors.append(f'missing deliverable: {required}')
for p in (ROOT / 'docs').glob('*.md'):
    import re
    for target in re.findall(r'\]\(([^)]+)\)', p.read_text()):
        if '://' in target or target.startswith('#'):
            continue
        if not (p.parent / target.split('#')[0]).exists():
            errors.append(f'broken local link: {p.name}: {target}')
print(f'files={len(sizes)} bytes={sum(n for n, _ in sizes)}')
for n, name in sorted(sizes, reverse=True)[:5]:
    print(f'largest: {n} {name}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('PASS: required docs, staged UTF-8 text, <1 MB per file, forbidden paths, doc links')
