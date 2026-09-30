from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
results = {}
for pair in ['pause', 'rebase']:
    suffixes = ['a', 'b'] if pair == 'pause' else ['before', 'after']
    a = np.asarray(Image.open(folder / f'f-{pair}-{suffixes[0]}.png').convert('RGB'))
    b = np.asarray(Image.open(folder / f'f-{pair}-{suffixes[1]}.png').convert('RGB'))
    diff = np.abs(a.astype(int) - b.astype(int))
    results[pair + '_changed_pixels'] = int(np.count_nonzero(np.any(diff, axis=2)))
    results[pair + '_max_channel_delta'] = int(diff.max())
for name in ['running', 'catchup', 'catchup-delay', 'result', 'fixed-station', 'rebase-before', 'relay-available', 'relay-activating', 'relay-activated']:
    im = Image.open(folder / f'f-{name}.png').convert('RGB')
    im.resize((640, 360), Image.Resampling.LANCZOS).save(folder / f'f-{name}-half.png')
    im.convert('L').save(folder / f'f-{name}-gray.png')
frames = [Image.open(p).convert('RGB').resize((960, 540), Image.Resampling.LANCZOS) for p in sorted((folder / 'f-frames').glob('*.png'))]
results['frame_changed_pixels'] = [int(np.count_nonzero(np.any(np.asarray(a) != np.asarray(b), axis=2))) for a, b in zip(frames, frames[1:])]
frames[0].save(folder / 'f-preview.gif', save_all=True, append_images=frames[1:], duration=67, loop=0, optimize=False)
sources = ['scripts/visual/' + name + '.gd' for name in ['endless_world_visual', 'endless_module_visual', 'endless_hud_visual', 'environment_visual', 'relay_visual', 'chase_visual']]
results['sources'] = [{'path': p, 'sha256': hashlib.sha256((root / p).read_bytes()).hexdigest()} for p in sources]
results['rebase_changed_fraction'] = results['rebase_changed_pixels'] / (a.shape[0] * a.shape[1])
# World-coordinate AA can vary by a few color levels after reducing float32
# magnitudes. Accept <=8/255 on <1% of pixels; logical anchors are checked
# independently in the runtime fixture. Do not report an identical image.
results['passed'] = results['pause_changed_pixels'] == 0 and results['rebase_max_channel_delta'] <= 8 and results['rebase_changed_fraction'] < 0.01 and min(results['frame_changed_pixels']) > 0
(folder / 'f-pixels.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
print(json.dumps(results))
raise SystemExit(0 if results['passed'] else 1)
