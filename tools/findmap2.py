#!/usr/bin/env python3
from collections import deque
L1 = [
"#################",
"#P......#.......#",
"#.#####.#.#####.#",
"#.#.......#..K..#",
"#.#...#####.###.#",
"#.#...#.#.....#.#",
"#.#.###.#.###.#.#",
"#.#.#...#K..#.#.#",
"#.#.#.#.#####.#.#",
"#.#.#...#...#K#.#",
"#.###.###...###.#",
"#.............#.#",
"##########E.###.#",
]
L2 = [r[::-1] for r in L1]

def bfs(rows, start_rc):
    H = len(rows); W = len(rows[0])
    q = deque([start_rc]); seen = {start_rc}
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < H and 0 <= nc < W and (nr, nc) not in seen and rows[nr][nc] != '#':
                seen.add((nr, nc)); q.append((nr, nc))
    return seen

for name, rows in (("L1", L1), ("L2", L2)):
    spawn = next((i, r.index('P')) for i, r in enumerate(rows) if 'P' in r)
    keys = [(i, j) for i, r in enumerate(rows) for j, c in enumerate(r) if c == 'K']
    exits = [(i, j) for i, r in enumerate(rows) for j, c in enumerate(r) if c == 'E']
    seen = bfs(rows, spawn)
    floors = sum(1 for r in rows for c in r if c != '#')
    print(name, "spawn", spawn, "keys", keys, "exit", exits, "reach", len(seen), "/", floors)
    for k in keys: print("   key ok:", k in seen)
    for e in exits: print("   exit ok:", e in seen)