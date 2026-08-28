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

# win / resolve
n = int(1.5 * SR)
tt = np.arange(n) / SR
win = np.sin(2 * np.pi * 220 * tt) * 0.5 + np.sin(2 * np.pi * 277 * tt) * 0.4 + np.sin(2 * np.pi * 330 * tt) * 0.5
write("win.wav", win * env(tt, 0.3, 0.5) * 0.6)

print("all done")