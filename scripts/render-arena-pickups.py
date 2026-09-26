import math
import pathlib
import random
import struct
import wave

root = pathlib.Path(__file__).resolve().parents[1]
rate = 24000
for index, frequency in enumerate((260, 310, 230, 285)):
    noise = random.Random(1127 + index)
    low = 0.0
    samples = []
    for frame in range(int(rate * 0.11)):
        time = frame / rate
        low += 0.18 * (noise.uniform(-1, 1) - low)
        envelope = min(1, time / 0.007) * (1 - time / 0.11) ** 3
        phase = 2 * math.pi * (frequency * time - 210 * time * time)
        value = (math.sin(phase) * 0.034 + math.sin(phase * 1.5) * 0.008 + low * 0.02) * envelope
        samples.append(round(value * 32767))
    for folder in ('arena-web/audio', 'ios/LittleDill/Audio'):
        destination = root / folder / f'arena-pickup-{index}.wav'
        destination.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(destination), 'wb') as output:
            output.setparams((1, 2, rate, len(samples), 'NONE', 'not compressed'))
            output.writeframes(struct.pack(f'<{len(samples)}h', *samples))
