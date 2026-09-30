from pathlib import Path
import json

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
report = folder.parent
before = np.asarray(Image.open(folder / 'pause-a.png').convert('RGB'))
after = np.asarray(Image.open(folder / 'pause-b.png').convert('RGB'))
changed = int(np.count_nonzero(np.any(before != after, axis=2)))
for source, stem in [(folder / 'menu.png', 'menu'), (folder / 'relay-active.png', 'contact'), (folder / 'failure.png', 'failure'),
                     (report / 'first-branch.png', 'first-branch'), (report / 'second-branch.png', 'second-branch')]:
    image = Image.open(source).convert('RGB')
    image.resize((640, 360), Image.Resampling.LANCZOS).save(folder / (stem + '-half.png'))
result = {'version': 'v0.3.0+8f8f69c021f9', 'pause_changed_pixels': changed, 'passed': changed == 0,
          'source': 'Own same-version runtime captures; first/second branch thumbnails reference producer final GPU captures.'}
(folder / 'pixel-results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
