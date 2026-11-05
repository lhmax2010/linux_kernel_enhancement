#!/usr/bin/env python3
"""Normalize and verify deployment metadata; run with the GBS platform Python.

The reference contains numeric metadata read from the official SR modules.img.
No symbolic link is followed, and no mode repair occurs during verification.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import tarfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_reference(path):
    data = json.loads(Path(path).read_text())
    assert data['source_image_sha256'] == 'd0ec6f50ceb59c6f8a4cf3d901df221449705b63bad3db3b69e2c95ed86e939f'
    return data['entries']


def kind(mode):
    if stat.S_ISDIR(mode):
        return 'directory'
    if stat.S_ISREG(mode):
        return 'file'
    if stat.S_ISLNK(mode):
        return 'symlink'
    raise ValueError('Unsupported file type')


def expected(ref, name, typ):
    if name in ref:
        r = ref[name]
        assert typ == r['type'], (name, typ, r)
        return r
    assert typ in ('directory', 'file'), ('Unreferenced symlink', name)
    return {'type': typ, 'uid': 0, 'gid': 0,
            'mode': '0755' if typ == 'directory' else '0644'}


def normalize(root, ref):
    root = Path(root)
    assert root.is_dir() and not root.is_symlink()
    assert os.geteuid() == 0, 'Use unprivileged bwrap --uid 0 --gid 0, never host sudo'
    changed = []
    for p in [root] + sorted(root.rglob('*')):
        old = p.lstat()
        name = '.' if p == root else p.relative_to(root).as_posix()
        r = expected(ref, name, kind(old.st_mode))
        # lchown and chmod only the current object; never dereference build links.
        os.chown(p, r['uid'], r['gid'], follow_symlinks=False)
        if r['type'] != 'symlink':
            os.chmod(p, int(r['mode'], 8), follow_symlinks=False)
        now = p.lstat()
        assert (now.st_uid, now.st_gid, stat.S_IMODE(now.st_mode)) == (r['uid'], r['gid'], int(r['mode'], 8))
        if (old.st_uid, old.st_gid, stat.S_IMODE(old.st_mode)) != (now.st_uid, now.st_gid, stat.S_IMODE(now.st_mode)):
            changed.append(name)
    return changed


def scan(root):
    root = Path(root)
    rows = {}
    for p in sorted(root.rglob('*')):
        s = p.lstat()
        typ = kind(s.st_mode)
        target = os.readlink(p) if typ == 'symlink' else None
        rows[p.relative_to(root).as_posix()] = {
            'type': typ, 'uid': s.st_uid, 'gid': s.st_gid,
            'mode': format(stat.S_IMODE(s.st_mode), '04o'),
            'link_target': target,
            'sha256': digest(p.read_bytes()) if typ == 'file' else (digest(target.encode()) if target else None),
            'bytes': s.st_size if typ == 'file' else None}
    return rows


def check(rows, ref, release):
    prefix = 'lib/modules/' + release
    errors = []
    present = set()
    modules = []
    for name, row in rows.items():
        q = PurePosixPath(name)
        if q.is_absolute() or '..' in q.parts or name in ('', '.'):
            errors.append('unsafe path: ' + name)
            continue
        if name == prefix or name.startswith(prefix + '/'):
            rel = '.' if name == prefix else name[len(prefix)+1:]
            present.add(rel)
            try:
                r = expected(ref, rel, row['type'])
            except AssertionError:
                errors.append('type or unreferenced link: ' + name)
                continue
        else:
            r = expected({}, name, row['type'])
        for key in ('uid', 'gid', 'mode'):
            if row[key] != r[key]:
                errors.append(f'{name}: {key}={row[key]} expected {r[key]}')
        if row['type'] == 'symlink' and row['link_target'] != r.get('link_target'):
            errors.append('link target: ' + name)
        if name.endswith('.ko'):
            if not name.startswith(prefix + '/'):
                errors.append('module outside version directory: ' + name)
                continue
            modules.append(name)
            if row['type'] != 'file' or not int(row['mode'], 8) & 0o004:
                errors.append('others cannot read module: ' + name)
            parent = q.parent
            while str(parent) != 'lib/modules':
                d = rows.get(str(parent))
                if not d or d['type'] != 'directory' or not int(d['mode'], 8) & 0o001:
                    errors.append('others cannot search directory: ' + str(parent))
                parent = parent.parent
    for missing in sorted(set(ref) - present):
        errors.append('missing reference path: ' + missing)
    if not modules:
        errors.append('no modules')
    return {'entries': len(rows), 'modules_checked': len(modules),
            'missing_reference_paths': sorted(set(ref)-present),
            'errors': errors, 'pass': not errors}


def archive_rows(path):
    rows = {}
    with tarfile.open(path, 'r:gz') as tf:
        for member in tf:
            name = member.name.removeprefix('./').rstrip('/')
            assert name not in rows, ('duplicate archive member', name)
            typ = 'file' if member.isfile() else 'directory' if member.isdir() else 'symlink' if member.issym() else None
            assert typ, ('unsupported tar member', name)
            rows[name] = {'type': typ, 'uid': member.uid, 'gid': member.gid,
                          'mode': format(member.mode, '04o'),
                          'bytes': member.size if typ == 'file' else None,
                          'link_target': member.linkname if typ == 'symlink' else None,
                          'sha256': digest(tf.extractfile(member).read()) if typ == 'file' else digest(member.linkname.encode()) if typ == 'symlink' else None}
    return rows


def verify_archive(archive, manifest, ref, release):
    rows = archive_rows(archive)
    result = check(rows, ref, release)
    if rows != manifest:
        result['errors'] += ['archive/manifest mismatch: ' + k for k in sorted(set(rows)|set(manifest)) if rows.get(k) != manifest.get(k)]
    result['pass'] = not result['errors']
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['normalize', 'verify-archive'])
    p.add_argument('path')
    p.add_argument('--reference', required=True)
    p.add_argument('--manifest')
    p.add_argument('--release', default='6.12.80-arm-rpi4-v7l-lko-base01')
    p.add_argument('--output', required=True)
    a = p.parse_args()
    ref = load_reference(a.reference)
    if a.action == 'normalize':
        result = {'pass': True, 'changed': normalize(a.path, ref)}
    else:
        manifest = json.loads(Path(a.manifest).read_text())['entries']
        result = verify_archive(a.path, manifest, ref, a.release)
    Path(a.output).write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))
    return 0 if result['pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
