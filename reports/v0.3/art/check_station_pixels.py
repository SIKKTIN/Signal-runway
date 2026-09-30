from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent / 'station'
root = folder.parents[3]
a = np.asarray(Image.open(folder / 'pause-a.png').convert('RGB'))
b = np.asarray(Image.open(folder / 'pause-b.png').convert('RGB'))
pause_changed = int(np.count_nonzero(np.any(a != b, axis=2)))
frames = [Image.open(file).convert('RGB') for file in sorted((folder / 'frames').glob('branch-*.png'))]
motion = [int(np.count_nonzero(np.any(np.asarray(x) != np.asarray(y), axis=2))) for x, y in zip(frames, frames[1:])]
small = [frame.resize((960, 540), Image.Resampling.LANCZOS) for frame in frames]
small[0].save(folder / 'station-preview.gif', save_all=True, append_images=small[1:], duration=50, loop=0, optimize=False)
for name in ['branch-one', 'branch-one-exit', 'branch-two', 'branch-two-exit', 'branch-two-activation', 'transmission', 'output']:
    image = Image.open(folder / (name + '.png')).convert('RGB')
    image.resize((640, 360), Image.Resampling.LANCZOS).save(folder / (name + '-half.png'))
    if name in ['branch-one', 'branch-two']:
        image.convert('L').save(folder / (name + '-gray.png'))
file = root / 'scripts/visual/environment_visual.gd'
result = {'pause_changed_pixels': pause_changed, 'continuous_frames': len(frames), 'min_adjacent_changed_pixels': min(motion),
          'environment_sha256': hashlib.sha256(file.read_bytes()).hexdigest(), 'passed': pause_changed == 0 and min(motion) > 0,
          'method': 'Fixed camera/actor, no actor collision in layout fixtures; motion/readability only, not route evidence.'}
(folder / 'pixel-results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
