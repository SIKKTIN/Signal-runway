from pathlib import Path
import json

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
pause_a = np.asarray(Image.open(folder / 'pause-a.png').convert('RGB'))
pause_b = np.asarray(Image.open(folder / 'pause-b.png').convert('RGB'))
pause_changed = int(np.count_nonzero(np.any(pause_a != pause_b, axis=2)))
frames = [Image.open(file).convert('RGB') for file in sorted((folder / 'frames').glob('relay-*.png'))]
small = [frame.resize((960, 540), Image.Resampling.LANCZOS) for frame in frames]
small[0].save(folder / 'relay-preview.gif', save_all=True, append_images=small[1:], duration=50, loop=0, optimize=False)
for name in ['available', 'activating', 'activated', 'time-trial']:
    img = Image.open(folder / (name + '.png')).convert('RGB')
    img.resize((640, 360), Image.Resampling.LANCZOS).save(folder / (name + '-half.png'))
    img.convert('L').save(folder / (name + '-gray.png'))
result = {'pause_changed_pixels': pause_changed, 'passed': pause_changed == 0, 'frames': len(frames),
          'method': 'Frozen-interface preview; same fixed front/player. No gameplay collision or route proof.'}
(folder / 'relay-pixels.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
