"""Build the deterministic Signal Run v0.1 prototype art and SFX."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
VISUAL = ROOT / "assets" / "visual"
AUDIO = ROOT / "assets" / "audio"
SCALE = 4

INK = "#18212B"
STRUCTURE = "#334554"
STRUCTURE_LIGHT = "#456070"
SAFE = "#E6EFED"
CYAN = "#45DCCB"
CYAN_LIGHT = "#A7FAEC"
CORAL = "#FF685C"
CORAL_LIGHT = "#FFB0A8"
GOLD = "#FFD166"
GOLD_LIGHT = "#FFF0B0"


class Tile:
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.image = Image.new("RGBA", (width * SCALE, height * SCALE), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)

    def rect(self, box, fill, radius=0, outline=None, width=1):
        x1, y1, x2, y2 = box
        xy = (round(x1 * SCALE), round(y1 * SCALE), round(x2 * SCALE), round(y2 * SCALE))
        if radius:
            self.draw.rounded_rectangle(xy, radius=round(radius * SCALE), fill=fill,
                                        outline=outline, width=width * SCALE)
        else:
            self.draw.rectangle(xy, fill=fill, outline=outline, width=width * SCALE)

    def poly(self, points, fill):
        self.draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)

    def line(self, points, fill, width=1):
        self.draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points],
                       fill=fill, width=max(1, round(width * SCALE)), joint="curve")

    def ellipse(self, box, fill):
        x1, y1, x2, y2 = box
        self.draw.ellipse((round(x1 * SCALE), round(y1 * SCALE),
                           round(x2 * SCALE), round(y2 * SCALE)), fill=fill)

    def save(self, name: str):
        path = VISUAL / name
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image.resize((self.width, self.height), Image.Resampling.LANCZOS).save(path)
        return path


def make_player(state: str):
    t = Tile(24, 32)
    # Each frame uses the same center anchor (12, 16), so swapping states does
    # not move the collision or the character's visual center.
    if state == "dead":
        t.rect((3, 15, 21, 24), CYAN, radius=4)
        t.rect((6, 17, 10, 19), CORAL, radius=1)
        t.line([(15, 17), (19, 21)], CORAL, 1.5)
        t.line([(19, 17), (15, 21)], CORAL, 1.5)
        t.line([(4, 25), (20, 25)], CYAN_LIGHT, 1)
    else:
        if state == "land":
            body = (3, 13, 21, 27)
            head = (5, 5, 19, 17)
        elif state == "wall_slide":
            body = (5, 15, 19, 27)
            head = (5, 3, 19, 17)
        else:
            body = (5, 14, 19, 26)
            head = (5, 3, 19, 17)
        t.rect(body, CYAN, radius=4)
        t.rect(head, CYAN, radius=5)
        t.rect((7, 4, 10, 13), CYAN_LIGHT, radius=1)
        t.rect((16, 9, 19, 12), INK, radius=1)
        t.line([(4, 19), (4, 24)], CYAN_LIGHT, 1)

        if state == "run_0":
            t.poly([(8, 24), (12, 24), (9, 31), (3, 31), (3, 29)], CYAN)
            t.poly([(15, 24), (19, 25), (23, 29), (21, 31), (14, 28)], CYAN)
        elif state == "run_1":
            t.poly([(8, 24), (12, 24), (4, 29), (2, 28), (4, 26)], CYAN)
            t.poly([(15, 24), (19, 24), (18, 31), (12, 31), (12, 29)], CYAN)
        elif state in {"rise", "jump", "wall_jump"}:
            t.poly([(7, 24), (12, 24), (10, 28), (7, 28)], CYAN)
            t.poly([(15, 24), (19, 24), (21, 28), (17, 28)], CYAN)
            t.poly([(1, 18), (5, 17), (4, 23), (1, 21)], CYAN_LIGHT)
        elif state == "fall":
            t.poly([(7, 24), (11, 24), (9, 30), (5, 28)], CYAN)
            t.poly([(15, 24), (19, 24), (21, 28), (17, 30)], CYAN)
            t.line([(2, 19), (2, 25)], CYAN_LIGHT, 2)
        elif state == "wall_slide":
            t.poly([(7, 24), (12, 24), (7, 30), (4, 29)], CYAN)
            t.poly([(16, 24), (20, 24), (22, 28), (19, 30)], CYAN)
            t.line([(19, 18), (23, 17)], CYAN_LIGHT, 2)
        elif state == "land":
            t.poly([(5, 25), (11, 25), (10, 30), (3, 30)], CYAN)
            t.poly([(14, 25), (20, 25), (22, 30), (15, 30)], CYAN)
        elif state == "finish":
            t.poly([(7, 24), (11, 24), (9, 31), (5, 31)], CYAN)
            t.poly([(16, 24), (20, 24), (21, 31), (17, 31)], CYAN)
            t.line([(19, 17), (22, 11)], GOLD_LIGHT, 2)
        else:  # idle
            t.poly([(7, 24), (12, 24), (11, 31), (5, 31)], CYAN)
            t.poly([(15, 24), (19, 24), (21, 31), (15, 31)], CYAN)
    t.save(f"player_{state}_0.png")


def make_terrain():
    tile = Tile(32, 32)
    tile.rect((0, 4, 32, 32), STRUCTURE)
    tile.rect((0, 0, 32, 5), SAFE)
    tile.rect((0, 5, 32, 8), STRUCTURE_LIGHT)
    tile.line([(3, 17), (29, 17)], "#3B5060", 1)
    tile.line([(8, 25), (8, 31)], "#263846", 1)
    tile.save("terrain_platform.png")

    wall = Tile(32, 32)
    wall.rect((0, 0, 32, 32), STRUCTURE)
    wall.rect((0, 0, 5, 32), SAFE)
    wall.rect((5, 0, 8, 32), STRUCTURE_LIGHT)
    for y in (6, 18, 30):
        wall.line([(13, y), (24, y)], "#5C7281", 1)
    wall.save("terrain_wall_left.png")
    wall.image = wall.image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    wall.save("terrain_wall_right.png")

    block = Tile(32, 32)
    block.rect((0, 0, 32, 32), STRUCTURE)
    block.line([(4, 4), (28, 4)], "#435B6A", 1)
    block.line([(4, 28), (28, 28)], "#263846", 1)
    block.save("terrain_solid.png")


def make_spike():
    t = Tile(32, 32)
    t.rect((0, 27, 32, 32), CORAL)
    t.rect((0, 30, 32, 32), CORAL_LIGHT)
    for x in (0, 10, 20):
        t.poly([(x, 27), (x + 5, 3), (x + 10, 27)], CORAL)
        t.line([(x + 2, 24), (x + 5, 10)], CORAL_LIGHT, 1)
    t.save("hazard_spike_up.png")
    t.image = t.image.transpose(Image.Transpose.ROTATE_90)
    t.save("hazard_spike_left.png")
    t.image = t.image.transpose(Image.Transpose.ROTATE_180)
    t.save("hazard_spike_right.png")


def make_goal():
    t = Tile(48, 96)
    t.rect((5, 4, 43, 95), GOLD, radius=4)
    t.rect((11, 11, 37, 94), (0, 0, 0, 0), radius=2)
    # Erase the inside explicitly; the frame is a recognizable vertical gate.
    t.rect((11, 11, 37, 95), (0, 0, 0, 0))
    t.rect((5, 4, 43, 12), GOLD_LIGHT, radius=3)
    t.poly([(17, 22), (32, 22), (32, 32), (24, 32), (24, 39), (17, 39)], GOLD)
    t.poly([(19, 25), (29, 25), (24, 30)], INK)
    t.rect((0, 91, 48, 96), GOLD)
    t.save("goal_gate.png")


def make_background():
    t = Tile(960, 540)
    t.rect((0, 0, 960, 540), INK)
    for x, h in [(34, 190), (175, 248), (344, 161), (485, 230), (658, 188), (820, 260)]:
        top = 540 - h
        t.rect((x, top, x + 72, 540), "#253440")
        t.line([(x + 12, top + 19), (x + 54, top + 92)], "#304350", 2)
        t.line([(x + 58, top + 19), (x + 15, top + 92)], "#304350", 2)
        t.rect((x + 22, top + 112, x + 32, top + 124), "#314554")
    for x, y in [(135, 158), (405, 104), (738, 140)]:
        t.poly([(x, y), (x + 18, y + 9), (x, y + 18)], "#35505A")
        t.line([(x + 26, y + 9), (x + 58, y + 9)], "#35505A", 2)
    t.save("background_industrial.png")


def make_ui_icons():
    clock = Tile(24, 24)
    clock.ellipse((2, 2, 22, 22), SAFE)
    clock.ellipse((5, 5, 19, 19), INK)
    clock.line([(12, 6), (12, 12), (17, 15)], SAFE, 2)
    clock.save("ui_clock.png")
    death = Tile(24, 24)
    death.poly([(3, 18), (7, 5), (12, 15), (17, 5), (21, 18)], CORAL)
    death.rect((3, 18, 21, 22), CORAL)
    death.save("ui_deaths.png")
    flag = Tile(24, 24)
    flag.line([(5, 2), (5, 22)], GOLD, 2)
    flag.poly([(7, 2), (20, 2), (16, 9), (20, 16), (7, 16)], GOLD)
    flag.save("ui_finish.png")


def synth(name: str, seconds: float, voice):
    rate = 48000
    rng = random.Random(name)
    samples = []
    previous_noise = 0.0
    for i in range(round(rate * seconds)):
        time = i / rate
        progress = time / seconds
        noise = rng.uniform(-1.0, 1.0)
        previous_noise = 0.82 * previous_noise + 0.18 * noise
        samples.append(voice(time, progress, previous_noise))
    peak = max(abs(v) for v in samples) or 1.0
    gain = 0.7 / peak  # -3.1 dBFS peak; leave room for rapid repeats.
    path = AUDIO / f"sfx_{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(b"".join(struct.pack("<h", round(max(-1.0, min(1.0, v * gain)) * 32767)) for v in samples))
    return path


def envelope(p, attack=0.03, release=0.25):
    return min(1.0, p / attack) * min(1.0, (1.0 - p) / release)


def make_audio():
    synth("jump", 0.18, lambda t, p, n:
          envelope(p) * (0.7 * math.sin(2 * math.pi * (390 * t + 390 * t * p / 2)) + 0.15 * n))
    synth("wall_jump", 0.22, lambda t, p, n:
          envelope(p, 0.02, 0.32) * (0.55 * math.sin(2 * math.pi * (330 * t + 260 * t * p / 2))
                                     + 0.18 * math.sin(2 * math.pi * 660 * t) + 0.13 * n))
    synth("land", 0.13, lambda t, p, n:
          math.exp(-9 * p) * (0.65 * math.sin(2 * math.pi * (135 - 60 * p) * t) + 0.35 * n))
    synth("death", 0.30, lambda t, p, n:
          envelope(p, 0.01, 0.4) * (0.65 * math.sin(2 * math.pi * (280 - 195 * p) * t) + 0.2 * n))

    def finish(t, p, n):
        notes = [(0.0, 523.25), (0.16, 659.25), (0.32, 783.99)]
        result = 0.0
        for start, hz in notes:
            q = t - start
            if 0 <= q <= 0.25:
                env = min(1.0, q / 0.018) * math.exp(-8 * q)
                result += env * (math.sin(2 * math.pi * hz * q) + 0.2 * math.sin(2 * math.pi * 2 * hz * q))
        return result

    synth("finish", 0.62, finish)


def main():
    for state in ["idle", "run_0", "run_1", "rise", "fall", "wall_slide", "jump", "wall_jump", "land", "dead", "finish"]:
        make_player(state)
    make_terrain()
    make_spike()
    make_goal()
    make_background()
    make_ui_icons()
    make_audio()
    print(f"Generated {len(list(VISUAL.glob('*.png')))} PNG and {len(list(AUDIO.glob('*.wav')))} WAV files")


if __name__ == "__main__":
    main()
