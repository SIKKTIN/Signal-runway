from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
for name in ['safe', 'relay', 'wall', 'gain', 'result']:
    image = Image.open(folder / f'c-{name}.png').convert('RGB')
    image.resize((640, 360), Image.Resampling.LANCZOS).save(folder / f'c-{name}-half.png')
    image.convert('L').save(folder / f'c-{name}-gray.png')
frames = [Image.open(p).convert('RGB').resize((960, 540), Image.Resampling.LANCZOS) for p in sorted((folder / 'c-frames').glob('*.png'))]
changes = [int(np.count_nonzero(np.any(np.asarray(a) != np.asarray(b), axis=2))) for a, b in zip(frames, frames[1:])]
frames[0].save(folder / 'c-preview.gif', save_all=True, append_images=frames[1:], duration=67, loop=0, optimize=False)
pause = int(np.count_nonzero(np.any(np.asarray(Image.open(folder / 'c-pause-a.png')) != np.asarray(Image.open(folder / 'c-pause-b.png')), axis=2)))
sources = ['scripts/visual/endless_module_visual.gd', 'scripts/visual/endless_hud_visual.gd', 'scripts/visual/endless_art_preview.gd', 'scenes/visual/endless_art_preview.tscn']
result = {'passed': pause == 0 and min(changes) > 0, 'pause_changed_pixels': pause, 'adjacent_changed_pixels': changes,
          'sources': [{'path': p, 'sha256': hashlib.sha256((root / p).read_bytes()).hexdigest()} for p in sources]}
(folder / 'c-pixels.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
