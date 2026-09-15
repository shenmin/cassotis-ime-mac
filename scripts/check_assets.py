#!/usr/bin/env python3
"""Verify the model and schema checksums required by the build."""
import hashlib
from pathlib import Path, PurePosixPath
import re
import sys


def verify_assets(root):
    expected = {}
    for line in (root / 'data/runtime-assets.sha256').read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        match = re.fullmatch(r'([0-9a-f]{64})  (data/\S+)', line)
        if not match:
            raise ValueError('Invalid runtime asset checksum entry')
        checksum, name = match.groups()
        path = PurePosixPath(name)
        if '..' in path.parts or name in expected or not (root / name).resolve().is_relative_to(root.resolve()):
            raise ValueError(f'Invalid runtime asset path: {name}')
        expected[name] = checksum
    if 'data/schema.sql' not in expected or not any(name.startswith('data/models/') for name in expected):
        raise ValueError('Runtime asset manifest is incomplete')
    failures = []
    for name, checksum in expected.items():
        path = root / name
        if not path.is_file():
            failures.append(f'missing: {name}')
            continue
        with path.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != checksum:
                failures.append(f'checksum mismatch: {name}')
    actual_models = {str(p.relative_to(root)) for p in (root / 'data/models').rglob('*') if p.is_file()}
    failures += [f'untracked model asset: {name}' for name in sorted(actual_models - expected.keys())]
    if failures:
        raise ValueError('\n'.join(failures))
    return len(expected)


if __name__ == '__main__':
    try:
        count = verify_assets(Path(__file__).resolve().parents[1])
    except (ValueError, OSError) as error:
        sys.exit(str(error))
    print(f'Runtime assets verified: {count} files')
