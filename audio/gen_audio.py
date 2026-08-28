import numpy as np
import wave, os

SR = 22050
os.makedirs(os.path.dirname(__file__), exist_ok=True)

def write(name, samples):
    data = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(os.path.dirname(__file__), name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, len(samples) / SR, "s")

def env(t, a=0.01, r=0.1):
    n = len(t)
    e = np.ones(n)
    na = int(a * SR)
    nr = int(r * SR)
    if na > 0:
        e[:na] = np.linspace(0, 1, na)
    if nr > 0:
        e[-nr:] = np.linspace(1, 0, nr)
    return e

t = np.arange(int(SR * 12)) / SR

# ambient drone: low rumble + detuned sines + slow shimmer
rng = np.random.default_rng(9)
noise = rng.uniform(-1, 1, len(t))
low = 0.25 * np.sin(2 * np.pi * 33 * t) + 0.3 * np.sin(2 * np.pi * 47 * t + 1.2)
lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.2 * t)
shimmer = 0.08 * noise * lfo
drone = (low + 0.35 * np.sin(2 * np.pi * 196 * t) * 0.15 + 0.25 * np.sin(2 * np.pi * 294 * t) * 0.2 + shimmer)
drone = np.convolve(drone, np.ones(64) / 64, mode="same")
write("ambient_drone.wav", drone * 0.5)

# heartbeat: two low thumps repeating
hb = np.zeros(int(SR * 4))
def thump(out, s, f=55, d=0.18):
    n = int(d * SR)
    tt = np.arange(n) / SR
    beat = np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * f * 2 * tt)
    beat *= np.exp(-tt * 22)
    out[s:s + n] += beat
thump(hb, int(0.0 * SR)); thump(hb, int(0.18 * SR))
thump(hb, int(0.55 * SR)); thump(hb, int(0.73 * SR))
rem = 2 * (hb[int(2 * SR):]) if False else None
hb = np.tile(hb, 1)
write("heartbeat.wav", hb * 0.7)

# jumpscare: loud noise + descending scream
n = int(1.4 * SR)
tt = np.arange(n) / SR
scream = np.sin(2 * np.pi * (900 - 500 * tt) * tt) * np.sin(2 * np.pi * 13 * tt) * 0.6
noise_burst = rng.uniform(-1, 1, n) * np.exp(-tt * 6) * 0.5
write("jumpscare.wav", (scream + noise_burst) * 1.0)

# footstep: short muffled thud
n = int(0.14 * SR)
tt = np.arange(n) / SR
step = np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 35)
step += rng.uniform(-1, 1, n) * np.exp(-tt * 60) * 0.3
write("footstep.wav", step * 0.8)

# door slam
n = int(0.5 * SR)
tt = np.arange(n) / SR
slam = rng.uniform(-1, 1, n) * np.exp(-tt * 9)
slam += np.sin(2 * np.pi * 65 * tt) * np.exp(-tt * 12) * 0.9
write("door_slam.wav", slam * 0.9)

# spooky whisper/swish
n = int(2.0 * SR)
tt = np.arange(n) / SR
whisper = rng.uniform(-1, 1, n)
envw = np.ones(n)
envw[:int(0.8 * SR)] = np.linspace(0, 1, int(0.8 * SR))
envw[-int(0.8 * SR):] = np.linspace(1, 0, int(0.8 * SR))
whisper *= envw
whisper = np.convolve(whisper, np.ones(256) / 256, mode="same")
mod = 1 + 0.8 * np.sin(2 * np.pi * 3.4 * t[:n])
write("whisper.wav", whisper * mod * 0.6)

# pickup chime
n = int(0.6 * SR)
tt = np.arange(n) / SR
chime = np.sin(2 * np.pi * 440 * tt) + 0.6 * np.sin(2 * np.pi * 660 * tt) + 0.3 * np.sin(2 * np.pi * 880 * tt)
write("pickup.wav", chime * env(tt) * 0.5)

# music loop: eerie ambient (30s, crossfaded tails for seamless looping)
dur = 30.0
n = int(SR * dur)
tt = np.arange(n) / SR
rng = np.random.default_rng(41)
music = np.zeros(n)
base = [73.42, 87.31, 110.0, 146.83]  # D minor drone
for f in base:
    music += np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.283))
    music += 0.5 * np.sin(2 * np.pi * f * 1.004 * tt + rng.uniform(0, 6.283))
pad_lfo = 0.55 + 0.45 * np.sin(2 * np.pi * 0.05 * tt + 0.7)
for f in [220.0, 261.63, 311.13]:
    music += 0.16 * np.sin(2 * np.pi * f * tt + rng.uniform(0, 6.283)) * pad_lfo
noise_wind = rng.uniform(-1, 1, n)
noise_wind = np.convolve(noise_wind, np.ones(900) / 900, mode="same")
music += noise_wind * (0.18 + 0.16 * np.sin(2 * np.pi * 0.03 * tt))
pluck_freqs = [466.16, 554.37, 587.33, 622.25, 349.23]
for i in range(10):
    st = int(rng.uniform(2.0, dur - 2.0) * SR)
    d = int(1.6 * SR)
    if st + d > n:
        continue
    seg = np.arange(d) / SR
    f = pluck_freqs[int(rng.integers(0, len(pluck_freqs)))]
    tone = np.sin(2 * np.pi * f * seg + rng.uniform(0, 6.283))
    tone += 0.4 * np.sin(2 * np.pi * f * 1.5 * seg)
    tone *= np.exp(-seg * 1.4)
    music[st:st + d] += tone
# danger swell sweeping upward each loop
sw = int(6.0 * SR)
swell_tt = np.arange(sw) / SR
swell = np.sin(2 * np.pi * (70 + 160 * np.linspace(0, 1, sw)) * swell_tt)
swell *= np.linspace(0, 1, sw) ** 2
music[n - sw:] += swell * 0.7
fadd = int(1.2 * SR)
fade = np.ones(n)
fade[:fadd] = np.linspace(0, 1, fadd)
fade[-fadd:] = np.linspace(1, 0, fadd)
music *= fade
music = music / (np.max(np.abs(music)) + 1e-9) * 0.55
write("music_loop.wav", music)

# flashlight click
n = int(0.14 * SR)
tt = np.arange(n) / SR
clk = np.sin(2 * np.pi * 1300 * tt) * np.exp(-tt * 60) + 0.6 * np.sin(2 * np.pi * 1900 * tt) * np.exp(-tt * 90)
write("click.wav", clk * 0.8)

# musik gurau: original melancholic 6/8 ballad (inspired by "Bersenja Gurau")
eighth = 0.5
n = int(SR * 24.0)
music = np.zeros(n)
rngm = np.random.default_rng(77)

def add_tone(buf, at, freq, dur, amp, decay=3.0, bright=0.35):
    s = max(0, int(at * SR))
    d = int(dur * SR)
    if s + d > len(buf):
        d = len(buf) - s
    if d <= 0:
        return
    seg = np.arange(d) / SR
    base = np.sin(2 * np.pi * freq * seg + rngm.uniform(0, 6.28))
    harm = bright * (0.4 * np.sin(2 * np.pi * freq * 2 * seg) + 0.15 * np.sin(2 * np.pi * freq * 3 * seg))
    vib = 1.0 + 0.007 * np.sin(2 * np.pi * 4.5 * seg + rngm.uniform(0, 6.28))
    env = np.exp(-seg * decay)
    buf[s:s + d] += (base * vib + harm) * env * amp

def add_bass(buf, at, freq, dur, amp):
    s = max(0, int(at * SR))
    d = int(dur * SR)
    if s + d > len(buf):
        d = len(buf) - s
    if d <= 0:
        return
    seg = np.arange(d) / SR
    t = np.sin(2 * np.pi * freq * seg) + 0.3 * np.sin(2 * np.pi * freq * 2 * seg)
    env = np.minimum(seg / 0.3, 1.0) * np.exp(-seg * 0.7)
    buf[s:s + d] += t * env * amp

# Dm - Bb - F - C
prog = [
    [73.42, 87.31, 110.0, 146.83],
    [58.27, 69.30, 87.31, 116.54],
    [87.31, 110.0, 130.81, 174.61],
    [65.41, 82.41, 98.0, 130.81],
]
melody = [
    (0, 2, 587.33, 1.2), (0, 5, 440.0, 1.0), (0, 8, 349.23, 1.0), (0, 11, 293.66, 1.8),
    (1, 1, 587.33, 1.2), (1, 4, 466.16, 1.0), (1, 7, 392.0, 1.0), (1, 10, 293.66, 1.8),
    (2, 2, 523.25, 1.2), (2, 5, 440.0, 1.0), (2, 8, 349.23, 1.2), (2, 10, 261.63, 2.0),
    (3, 1, 523.25, 1.2), (3, 4, 392.0, 1.0), (3, 7, 329.63, 1.0), (3, 11, 261.63, 2.2),
]
for ci, chord in enumerate(prog):
    base = ci * 6.0
    for i in range(12):
        at = base + i * eighth
        arp = chord[(i * 2) % 4]
        amp = 0.2 if i % 3 == 0 else 0.13
        add_tone(music, at, arp, 0.7, amp, decay=2.6, bright=0.18)
    add_bass(music, base, chord[0], 2.6, 0.5)
    add_bass(music, base + 3.0, chord[1], 2.2, 0.3)
    # soft pad
    s0 = int(base * SR)
    seg = np.arange(int(6.0 * SR)) / SR
    env2 = np.minimum(seg / 0.7, 1.0) * np.exp(-np.maximum(seg - 4.2, 0) * 0.8)
    for f in [chord[1] * 2, chord[2] * 2, chord[3]]:
        pad = np.sin(2 * np.pi * f * seg + rngm.uniform(0, 6.28))
        pad += 0.5 * np.sin(2 * np.pi * f * 1.004 * seg + rngm.uniform(0, 6.28))
        music[s0:s0 + len(seg)] += pad * env2 * 0.05
for plan in melody:
    ci, slot, f, dur = plan
    add_tone(music, ci * 6.0 + slot * eighth, f, dur, 0.3, decay=1.7, bright=0.5)

air = np.convolve(rngm.uniform(-1, 1, n), np.ones(500) / 500, mode="same")
music += air * 0.014

fadd = int(1.2 * SR)
fade = np.ones(n)
fade[:fadd] = np.linspace(0, 1, fadd)
fade[-fadd:] = np.linspace(1, 0, fadd)
music *= fade
music = music / (np.max(np.abs(music)) + 1e-9) * 0.45
write("musik_gurau.wav", music)

# win / resolve
n = int(1.5 * SR)
tt = np.arange(n) / SR
win = np.sin(2 * np.pi * 220 * tt) * 0.5 + np.sin(2 * np.pi * 277 * tt) * 0.4 + np.sin(2 * np.pi * 330 * tt) * 0.5
write("win.wav", win * env(tt, 0.3, 0.5) * 0.6)

print("all done")