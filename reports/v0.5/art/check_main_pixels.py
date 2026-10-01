from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
a = np.asarray(Image.open(folder/'main-paused-a.png').convert('RGB'))
b = np.asarray(Image.open(folder/'main-paused-b.png').convert('RGB'))
pause = int(np.any(a != b, axis=2).sum())
for name in ['main-hurt-960', 'main-full-1280', 'main-geometry-01-1280', 'main-geometry-03-1280', 'main-low-960']:
    Image.open(folder/(name+'.png')).convert('L').save(folder/(name+'-gray.png'))
sources = ['scenes/ui/v05_status.gd', 'scenes/ui/v05_status.tscn',
           'assets/visual/v05/platform_cap.svg', 'assets/visual/v05/ground_side.svg',
           'assets/visual/v05/route_upper.svg', 'assets/audio/v05/hurt_tick.wav',
           'scripts/visual/chase_visual.gd', 'scripts/level/run_flow.gd',
           'scripts/level/course.gd', 'scripts/level/endless_course.gd',
           'scripts/visual/endless_hud_visual.gd']
result = {'passed': pause == 0, 'pause_changed_pixels': pause,
          'image_sizes': {name: list(Image.open(folder/name).size)
                          for name in ['main-full-1280.png','main-hurt-1280.png','main-hurt-960.png','main-tool-960.png']},
          'sources': [{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in sources],
          'scope':'F capture-time presentation/source snapshot; not final G frozen manifest. Grayscale copies are QA artifacts, not production assets.'}
(folder/'main-pixels.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'passed':result['passed'],'pause_changed_pixels':pause,'image_sizes':result['image_sizes']}))
raise SystemExit(0 if result['passed'] else 1)
