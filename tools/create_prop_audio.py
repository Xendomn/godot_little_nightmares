"""Deterministic original mechanical Foley; no external recordings."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050

def write(name, seconds, sample):
    rng = random.Random(260906)
    samples = []
    for i in range(int(RATE * seconds)):
        value = sample(i / RATE, rng)
        samples.append(struct.pack('<h', int(max(-1, min(1, value)) * 27000)))
    with wave.open(str(ROOT / 'assets/audio' / ('prop_' + name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(samples))

write('bell', 2.4, lambda t, r: sum(math.sin(2 * math.pi * 540 * ratio * t) * math.exp(-t * decay) * gain for ratio, decay, gain in [(1, 2, .35), (2.71, 3, .17), (4.07, 4, .09), (5.43, 6, .04)]) * min(1, t * 500))
write('valve', 1.1, lambda t, r: (r.uniform(-1, 1) * .20 + math.sin(t * 670 + math.sin(t * 28) * 4) * .10) * math.sin(math.pi * min(1, t / 1.1)) ** 2)
write('ratchet', .9, lambda t, r: (r.uniform(-1, 1) * .32 + math.sin(t * 2400) * .13) * math.exp(-(t % .095) * 100) * max(0, 1 - t / .9))
print('Created 3 original mechanical Foley WAVs')
