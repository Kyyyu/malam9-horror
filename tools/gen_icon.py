#!/usr/bin/env python3
import zlib, struct, math, os

OUT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def write_png(path, w, h, rgba):
    raw = b""
    for y in range(h):
        raw += b"\x00"
        for x in range(w):
            r, g, b, a = rgba[y][x]
            raw += bytes((r, g, b, a))
    comp = zlib.compress(raw, 9)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", comp)
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)

def box_downscale(buf, w, h, s):
    nw, nh = w // s, h // s
    out = [[(0, 0, 0, 0) for _ in range(nw)] for _ in range(nh)]
    for y in range(nh):
        for x in range(nw):
            r = g = b = a = 0
            cnt = 0
            for dy in range(s):
                for dx in range(s):
                    rr, gg, bb, aa = buf[y * s + dy][x * s + dx]
                    r += rr * aa; g += gg * aa; b += bb * aa; a += aa
                    cnt += 1
            if a > 0:
                r /= a; g /= a; b /= a
            a /= cnt
            out[y][x] = (int(r), int(g), int(b), int(a * 255 / 255.0 * 255)) if False else (int(r), int(g), int(b), int(a))
    return out

def face_layer(w, h, cx, cy, rx, ry, scale=1.0, bg_dark=True, safe=1.0):
    buf = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]
    def put_f(A, x):
        px = int(x)
        if 0 <= px < w:
            rr, gg, bb, aa = buf[y][px]
            f = A
            buf[y][px] = (min(255, rr + int(rr * 0)), min(255, gg), min(255, bb), 255)
    def add(x, y, col, alpha):
        px = int(x)
        if not (0 <= px < w and 0 <= y < h):
            return
        r, g, b, a = col
        pr, pg, pb, pa = buf[y][px]
        na = pa + alpha * (255 - pa) / 255
        if na <= 0:
            return
        nr = (r * alpha + pr * (255 - alpha)) / 255
        ng = (g * alpha + pg * (255 - alpha)) / 255
        nb = (b * alpha + pb * (255 - alpha)) / 255
        buf[y][px] = (int(nr), int(ng), int(nb), int(na))
    return buf

def render(size, transparent_bg, cx, cy, fx, fy, rx, ry):
    w = h = size
    buf = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]
    def add(x, y, r, g, b, a):
        xi = int(x); yi = int(y)
        if 0 <= xi < w and 0 <= yi < h:
            pr, pg, pb, pa = buf[yi][xi]
            na = pa + a * (255 - pa) / 255
            if na <= 0:
                return
            nr = (r * a + pr * (255 - a)) / 255
            ng = (g * a + pg * (255 - a)) / 255
            nb = (b * a + pb * (255 - a)) / 255
            buf[yi][xi] = (int(nr), int(ng), int(nb), int(na))
    def ellipse(x, y, rx2, ry2, r, g, b, a):
        for yy in range(int(y - ry2) - 1, int(y + ry2) + 2):
            for xx in range(int(x - rx2) - 1, int(x + rx2) + 2):
                dx = (xx + 0.5 - x) / rx2
                dy = (yy + 0.5 - y) / ry2
                if dx * dx + dy * dy <= 1.0:
                    add(xx, yy, r, g, b, a)
    # background
    if not transparent_bg:
        for yy in range(h):
            for xx in range(w):
                nx = (xx + 0.5) / w * 2 - 1
                ny = (yy + 0.5) / h * 2 - 1
                d = math.sqrt(nx * nx + ny * ny) * 0.85
                t = max(0.0, 1.0 - d)
                r = int(18 + 10 * t)
                g = int(4 + 10 * t)
                b = int(30 + 30 * t)
                buf[yy][xx] = (r, g, b, 255)
    # red halo behind head
    halo_a = 200 if transparent_bg else 90
    ellipse(cx, cy + fy * 0.08, fx * 1.5, fy * 1.35, 120, 12, 18, halo_a)
    # head (pale)
    ellipse(cx, cy, fx, fy, 226, 220, 214, 255)
    ellipse(cx, cy + fy * 0.06, fx * 0.92, fy * 0.74, 196, 186, 178, 255)
    # cheek shade
    ellipse(cx - fx * 0.42, cy + fy * 0.16, fx * 0.18, fy * 0.22, 90, 40, 40, 70)
    ellipse(cx + fx * 0.42, cy + fy * 0.16, fx * 0.18, fy * 0.22, 90, 40, 40, 70)
    # forehead wrap (cloth bound pocong)
    ellipse(cx, cy - fy * 0.62, fx * 0.98, fy * 0.09, 208, 200, 190, 255)
    for i in range(6):
        tx = cx - fx * 0.55 + fx * 0.22 * i
        ellipse(tx, cy - fy * 0.72, fx * 0.06, fy * 0.09, 165, 150, 145, 200)
    # dark eye sockets
    ex1, ey1 = cx - fx * 0.38, cy - fy * 0.06
    ex2, ey2 = cx + fx * 0.38, cy - fy * 0.06
    ellipse(ex1, ey1, fx * 0.24, fy * 0.3, 8, 5, 5, 255)
    ellipse(ex2, ey2, fx * 0.24, fy * 0.3, 8, 5, 5, 255)
    # hollow inner darker
    ellipse(ex1, ey1 + fy * 0.02, fx * 0.15, fy * 0.19, 0, 0, 0, 255)
    ellipse(ex2, ey2 + fy * 0.02, fx * 0.15, fy * 0.19, 0, 0, 0, 255)
    # red glints
    ellipse(ex1 - fx * 0.03, ey1 + fy * 0.02, fx * 0.06, fy * 0.08, 255, 20, 20, 255)
    ellipse(ex2 - fx * 0.03, ey2 + fy * 0.02, fx * 0.06, fy * 0.08, 255, 20, 20, 255)
    # mouth slit
    ellipse(cx + fx * 0.03, cy + fy * 0.42, fx * 0.22, fy * 0.13, 10, 4, 4, 255)
    ellipse(cx + fx * 0.03, cy + fy * 0.42, fx * 0.15, fy * 0.08, 0, 0, 0, 255)
    # nose shadow
    ellipse(cx + fx * 0.01, cy + fy * 0.18, fx * 0.06, fy * 0.12, 130, 110, 110, 130)
    return buf

SS = 4
for size, name, tbg in ((256, "icon.png", False), (432, "icon_fg.png", True), (432, "icon_bg.png", False)):
    fs = size * SS
    b = render(fs, tbg, fs / 2, fs / 2, fs * 0.30, fs * 0.40, fs * 0.30, fs * 0.40)
    buf = box_downscale(b, fs, fs, SS)
    write_png(os.path.join(OUT, name), size, size, buf)
    print("wrote", os.path.join(OUT, name), size)