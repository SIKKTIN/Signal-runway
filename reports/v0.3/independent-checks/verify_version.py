from pathlib import Path
import hashlib
import json

folder = Path(__file__).resolve().parent
root = folder.parents[2]
manifest = json.loads((root / 'reports/v0.3/version-manifest.json').read_text(encoding='utf-8'))
rows = []
for entry in manifest['files']:
    data = (root / entry['path']).read_bytes()
    rows.append({'path': entry['path'], 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
digest = hashlib.sha256(json.dumps(rows, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
mismatches = [actual['path'] for actual, expected in zip(rows, manifest['files']) if actual != expected]
passed = len(rows) == 66 and not mismatches and digest == manifest['sha256'] == '8f8f69c021f9df9b733292c71936b21eb8ebca8baa7fb682df39fdaa90158d35' and manifest['version'] == 'v0.3.0+8f8f69c021f9'
result = {'version': manifest['version'], 'sha256': digest, 'files': len(rows), 'mismatches': mismatches, 'passed': passed}
(folder / 'version-check.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if passed else 1)
