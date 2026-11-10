"""Generate the repository's original replacement effects (Python stdlib only)."""

from array import array
from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
import sys
import wave

RATE = 24000
OUT = Path(__file__).resolve().parents[1] / "assets/audio/public_effects"


def emit(name, duration, parts):
    count = round(duration * RATE)
    samples = [0.0] * count
    for start, sound in parts:
        first = round(start * RATE)
        for n, value in enumerate(sound):
            if first + n >= count:
                break
            samples[first + n] += value
    pcm = array("h", (round(25000 * tanh(sample)) for sample in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as file:
        file.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        file.writeframes(pcm.tobytes())


def breath(seed, duration, pitch, gain):
    random = Random(seed)
    phase = low = air = 0.0
    for n in range(round(duration * RATE)):
        t = n / RATE
        u = t / duration
        pulse = 0.81 + 0.19 * sin(2 * pi * (4.2 * t + 0.22 * sin(15 * t)))
        envelope = sin(pi * u) ** 1.4 * pulse
        phase += 2 * pi * pitch * (0.88 + 0.15 * sin(pi * u) - 0.10 * u + 0.014 * sin(26 * t)) / RATE
        hiss = random.uniform(-1, 1)
        low += 0.035 * (hiss - low)
        air += 0.22 * (hiss - air)
        tone = 0.45 * sin(phase) + 0.23 * sin(2 * phase) + 0.13 * sin(3 * phase) + 0.05 * sin(5 * phase)
        yield envelope * gain * (tone * (0.52 + 0.39 * sin(pi * u)) + 0.75 * (air - low))


def impact(seed, pitch, duration, gain):
    random = Random(seed)
    low = 0.0
    for n in range(round(duration * RATE)):
        t = n / RATE
        noise = random.uniform(-1, 1)
        low += 0.08 * (noise - low)
        thump = sin(2 * pi * pitch * t) * exp(-25 * t)
        click = (noise - low) * exp(-113 * t)
        ring = sin(2 * pi * pitch * 3.4 * t) * exp(-40 * t)
        yield gain * min(1.0, 500 * t) * (0.56 * thump + 0.57 * click + 0.14 * ring + 0.35 * low * exp(-14 * t))


def hinge(seed, duration, gain):
    random = Random(seed)
    phase = low = 0.0
    for n in range(round(duration * RATE)):
        t = n / RATE
        u = t / duration
        low += 0.12 * (random.uniform(-1, 1) - low)
        phase += 2 * pi * (109 + 85 * sin(pi * u) + 19 * sin(t * 17)) / RATE
        grit = 0.48 + 0.28 * sin(t * 31) + 0.21 * sin(t * 53)
        yield gain * (sin(pi * u) ** 1.3) * grit * (0.41 * sin(phase) + 0.17 * sin(phase * 2.31) + 0.84 * low)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    emit("hall_sob", 12.0, [
        (0.24, breath(200, 1.28, 218, 0.66)), (1.8, breath(201, 0.68, 194, 0.38)),
        (2.8, breath(202, 1.71, 231, 0.60)), (4.94, breath(203, 1.04, 203, 0.43)),
        (6.4, breath(204, 1.77, 222, 0.52)), (8.55, breath(205, 0.73, 193, 0.37)),
        (9.61, breath(206, 1.78, 212, 0.40)),
    ])
    for name, seconds, pitch in [("sob_close", 1.23, 219), ("sob_between", 1.65, 230),
                                 ("sob_last", 1.12, 201), ("beam_sob", 2.56, 213)]:
        emit(name, seconds, [(0.06, breath(pitch, seconds * 0.70, pitch, 0.52)),
                             (seconds * 0.77, breath(pitch + 2, seconds * 0.20, pitch - 17, 0.32))])
    timings = [1.72, 2.90, 4.17, 5.12, 6.29, 7.25, 8.29, 9.23, 10.05, 10.96, 11.82, 12.80, 13.70]
    parts = []
    for i, start in enumerate(timings):
        gain = (0.42 + 0.041 * i) * (0.9 if i % 2 else 1.0)
        parts.append((start, impact(500 + i, 118 + (i % 4) * 13, 0.38, gain)))
        parts.append((start + 0.078, impact(600 + i, 93, 0.25, gain * 0.32)))
    emit("corridor_footsteps", 14.69, parts)
    emit("door_push", 1.48, [(0.04, hinge(713, 1.21, 1.30)), (1.02, impact(714, 97, 0.35, 0.45))])
    emit("hinge_open", 1.25, [(0.03, hinge(715, 1.18, 1.25))])
    emit("hinge_close", 1.42, [(0.02, hinge(716, 1.38, 1.18))])
    emit("door_seat", 0.48, [(0.02, impact(717, 81, 0.45, 0.7))])


if __name__ == "__main__":
    main()
