#!/usr/bin/env python3
"""Build schema 24 dictionaries with the production importer; publish atomically."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lexicon', type=Path, default=os.environ.get('CASSOTIS_LEXICON_ROOT'))
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    if args.lexicon is None:
        parser.error('Set CASSOTIS_LEXICON_ROOT or pass --lexicon with the Cassotis Lexicon directory')
    manifest_inputs = json.loads((ROOT / 'data/lexicon-inputs.json').read_text())
    for name, expected in manifest_inputs['source_sha256'].items():
        source = args.lexicon / name
        if not source.is_file() or digest(source) != expected:
            parser.error(f'Lexicon input is missing or has an unexpected checksum: {name}')
    arch = os.environ.get('CASSOTIS_ARCH', 'arm64')
    tool = ROOT / 'build' / arch / 'bin/cassotis-dict-init'
    schema = ROOT / 'data/schema.sql'
    generated = args.lexicon.resolve() / 'data/generated'
    output = ROOT / 'build/dictionaries'
    output.mkdir(parents=True, exist_ok=True)
    modes = [('unihan', 'base'), ('clean', 'base'),
             ('query_path_prior', 'query_path'), ('lm_transition', 'lm_transition'),
             ('transition_completion', 'transition_completion'),
             ('long_completion', 'long_completion'),
             ('completion_prior', 'completion_prior'),
             ('completion_lookup', 'completion_lookup'),
             ('completion_competition', 'completion_competition'),
             ('completion_pair_audit', 'completion_pair_audit'),
             ('char_lm', 'char_lm'), ('char_reverse_lm', 'char_reverse_lm')]
    for variant in ('sc', 'tc'):
        sources = [(generated / f'dict_{name}_{variant}.txt', mode) for name, mode in modes]
        fingerprint = {'schema': digest(schema), 'importer': digest(tool),
                       'inputs': {p.name: digest(p) for p, _ in sources}}
        manifest = output / f'dict_{variant}.json'
        destination = output / f'dict_{variant}.db'
        if not args.force and destination.exists() and manifest.exists():
            old = json.loads(manifest.read_text())
            if old.get('source') == fingerprint and old.get('sha256') == digest(destination):
                print(f'[dictionary] {variant}: up to date', flush=True)
                continue
        with tempfile.TemporaryDirectory(prefix=f'{variant}-', dir=output) as directory:
            database = Path(directory) / destination.name
            log_path = output / f'dict_{variant}.log'
            with log_path.open('w') as log:
                for source, mode in sources:
                    print(f'[dictionary {variant}] {source.name}', flush=True)
                    subprocess.run([str(tool), str(database), str(schema), str(source), mode],
                                   stdout=log, stderr=subprocess.STDOUT, check=True)
                subprocess.run([str(tool), str(database), str(schema), '--build-contains-index'],
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            with sqlite3.connect(database) as connection:
                assert connection.execute('PRAGMA integrity_check').fetchone() == ('ok',)
                tables = [row[0] for row in connection.execute(
                    "SELECT name FROM sqlite_master WHERE type='table'")]
                counts = {t: connection.execute(f'SELECT count(*) FROM "{t}"').fetchone()[0]
                          for t in tables}
                assert counts.get('dict_base', 0) == manifest_inputs['base_entries'][variant]
                connection.execute('PRAGMA wal_checkpoint(TRUNCATE)')
            result = {'source': fingerprint, 'sha256': digest(database), 'rows': counts}
            os.replace(database, destination)
            manifest.write_text(json.dumps(result, indent=2) + '\n')
            print(f'[dictionary] {variant}: {counts["dict_base"]} entries', flush=True)


if __name__ == '__main__':
    main()
