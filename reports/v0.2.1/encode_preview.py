"""Encode Godot-rendered frames and check visible motion/pause, no input-art edits."""
from pathlib import Path
from PIL import Image, ImageChops
import json

here = Path(__file__).resolve().parent
frames = [Image.open(p).convert('RGB') for p in sorted((here / 'frames').glob('frame-*.png'))]
if not frames:
    raise SystemExit('No rendered frames')

def changed(a, b, box=None):
    if box:
        a, b = a.crop(box), b.crop(box)
    return sum(pixel != (0, 0, 0) for pixel in ImageChops.difference(a, b).getdata())

# The fixed fixture front is world x=310, with viewport/camera centre=480.
# Canvas stretch may produce a larger render texture; use the logical ratios.
width, height = frames[0].size
sx, sy = width / 960, height / 540
wave_box = (0, int(220 * sy), int(310 * sx), int(410 * sy))
environment_box = (int(370 * sx), int(225 * sy), int(660 * sx), int(410 * sy))
pause_a = Image.open(here / 'pause-a.png').convert('RGB')
pause_b = Image.open(here / 'pause-b.png').convert('RGB')
result = {
    'frame_count': len(frames), 'render_size': [width, height],
    'wave_changed_pixels': changed(frames[0], frames[15], wave_box),
    'environment_changed_pixels': changed(frames[0], frames[15], environment_box),
    'pause_changed_pixels': changed(pause_a, pause_b),
    'scope': 'GPU frame differences at a fixed front/camera; no player experience conclusion'
}
result['passed'] = result['wave_changed_pixels'] > 100 and result['environment_changed_pixels'] > 30 and result['pause_changed_pixels'] == 0
(here / 'pixel-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
preview = [im.resize((720, 405), Image.Resampling.LANCZOS) for im in frames]
preview[0].save(here / 'motion-preview.gif', save_all=True, append_images=preview[1:], duration=67, loop=0, optimize=False)
print(json.dumps(result, ensure_ascii=False))
if not result['passed']:
    raise SystemExit(1)
