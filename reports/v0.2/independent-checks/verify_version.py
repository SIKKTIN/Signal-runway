from pathlib import Path
import hashlib
import json

folder = Path(__file__).resolve().parent
root = folder.parents[2]
manifest = json.loads((root / 'reports/v0.2/version-manifest.json').read_text(encoding='utf-8'))
rows = []
for expected in manifest['files']:
    data = (root / expected['path']).read_bytes()
    rows.append({'path': expected['path'], 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
digest = hashlib.sha256(json.dumps(rows, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
mismatches = [r['path'] for r, e in zip(rows, manifest['files']) if r != e]
passed = not mismatches and digest == manifest['sha256'] == '0dd12888c9bf9798ce1ca9f5fe5511a569fefb452b827f3d04e850b38f7e6023'
result = {'version': manifest['version'], 'files': len(rows), 'sha256': digest, 'mismatches': mismatches, 'passed': passed}
(folder / 'version-check.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if passed else 1)
