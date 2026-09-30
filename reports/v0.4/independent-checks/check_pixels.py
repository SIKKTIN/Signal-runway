from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
result = {}
for prefix, suffixes in [('pause', ['a', 'b']), ('rebase', ['before', 'after'])]:
    a = np.asarray(Image.open(folder / f'{prefix}-{suffixes[0]}.png').convert('RGB'))
    b = np.asarray(Image.open(folder / f'{prefix}-{suffixes[1]}.png').convert('RGB'))
    delta = np.abs(a.astype(int) - b.astype(int))
    result[prefix] = {'changed_pixels': int(np.count_nonzero(np.any(delta, axis=2))),
                      'changed_fraction': float(np.count_nonzero(np.any(delta, axis=2)) / (a.shape[0] * a.shape[1])),
                      'max_channel_delta': int(delta.max())}
for name in ['menu', 'relay', 'result', 'catchup-delay', 'fixed-entry', 'rebase-before']:
    image = Image.open(folder / (name + '.png')).convert('RGB')
    image.resize((640, 360), Image.Resampling.LANCZOS).save(folder / (name + '-half.png'))
    image.convert('L').save(folder / (name + '-gray.png'))
frames = [Image.open(p).convert('RGB').resize((960, 540), Image.Resampling.LANCZOS) for p in sorted((folder / 'frames').glob('*.png'))]
result['continuous_frame_changed_pixels'] = [int(np.count_nonzero(np.any(np.asarray(a) != np.asarray(b), axis=2))) for a, b in zip(frames, frames[1:])]
frames[0].save(folder / 'dynamic-preview.gif', save_all=True, append_images=frames[1:], duration=67, loop=0, optimize=False)
result['passed'] = result['pause']['changed_pixels'] == 0 and result['rebase']['max_channel_delta'] <= 8 and result['rebase']['changed_fraction'] < .01 and min(result['continuous_frame_changed_pixels']) > 0
result['pause_passed'] = result['pause']['changed_pixels'] == 0
result['animation_passed'] = min(result['continuous_frame_changed_pixels']) > 0
result['rebase_strict_8_color_level_gate_passed'] = result['rebase']['max_channel_delta'] <= 8
result['rebase_pixels_over_8'] = int(np.count_nonzero(np.any(delta > 8, axis=2)))
result['note'] = 'Strict color gate is retained even when logical anchors and visual continuity pass; producer must review the observed sparse AA differences.'
result['checks_source_sha256'] = hashlib.sha256((folder / 'check_runtime.gd').read_bytes()).hexdigest()
(folder / 'pixels.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
raise SystemExit(0 if result['passed'] else 1)
