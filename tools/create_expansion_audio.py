"""Original synthesized audio, deterministic and redistributable with this project."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'

def write(name, duration, sample):
    rng = random.Random(2609)
    values = []
    count = int(RATE * duration)
    for i in range(count):
        t = i / RATE
        # Seam-safe short fade keeps looping ambience free of clicks.
        envelope = min(1, t / .15, (duration - t) / .15)
        value = max(-.9, min(.9, sample(t, rng))) * envelope
        values.append(struct.pack('<h', int(value * 32767)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(b''.join(values))

def ambient(kind):
    def sample(t, rng):
        drone = .10 * math.sin(math.tau * 43 * t) + .05 * math.sin(math.tau * 64 * t)
        if kind == 'laundry':
            return drone + .13 * rng.uniform(-1, 1) * (.6 + .4 * math.sin(math.tau * .5 * t))
        if kind == 'thread_vault':
            return drone * .5 + .045 * math.sin(math.tau * (310 + 6 * math.sin(t)) * t) + .035 * rng.uniform(-1, 1)
        tick = math.exp(-32 * (t % 1))
        return drone + tick * (.25 * math.sin(math.tau * 380 * t) + .1 * rng.uniform(-1, 1))
    return sample

for chapter in ['laundry', 'thread_vault', 'clocktower']:
    write(chapter + '_ambient', 12, ambient(chapter))
write('keeper_breath', 6, lambda t, r: (.15 * r.uniform(-1, 1) + .04 * math.sin(math.tau * 90 * t)) * max(0, math.sin(math.tau * t / 3)) ** 2)
write('keeper_step', .7, lambda t, r: (.4 * math.sin(math.tau * 58 * t) + .16 * r.uniform(-1, 1)) * math.exp(-7 * t))
write('keeper_cloth', 1.1, lambda t, r: .12 * r.uniform(-1, 1) * math.sin(math.pi * t / 1.1) ** 2)
print('Generated 6 original expansion sounds')
