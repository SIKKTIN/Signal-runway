from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
folder = Path(__file__).resolve().parent
root = folder.parents[2]
a=np.asarray(Image.open(folder/'paused-a.png').convert('RGB'))
b=np.asarray(Image.open(folder/'paused-b.png').convert('RGB'))
pause=int(np.any(a!=b,axis=2).sum())
for name in ['final-challenge-wait-exit-960','station-full-1280','station-380-selected-heal-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
sources=['scripts/visual/route_visual.gd','scenes/ui/v06_route_status.gd','scenes/ui/v06_route_status.tscn',
         'scenes/ui/v05_status.gd','scripts/visual/endless_module_visual.gd','scripts/visual/endless_hud_visual.gd',
         'assets/audio/v06/complete.wav','assets/audio/v06/recover.wav']
result={'passed':pause==0,'pause_changed_pixels':pause,'sources':[{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in sources],
        'scope':'E final presentation resource hashes and screenshot QA, not F frozen production manifest.'}
(folder/'pixels-results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'passed':result['passed'],'pause_changed_pixels':pause,'source_count':len(sources)}))
