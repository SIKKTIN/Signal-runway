"""Extend the established geometric icon system; deterministic PNG/WAV assets."""
from pathlib import Path
import hashlib
import json
import math
import wave

import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
visual = root / 'assets/visual/relay'
audio = root / 'assets/audio/relay'
report = root / 'reports/v0.3/art'
for folder in (visual, audio, report):
    folder.mkdir(parents=True, exist_ok=True)
scale = 4
gold, dark = '#FFD166', '#18212B'
for state in ['available', 'activating', 'activated']:
    image = Image.new('RGBA', (192, 192))
    draw = ImageDraw.Draw(image)
    color = gold if state != 'activated' else '#A38D57'
    if state == 'available':
        for start in [12, 102, 192, 282]:
            draw.arc((16, 16, 176, 176), start, start + 60, fill=color, width=8)
        draw.rounded_rectangle((65, 64, 127, 129), 8, fill=dark, outline=color, width=8)
        for x in [82, 106]:
            draw.line((x, 42, x, 67), fill=color, width=8)
        draw.line((80, 99, 112, 99), fill=color, width=7)
        draw.line((96, 83, 96, 115), fill=color, width=7)
    elif state == 'activating':
        draw.ellipse((13, 13, 179, 179), outline='#FFECC5', width=10)
        draw.rounded_rectangle((64, 64, 128, 130), 8, fill=gold, outline='#FFECC5', width=6)
        for x in [81, 106]:
            draw.line((x, 41, x, 64), fill='#FFECC5', width=8)
        draw.line((78, 98, 111, 98), fill=dark, width=8)
        draw.line((95, 82, 95, 115), fill=dark, width=8)
    else:
        draw.ellipse((16, 16, 176, 176), outline=color, width=7)
        draw.rounded_rectangle((64, 61, 129, 130), 8, fill=dark, outline=color, width=7)
        draw.line([(78, 100), (93, 115), (119, 80)], fill=color, width=9, joint='curve')
    image.resize((48, 48), Image.Resampling.LANCZOS).save(visual / f'relay_{state}.png')

rate = 48000
t = np.arange(round(0.30 * rate)) / rate
signal = np.zeros_like(t)
for start, frequency in [(0.0, 523.251), (0.065, 783.991), (0.13, 1046.502)]:
    dt = t - start
    envelope = np.where(dt >= 0, (1 - np.exp(-np.maximum(dt, 0) * 350)) * np.exp(-np.maximum(dt, 0) * 23), 0)
    signal += envelope * (np.sin(2 * math.pi * frequency * dt) + 0.13 * np.sin(4 * math.pi * frequency * dt))
signal *= np.clip((0.30 - t) / 0.025, 0, 1)
signal *= 10 ** (-8 / 20) / np.max(np.abs(signal))
pcm = np.rint(signal * 32767).astype('<i2')
with wave.open(str(audio / 'relay_connect.wav'), 'wb') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(rate)
    wav.writeframes(pcm.tobytes())
rows = []
for file in sorted(visual.glob('*.png')):
    rows.append({'path': file.relative_to(root).as_posix(), 'size': [48, 48], 'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
file = audio / 'relay_connect.wav'
rows.append({'path': file.relative_to(root).as_posix(), 'sample_rate': rate, 'channels': 1, 'bits': 16, 'seconds': 0.30,
             'peak_dbfs': float(20 * np.log10(np.max(np.abs(pcm.astype(float))) / 32767)),
             'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
(report / 'relay-assets.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(json.dumps({'images': 3, 'sounds': 1, 'report': 'reports/v0.3/art/relay-assets.json'}))
