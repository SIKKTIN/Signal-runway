from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
folder=Path(__file__).resolve().parent
root=folder.parents[2]
a=np.asarray(Image.open(folder/'g-camera-pause-a.png'))
b=np.asarray(Image.open(folder/'g-camera-pause-b.png'))
pause=int(np.any(a!=b,axis=2).sum())
manifest=json.loads((root/'reports/v0.7/version-manifest.json').read_text(encoding='utf-8-sig'))
initial=json.loads((folder/'version-manifest-initial.json').read_text(encoding='utf-8-sig'))
old={r['path']:r['sha256'] for r in initial['files']}
changed=[r['path'] for r in manifest['files'] if old.get(r['path'])!=r['sha256']]
mismatch=[r['path'] for r in manifest['files'] if hashlib.sha256((root/r['path']).read_bytes()).hexdigest()!=r['sha256']]
(folder/'g-version-manifest.json').write_bytes((root/'reports/v0.7/version-manifest.json').read_bytes())
result={'version':manifest['version'],'sha256':manifest['sha256'],'files':len(manifest['files']),'mismatches':mismatch,'changed_from_initial_214':changed,'pause_changed_pixels':pause,'passed':pause==0 and not mismatch and changed==['scripts/level/run_flow.gd'],'method':'Only current camera fix manifest/draw-pause verification. Initial six natural routes and 24 tool results remain unchanged; exactly one production file differs.'}
(folder/'g-camera-pixels-and-sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
