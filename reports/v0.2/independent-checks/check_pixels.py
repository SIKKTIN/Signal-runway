from pathlib import Path
import json
import math

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
runtime = json.loads((folder / 'runtime-results.json').read_text(encoding='utf-8'))
with_front = np.asarray(Image.open(folder / 'front_with.png').convert('RGB'))
without_front = np.asarray(Image.open(folder / 'front_without.png').convert('RGB'))
delta = np.max(np.abs(with_front.astype(int) - without_front.astype(int)), axis=2)
changed_y, changed_x = np.where(delta > 0)
# Canvas-items stretching uses a 960x540 logical canvas. PNG is 1280x720;
# the texture handle's reported size differs, so use actual PNG pixels here.
scale = with_front.shape[1] / 960.0
front_pixel = runtime['boundary']['front_screen_x'] * scale
start_ahead = math.ceil(front_pixel)
ahead_unchanged = bool(np.max(delta[:, start_ahead:]) == 0)
for name in ['front_with', 'urgent', 'caught', 'spike', 'fall']:
    img = Image.open(folder / (name + '.png')).convert('RGB')
    img.resize((640, 360), Image.Resampling.LANCZOS).save(folder / (name + '_half.png'))
Image.open(folder / 'front_with.png').convert('L').save(folder / 'front_grayscale.png')
passed = ahead_unchanged and int(changed_x.max()) < start_ahead
result = {
    'version': runtime['version'],
    'method': 'Same frozen live main scene, actual Esc pause; pause card temporarily hidden and ChaseVisual draw toggled. HUD unchanged. Pixel fixture only.',
    'image_size': [with_front.shape[1], with_front.shape[0]],
    'logical_canvas': [960, 540],
    'front_world_x': runtime['boundary']['front_world_x'],
    'front_canvas_x': runtime['boundary']['front_screen_x'],
    'front_pixel_x': front_pixel,
    'max_changed_pixel_x': int(changed_x.max()),
    'ahead_region_identical': ahead_unchanged,
    'passed': passed,
}
(folder / 'pixel-results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if passed else 1)
