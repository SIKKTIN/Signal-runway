from pathlib import Path
import json
import wave

import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[3]
folder = Path(__file__).resolve().parent
safe = np.asarray(Image.open(folder / "safe.png").convert("RGB"))
urgent_image = Image.open(folder / "urgent.png").convert("RGB")
urgent = np.asarray(urgent_image)
delta = np.max(np.abs(safe.astype(int) - urgent.astype(int)), axis=2)
# Exclude HUD and metadata; compare the actual player/landing region ahead.
ahead = delta[300:650, 720:]
changed_x = np.where(delta[300:550] > 0)[1]
urgent_image.convert("L").save(folder / "urgent_grayscale.png")
urgent_image.resize((640, 360), Image.Resampling.LANCZOS).save(folder / "urgent_half.png")
with wave.open(str(root / "assets/audio/v02/threat_loop.wav"), "rb") as wav:
    samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(float)
seam = abs(samples[0] - samples[-1])
adjacent = float(np.max(np.abs(np.diff(samples))))
result = {
    "front_world_x": 540,
    "front_screen_x": 720,
    "ahead_region_unchanged": bool(np.max(ahead) == 0),
    "max_changed_x_below_hud": int(np.max(changed_x)),
    "front_does_not_extend_ahead": bool(np.max(changed_x) < 720),
    "loop_seam_delta_pcm": seam,
    "max_adjacent_delta_pcm": adjacent,
    "loop_seam_within_normal_wave_slope": bool(seam <= adjacent),
}
(folder / "frame-check.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result))
raise SystemExit(0 if result["ahead_region_unchanged"] and result["front_does_not_extend_ahead"] and result["loop_seam_within_normal_wave_slope"] else 1)
