from pathlib import Path
import json
import hashlib
import numpy as np
from PIL import Image

out = Path(__file__).resolve().parent
root = out.parents[2]
results = {}
for size in (960, 1280):
    a = np.asarray(Image.open(out / f'{size}-pause-before.png').convert('RGB'))
    b = np.asarray(Image.open(out / f'{size}-pause-after.png').convert('RGB'))
    with_effect = np.asarray(Image.open(out / f'{size}-surface-with.png').convert('RGB'))
    without = np.asarray(Image.open(out / f'{size}-surface-without.png').convert('RGB'))
    diff = np.any(with_effect != without, axis=2)
    white = (without.min(axis=2) > 180) & (np.ptp(without.astype(int), axis=2) < 60)
    results[str(size)] = {
        'pause_changed_pixels': int(np.any(a != b, axis=2).sum()),
        'effect_changed_pixels': int(diff.sum()),
        'bright_neutral_changed_pixels': int((white & diff).sum()),
        'method': 'Actual Main ground dash, frozen pause with pause overlay hidden for with/without DashVisual pair. Not natural traversal or business validation.'
    }
results['passed'] = all(r['pause_changed_pixels'] == 0 and r['bright_neutral_changed_pixels'] == 0 and r['effect_changed_pixels'] > 10 for r in results.values())
paths = ['scripts/visual/dash_visual.gd', 'scenes/ui/v08_dash_status.gd', 'scenes/ui/v08_dash_status.tscn', 'assets/audio/v08/dash_start.wav', 'assets/audio/v08/dash_refill.wav']
results['sources'] = {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
(out / 'skill-pixels-and-sources.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps(results, ensure_ascii=False))
raise SystemExit(0 if results['passed'] else 1)
