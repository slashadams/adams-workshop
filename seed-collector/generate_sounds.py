#!/usr/bin/env python3
"""Generate simple 8-bit sound effects for Seed Collector."""

import wave
import math
import struct
import os

SOUNDS = "/root/seed-collector/assets/sounds"
SAMPLE_RATE = 22050

def write_wav(filename, samples):
    path = os.path.join(SOUNDS, filename)
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(struct.pack(f"<{len(samples)}h", *samples))

def square_wave(freq, duration, volume=0.5):
    n = int(SAMPLE_RATE * duration)
    return [int(volume * 32767 * (1 if int(t * freq / SAMPLE_RATE) % 2 == 0 else -1)) for t in range(n)]

def noise(duration, volume=0.3):
    n = int(SAMPLE_RATE * duration)
    return [int(volume * 32767 * (hash((t,)) % 2 * 2 - 1)) for t in range(n)]

def envelope(samples, attack=0.01, release=0.05):
    n = len(samples)
    a = int(SAMPLE_RATE * attack)
    r = int(SAMPLE_RATE * release)
    for i in range(n):
        if i < a:
            samples[i] = int(samples[i] * (i / a))
        elif i > n - r:
            samples[i] = int(samples[i] * ((n - i) / r))
    return samples

def generate_collect():
    """Bright coin-pickup sound."""
    s = square_wave(880, 0.08) + square_wave(1320, 0.12)
    s = envelope(s, 0.005, 0.1)
    write_wav("collect.wav", s)

def generate_plant():
    """Soft thud for planting."""
    s = square_wave(120, 0.15)
    s = envelope(s, 0.01, 0.1)
    write_wav("plant.wav", s)

def generate_step():
    """Soft footstep."""
    s = square_wave(200, 0.05, 0.2)
    s = envelope(s, 0.005, 0.04)
    write_wav("step.wav", s)

def generate_harvest():
    """Rising cheerful tone."""
    s = square_wave(660, 0.1) + square_wave(880, 0.1) + square_wave(1100, 0.15)
    s = envelope(s, 0.01, 0.15)
    write_wav("harvest.wav", s)

def generate_buy():
    """Cash register ding."""
    s = square_wave(440, 0.05) + square_wave(880, 0.1)
    s = envelope(s, 0.005, 0.08)
    write_wav("buy.wav", s)

def generate_sell():
    """Coin drop."""
    s = square_wave(880, 0.05) + square_wave(660, 0.08)
    s = envelope(s, 0.005, 0.08)
    write_wav("sell.wav", s)

def generate_menu():
    """Soft UI blip."""
    s = square_wave(440, 0.03, 0.3)
    s = envelope(s, 0.002, 0.02)
    write_wav("menu.wav", s)

if __name__ == "__main__":
    os.makedirs(SOUNDS, exist_ok=True)
    generate_collect()
    generate_plant()
    generate_step()
    generate_harvest()
    generate_buy()
    generate_sell()
    generate_menu()
    print("All sounds generated.")