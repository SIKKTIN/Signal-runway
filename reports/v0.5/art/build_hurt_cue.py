from pathlib import Path
import math
import struct
import wave

root = Path(__file__).resolve().parents[3]
target = root / 'assets/audio/v05/hurt_tick.wav'
target.parent.mkdir(parents=True, exist_ok=True)
rate = 48000
duration = .16
signal = []
for index in range(int(rate * duration)):
    time = index / rate
    envelope = min(1, time / .008) * (1 - time / duration) ** 2
    phase = 2 * math.pi * (260 * time - 450 * time * time)
    signal.append(envelope * (math.sin(phase) + .16 * math.sin(2.2 * phase)))
peak = max(map(abs, signal))
amplitude = 10 ** (-14 / 20)
samples = [round(sample / peak * amplitude * 32767) for sample in signal]
with wave.open(str(target), 'wb') as stream:
    stream.setnchannels(1)
    stream.setsampwidth(2)
    stream.setframerate(rate)
    stream.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print({'path': str(target.relative_to(root)), 'duration': duration, 'rate': rate, 'peak_dbfs': -14})
