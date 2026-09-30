from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image

folder = Path(__file__).resolve().parent
root = folder.parents[2]
runtime = json.loads((folder / 'lifecycle-results.json').read_text(encoding='utf-8'))
boundaries = []
for index, sample in enumerate(runtime['boundary_samples']):
    a = np.asarray(Image.open(folder / f'boundary-{index:02d}-with.png').convert('RGB'))
    b = np.asarray(Image.open(folder / f'boundary-{index:02d}-without.png').convert('RGB'))
    delta = np.max(np.abs(a.astype(int) - b.astype(int)), axis=2)
    changed_y, changed_x = np.where(delta > 0)
    pixel_front = sample['front_canvas_x'] * a.shape[1] / 960.0
    ahead_start = math.ceil(pixel_front)
    marker_absent = bool(np.max(delta[:, math.floor(pixel_front) - 2:ahead_start + 1]) == 0)
    boundaries.append({**sample, 'front_pixel_x': pixel_front, 'max_changed_pixel_x': int(changed_x.max()),
                       'ahead_identical': bool(np.max(delta[:, ahead_start:]) == 0),
                       'straight_marker_absent': marker_absent,
                       'passed': bool(changed_x.max() < ahead_start and np.max(delta[:, ahead_start:]) == 0 and marker_absent)})

frame_paths = sorted((folder / 'frames').glob('motion-*.png'))
frames = [Image.open(path).convert('RGB') for path in frame_paths]
arrays = [np.asarray(frame) for frame in frames]
wave_changes, environment_changes = [], []
for a, b in zip(arrays, arrays[1:]):
    delta = np.max(np.abs(a.astype(int) - b.astype(int)), axis=2)
    wave_changes.append(int(np.count_nonzero(delta[210:590, 595:747])))
    environment_changes.append(int(np.count_nonzero(delta[300:540, 750:1250])))
paused_a = np.asarray(Image.open(folder / 'paused-a.png').convert('RGB'))
paused_b = np.asarray(Image.open(folder / 'paused-b.png').convert('RGB'))
pause_changed = int(np.count_nonzero(np.any(paused_a != paused_b, axis=2)))
preview = [frame.resize((960, 540), Image.Resampling.LANCZOS) for frame in frames]
preview[0].save(folder / 'motion-preview.gif', save_all=True, append_images=preview[1:], duration=67, loop=0, optimize=False)
frames[12].resize((640, 360), Image.Resampling.LANCZOS).save(folder / 'pursuit-half.png')
Image.open(folder / 'wall-jump.png').resize((640, 360), Image.Resampling.LANCZOS).save(folder / 'wall-jump-half.png')
rows = []
for relative in ['scripts/visual/chase_visual.gd', 'scripts/visual/environment_visual.gd']:
    data = (root / relative).read_bytes()
    rows.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
passed = all(row['passed'] for row in boundaries) and min(wave_changes) > 500 and min(environment_changes) > 20 and pause_changed == 0
result = {'boundary_checks': boundaries, 'continuous_frames': len(frames), 'frame_interval_game_seconds': 4 / 60,
          'wave_changed_pixels_per_adjacent_pair': wave_changes,
          'environment_changed_pixels_per_adjacent_pair': environment_changes,
          'pause_changed_pixels': pause_changed, 'passed': passed,
          'method': 'Same fixed camera/front/actor. Adjacent frames prove motion. Paused paired draws isolate chase coverage from ambient movement.',
          'source_files': rows}
(folder / 'pixel-results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({'passed': passed, 'boundary_checks': len(boundaries), 'wave_min_changed_pixels': min(wave_changes),
                  'environment_min_changed_pixels': min(environment_changes), 'pause_changed_pixels': pause_changed,
                  'max_changed_x': max(row['max_changed_pixel_x'] for row in boundaries), 'front_pixel': boundaries[0]['front_pixel_x']}))
raise SystemExit(0 if passed else 1)
