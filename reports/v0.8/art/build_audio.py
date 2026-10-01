"""Original short PCM cues; no external samples, no image generation."""
from pathlib import Path
import math
import wave
import array

out = Path(__file__).resolve().parents[3] / 'assets/audio/v08'
out.mkdir(parents=True, exist_ok=True)
rate = 24000
for name, duration in [('dash_start', .105), ('dash_refill', .18)]:
    samples = array.array('h')
    phase = 0.0
    for i in range(int(rate * duration)):
        t = i / rate
        u = t / duration
        envelope = min(1.0, t / .008) * (1 - u) ** 2
        if name == 'dash_start':
            phase += 2 * math.pi * (680 - 360 * u) / rate
            value = (math.sin(phase) + .15 * math.sin(phase * 3)) * .23
        else:
            value = (math.sin(2 * math.pi * 880 * t) + .4 * math.sin(2 * math.pi * 1320 * t)) * .19
        samples.append(int(32767 * envelope * value))
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(samples.tobytes())
    print(name, len(samples), 'samples')
