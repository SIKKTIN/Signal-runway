"""Record measurable properties of the five prototype sound effects."""

import json
import math
import wave
from pathlib import Path

import numpy as np


root = Path(__file__).resolve().parents[2]
metrics = {}
for path in sorted((root / "assets" / "audio").glob("sfx_*.wav")):
    with wave.open(str(path), "rb") as wav:
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
        peak = float(np.max(np.abs(samples)))
        rms = float(np.sqrt(np.mean(samples * samples)))
        metrics[path.name] = {
            "sample_rate_hz": wav.getframerate(),
            "channels": wav.getnchannels(),
            "duration_s": round(len(samples) / wav.getframerate(), 3),
            "peak_dbfs": round(20 * math.log10(peak), 2),
            "rms_dbfs": round(20 * math.log10(rms), 2),
        }
output = root / "reports" / "v0.1" / "art" / "audio_metrics.json"
output.write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(metrics, ensure_ascii=False))
