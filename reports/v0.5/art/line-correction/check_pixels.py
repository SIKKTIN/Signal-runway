from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[3]
a = np.asarray(Image.open(folder / 'front-line-current.png').convert('RGB'))
b = np.asarray(Image.open(folder / 'front-line-without-effect.png').convert('RGB'))
delta = np.any(a != b, axis=2)
front = 560 * a.shape[1] / 960
columns = np.flatnonzero(delta.any(axis=0))
result = {
    'front_pixel_x': front,
    'former_line_changed_pixels': int(delta[:, int(front)-2:int(front)+2].sum()),
    'max_effect_pixel_x': int(columns.max()),
    'ahead_changed_pixels': int(delta[:, int(np.ceil(front)):].sum()),
    'source_sha256': hashlib.sha256((root / 'scripts/visual/chase_visual.gd').read_bytes()).hexdigest(),
}
result['passed'] = result['former_line_changed_pixels'] == 0 and result['ahead_changed_pixels'] == 0
(folder / 'front-line-pixels.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
Image.open(folder / 'front-line-current.png').resize((960, 540), Image.Resampling.LANCZOS).save(folder / 'front-line-preview.png')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)

