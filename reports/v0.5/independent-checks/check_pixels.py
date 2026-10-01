from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
a = np.asarray(Image.open(folder/'tool-pause-a.png').convert('RGB'))
b = np.asarray(Image.open(folder/'tool-pause-b.png').convert('RGB'))
changed = int(np.any(a != b,axis=2).sum())
for name in ['route-404-upper-upper','tool-hurt-1280','tool-recovered-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
manifest = json.loads((root/'reports/v0.5/version-manifest.json').read_text(encoding='utf-8-sig'))
mismatches = [row['path'] for row in manifest['files']
              if hashlib.sha256((root/row['path']).read_bytes()).hexdigest() != row['sha256']]
result = {'version':manifest['version'],'file_count':len(manifest['files']),
          'final_source_mismatches':mismatches,'pause_changed_pixels':changed,
          'image_sizes':{name:list(Image.open(folder/name).size) for name in ['tool-hurt-1280.png','tool-recovered-960.png','route-404-upper-upper.png']},
          'passed':changed == 0 and not mismatches,
          'scope':'GPU screenshot pixels and frozen source verification; no human experience claim.'}
(folder/'pixels-results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
