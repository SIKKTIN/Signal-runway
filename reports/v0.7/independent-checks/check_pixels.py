from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

folder=Path(__file__).resolve().parent
root=folder.parents[2]
a=np.asarray(Image.open(folder/'natural-pause-a.png'))
b=np.asarray(Image.open(folder/'natural-pause-b.png'))
assert a.shape==b.shape
pause=int(np.any(a!=b,axis=2).sum())
manifest=json.loads((root/'reports/v0.7/version-manifest.json').read_text(encoding='utf-8-sig'))
copy=folder/'version-manifest-initial.json'
if not copy.exists():
    copy.write_bytes((root/'reports/v0.7/version-manifest.json').read_bytes())
mismatch=[row['path'] for row in manifest['files'] if hashlib.sha256((root/row['path']).read_bytes()).hexdigest()!=row['sha256']]
gray=[]
for name in ['natural-404-upper-seam-960','natural-404-upper-station-selected','tool-late-connection-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
    gray.append(name+'-gray.png')
result={'version':manifest['version'],'files':len(manifest['files']),'mismatches':mismatch,'pause_changed_pixels':pause,'gray_previews':gray,'passed':not mismatch and pause==0,'method':'Actual Esc pause pair from natural seed404 upper route, whole image comparison. Current source hashes independently checked against manifest. Grayscale previews are legibility evidence; no quantitative all-map overlap claim.'}
(folder/'pixels-and-sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
