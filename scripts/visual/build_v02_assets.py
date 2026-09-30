"""Deterministic Signal Collapse textures and 48 kHz prototype audio."""
from pathlib import Path
import hashlib
import json
import math
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
VIS = ROOT / "assets/visual/v02"
AUD = ROOT / "assets/audio/v02"
REPORT = ROOT / "reports/v0.2/art"
for directory in (VIS, AUD, REPORT):
    directory.mkdir(parents=True, exist_ok=True)

COLORS = {"safe": "#45DCCB", "near": "#FFD166", "urgent": "#FF685C"}


def icon(name, color, shape):
    image = Image.new("RGBA", (128, 128))
    draw = ImageDraw.Draw(image)
    if shape == "safe":
        draw.line([(24, 64), (50, 88), (104, 32)], fill=color, width=14, joint="curve")
    elif shape == "near":
        draw.rounded_rectangle((26, 28, 48, 100), 6, fill=color)
        draw.rounded_rectangle((78, 28, 100, 100), 6, fill=color)
    elif shape == "urgent":
        draw.polygon([(64, 12), (118, 112), (10, 112)], fill=color)
        draw.rounded_rectangle((58, 43, 70, 78), 4, fill="#18212B")
        draw.ellipse((58, 89, 70, 101), fill="#18212B")
    elif shape == "spike":
        draw.polygon([(12, 110), (32, 28), (52, 110), (76, 16), (100, 110)], fill=color)
    elif shape == "fall":
        draw.rounded_rectangle((53, 16, 75, 74), 4, fill=color)
        draw.polygon([(24, 65), (104, 65), (64, 113)], fill=color)
    elif shape == "caught":
        draw.rectangle((15, 18, 113, 110), outline=color, width=9)
        for x, y, w in [(18, 30, 70), (44, 52, 68), (16, 78, 79)]:
            draw.rectangle((x, y, x + w, y + 12), fill=color)
        draw.rectangle((52, 18, 65, 113), fill="#18212B")
    image.resize((32, 32), Image.Resampling.LANCZOS).save(VIS / (name + ".png"))


for grade in COLORS:
    icon("warning_" + grade, COLORS[grade], grade)
for reason, shape in [("spike", "spike"), ("fall", "fall"), ("caught", "caught")]:
    icon("failure_" + reason, "#FF685C", shape)

# Both patterns stay behind the exact leading edge. No texture paints ahead.
front = Image.new("RGBA", (32, 128))
draw = ImageDraw.Draw(front)
draw.rectangle((30, 0, 31, 127), fill=(255, 104, 92, 255))
for y, width in [(4, 20), (24, 11), (43, 26), (64, 16), (91, 23), (113, 9)]:
    draw.rectangle((31 - width, y, 29, y + 5), fill=(255, 104, 92, 90))
    draw.rectangle((25, y + 8, 29, y + 10), fill=(255, 209, 102, 70))
front.save(VIS / "collapse_front.png")
cover = Image.new("RGBA", (128, 128), (9, 17, 24, 145))
draw = ImageDraw.Draw(cover)
for x, y, width in [(0, 12, 86), (46, 31, 82), (9, 57, 54), (0, 84, 112), (69, 106, 59)]:
    draw.rectangle((x, y, x + width, y + 3), fill=(56, 80, 94, 110))
draw.line([(18, 0), (18, 128)], fill=(23, 39, 50, 80))
cover.save(VIS / "collapse_cover.png")

RATE = 48000
metrics = {}


def save_sound(name, signal, peak_db):
    signal = np.asarray(signal, dtype=np.float64)
    signal -= signal.mean()
    signal *= 10 ** (peak_db / 20) / max(1e-9, np.max(np.abs(signal)))
    pcm = np.rint(np.clip(signal, -1, 1) * 32767).astype("<i2")
    path = AUD / (name + ".wav")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    metrics[name] = {"duration_s": len(pcm) / RATE, "peak_dbfs": round(20 * math.log10(np.max(np.abs(pcm)) / 32768), 2),
                     "rms_dbfs": round(20 * math.log10(np.sqrt(np.mean((pcm.astype(float) / 32768) ** 2))), 2),
                     "sample_rate_hz": RATE, "channels": 1}


t = np.arange(RATE * 2) / RATE
loop = (0.62 * np.sin(2 * np.pi * 65 * t) + 0.25 * np.sin(2 * np.pi * 130 * t)
        + 0.10 * np.sin(2 * np.pi * 195 * t)) * (0.84 + 0.16 * np.cos(2 * np.pi * t))
save_sound("threat_loop", loop, -12)
metrics["threat_loop"]["loop_seam_delta"] = float(abs(loop[-1] - loop[0]))

for name, seconds, start, end in [("warning_near", .20, 310, 390), ("warning_urgent", .24, 440, 570)]:
    t = np.arange(round(RATE * seconds)) / RATE
    p = t / seconds
    envelope = np.minimum(1, p / .06) * np.minimum(1, (1 - p) / .35)
    phase = 2 * np.pi * (start * t + (end - start) * t * p / 2)
    save_sound(name, envelope * (np.sin(phase) + .12 * np.sin(2 * phase)), -7)

t = np.arange(round(RATE * .46)) / RATE
p = t / .46
envelope = np.minimum(1, p / .025) * (1 - p) ** 1.5
rng = np.random.default_rng(27)
noise = np.convolve(rng.uniform(-1, 1, len(t)), np.ones(14) / 14, mode="same")
phase = 2 * np.pi * (210 * t - 150 * t * p / 2)
save_sound("caught", envelope * (.78 * np.sin(phase) + .22 * noise), -4)

files = []
for path in sorted(list(VIS.glob("*.png")) + list(AUD.glob("*.wav"))):
    record = {"path": str(path.relative_to(ROOT)).replace("\\", "/"), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
    if path.suffix == ".png":
        record["dimensions"] = list(Image.open(path).size)
    files.append(record)
(REPORT / "assets.json").write_text(json.dumps({"files": files, "audio": metrics}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Built {len(list(VIS.glob('*.png')))} textures and {len(metrics)} audio streams")
