#!/usr/bin/env python3
"""
Genera 4 suonerie .wav PCM 16-bit mono a 44100 Hz da 28.5 secondi ciascuna
(sotto il limite massimo di 30s imposto da iOS per le notifiche persistenti).
Usa esclusivamente la libreria standard Python.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
DURATION_SECONDS = 28.5
NUM_SAMPLES = int(SAMPLE_RATE * DURATION_SECONDS)
MAX_AMP = 29000  # ~88% del fondo scala int16 per evitare clipping


def clamp_sample(val: float) -> int:
    s = int(val * MAX_AMP)
    if s > 32767:
        return 32767
    if s < -32768:
        return -32768
    return s


def envelope(local_t: float, note_len: float, attack: float = 0.008, release: float = 0.03) -> float:
    if local_t < 0.0 or local_t >= note_len:
        return 0.0
    if local_t < attack:
        return local_t / attack
    if local_t > note_len - release:
        return max(0.0, (note_len - local_t) / release)
    return 1.0


def gen_radar(t: float) -> float:
    # Pattern ispirato a Radar: raffiche veloci di 4 colpi ogni 1.25s
    cycle = t % 1.25
    pulse_starts = [0.0, 0.16, 0.32, 0.48, 0.72]
    val = 0.0
    for idx, start in enumerate(pulse_starts):
        lt = cycle - start
        dur = 0.11 if idx < 4 else 0.18
        if 0.0 <= lt < dur:
            env = envelope(lt, dur, attack=0.004, release=0.04) * math.exp(-lt * 6.0)
            f0 = 1567.98 if idx % 2 == 0 else 1975.53  # G6 / B6
            tone = (
                0.65 * math.sin(2.0 * math.pi * f0 * lt)
                + 0.25 * math.sin(2.0 * math.pi * (f0 * 2.0) * lt)
                + 0.10 * math.sin(2.0 * math.pi * (f0 * 3.0) * lt)
            )
            val += env * tone
    return val * 0.95


def gen_digital(t: float) -> float:
    # Bip bitonali classici da sveglia digitale ad alta penetrazione
    cycle = t % 1.0
    beep_times = [(0.0, 0.10, 2093.0), (0.14, 0.10, 2637.02), (0.28, 0.10, 2093.0), (0.42, 0.14, 2637.02)]
    val = 0.0
    for start, dur, freq in beep_times:
        lt = cycle - start
        if 0.0 <= lt < dur:
            env = envelope(lt, dur, attack=0.005, release=0.015)
            # Onda quadra ammorbidita (armoniche dispari) per timbro sveglia digitale
            tone = (
                0.72 * math.sin(2.0 * math.pi * freq * lt)
                + 0.22 * math.sin(2.0 * math.pi * (freq * 3.0) * lt)
                + 0.08 * math.sin(2.0 * math.pi * (freq * 5.0) * lt)
            )
            val += env * tone
    return val * 0.9


def gen_extreme(t: float) -> float:
    # Sirena modulata urgente bitonale + impulsi di attacco
    cycle = t % 0.8
    # Sweep rapido tra 740 Hz e 1480 Hz
    phase_mod = math.sin(2.0 * math.pi * 2.5 * t)
    freq = 1110.0 + 370.0 * phase_mod
    siren = (
        0.60 * math.sin(2.0 * math.pi * freq * t)
        + 0.28 * math.sin(2.0 * math.pi * (freq * 1.5) * t)
        + 0.12 * math.sin(2.0 * math.pi * (freq * 2.0) * t)
    )
    gate = 1.0 if cycle < 0.62 else 0.15
    # Piccoli fade ai bordi del gate per evitare click
    if 0.60 <= cycle < 0.62:
        gate = 1.0 - ((cycle - 0.60) / 0.02) * 0.85
    elif 0.78 <= cycle < 0.80:
        gate = 0.15 + ((cycle - 0.78) / 0.02) * 0.85
    return siren * gate * 0.92


def gen_gentle(t: float) -> float:
    # Accordo armonico progressivo (cresce nei primi 8 secondi)
    progress = min(1.0, 0.28 + 0.72 * (t / 8.0))
    cycle = t % 2.4
    notes = [
        (0.0, 1.4, 523.25),   # C5
        (0.35, 1.4, 659.25),  # E5
        (0.70, 1.4, 783.99),  # G5
        (1.05, 1.3, 1046.50), # C6
    ]
    val = 0.0
    for start, dur, freq in notes:
        lt = cycle - start
        if 0.0 <= lt < dur:
            env = envelope(lt, dur, attack=0.04, release=0.35) * math.exp(-lt * 1.4)
            tone = (
                0.75 * math.sin(2.0 * math.pi * freq * lt)
                + 0.20 * math.sin(2.0 * math.pi * (freq * 2.0) * lt)
                + 0.05 * math.sin(2.0 * math.pi * (freq * 3.0) * lt)
            )
            val += env * tone * 0.45
    return val * progress


def write_wav(path: str, generator_fn) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = bytearray()
    for i in range(NUM_SAMPLES):
        t = i / SAMPLE_RATE
        sample = clamp_sample(generator_fn(t))
        frames.extend(struct.pack("<h", sample))

    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(bytes(frames))


def main() -> None:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(repo_root, "Sveglia", "Resources", "Sounds")

    sounds = [
        ("alarm_radar.wav", gen_radar),
        ("alarm_digital.wav", gen_digital),
        ("alarm_extreme.wav", gen_extreme),
        ("alarm_gentle.wav", gen_gentle),
    ]

    for filename, fn in sounds:
        out_path = os.path.join(out_dir, filename)
        print(f"Generazione {out_path} ({DURATION_SECONDS}s)...")
        write_wav(out_path, fn)

    print("Completato: tutte le suonerie sono pronte.")


if __name__ == "__main__":
    main()
