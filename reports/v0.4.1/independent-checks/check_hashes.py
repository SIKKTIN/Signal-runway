from pathlib import Path
import hashlib
import json
import sys
folder = Path(__file__).resolve().parent
root = folder.parents[2]
manifest_file = root / 'reports/v0.4.1/version-manifest.json'
manifest = json.loads(manifest_file.read_text(encoding='utf-8'))
rows = []
for row in manifest['files']:
    p = root / row['path']
    data = p.read_bytes() if p.is_file() else b''
    actual = hashlib.sha256(data).hexdigest()
    rows.append({'path':row['path'], 'sha256':actual, 'bytes':len(data), 'passed':p.is_file() and actual==row['sha256'] and len(data)==row['bytes']})
result = {'version':manifest['version'],'sha256':manifest['sha256'],'manifest_sha256':hashlib.sha256(manifest_file.read_bytes()).hexdigest(),'files':rows,'passed':len(rows)==90 and all(r['passed'] for r in rows)}
(folder / ('hashes-'+sys.argv[1]+'.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'version':result['version'],'files':len(rows),'passed':result['passed']}))
raise SystemExit(0 if result['passed'] else 1)
