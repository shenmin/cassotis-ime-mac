#!/usr/bin/env python3
"""Reassemble the character model from numbered Git files, checking its SHA-256."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def restore(directory):
    directory = Path(directory)
    model = directory / 'char_lm.onnx'
    expected = json.loads((directory / 'runtime_manifest.json').read_text())['files'][model.name]
    parts = sorted(directory.glob(model.name + '.[0-9][0-9][0-9]'))
    if parts and [p.name for p in parts] != [f'{model.name}.{i:03d}' for i in range(len(parts))]:
        raise ValueError('Character model parts are not contiguous from .000')
    if model.is_file() and digest(model) == expected:
        return model
    if not parts:
        raise ValueError('Character model is missing or invalid and no numbered parts are available')
    # Publish only a complete, verified model. A failed join never replaces the
    # previous file and its temporary output is removed, including on errors.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=directory, prefix='char_lm.', suffix='.joining', delete=False) as output:
            temporary = Path(output.name)
            for part in parts:
                with part.open('rb') as stream:
                    shutil.copyfileobj(stream, output, 1024 * 1024)
        if digest(temporary) != expected:
            raise ValueError('Joined character model SHA-256 does not match runtime_manifest.json')
        os.replace(temporary, model)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    return model


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(f'Character model verified: {restore(args.directory).name}')
