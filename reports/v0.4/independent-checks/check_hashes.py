from pathlib import Path
import hashlib
import json
import sys

folder = Path(__file__).resolve().parent
root = folder.parents[2]
manifest = json.loads((root / 'reports/v0.4/version-manifest.json').read_text(encoding='utf-8'))
results = []
for row in manifest['files']:
    file = root / row['path']
    data = file.read_bytes() if file.is_file() else b''
    actual = hashlib.sha256(data).hexdigest()
    results.append({'path': row['path'], 'passed': file.is_file() and actual == row['sha256'] and len(data) == row['bytes'], 'sha256': actual, 'bytes': len(data)})
summary = {'version': manifest['version'], 'sha256': manifest['sha256'], 'files': results,
           'manifest_sha256': hashlib.sha256((root / 'reports/v0.4/version-manifest.json').read_bytes()).hexdigest(),
           'passed': len(results) == 84 and all(row['passed'] for row in results)}
(folder / ('hashes-' + sys.argv[1] + '.json')).write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps({'version': summary['version'], 'passed': summary['passed'], 'files': len(results)}))
raise SystemExit(0 if summary['passed'] else 1)
