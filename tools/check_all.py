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

L2_INTERIOR = [
"...............",
"P.....####.....",
".#####....#.###",
"..#......#.....",
"...####.#####..",
".#.#..#....#...",
"##..##...#....#",
"....#..#.K#....",
"######......#..",
"........#..K#..",
".......##......",
"K.......#......",
"####E##......##",
]
L2 = ["#" + i + "#" for i in L2_INTERIOR]

def bfs(g, start, goal):
    if g[start[0]][start[1]] == '#' or g[goal[0]][goal[1]] == '#':
        return False
    q = deque([start]); seen = {start}
    while q:
        x, y = q.popleft()
        if (x, y) == goal:
            return True
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= ny < len(g[0]) and 0 <= nx < len(g) and (nx,ny) not in seen and g[nx][ny] != '#':
                seen.add((nx,ny)); q.append((nx,ny))
    return False

for name, rows in [("L1", L1), ("L2", L2)]:
    ok = all(len(r) == 17 for r in rows)
    g = [list(r) for r in rows]
    spawn = next((i, r.index('P')) for i, r in enumerate(rows) if 'P' in r)
    keys = [(i, j) for i, r in enumerate(rows) for j, c in enumerate(r) if c == 'K']
    exits = [(i, j) for i, r in enumerate(rows) for j, c in enumerate(r) if c == 'E']
    floors = [(i,j) for i,r in enumerate(rows) for j,c in enumerate(r) if c != '#']
    q = deque([spawn]); seen = {spawn}
    while q:
        x,y = q.popleft()
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx,ny = x+dx,y+dy
            if 0<=nx<len(rows) and 0<=ny<17 and (nx,ny) not in seen and g[nx][ny] != '#':
                seen.add((nx,ny)); q.append((nx,ny))
    print(f"== {name} == rows_ok={ok} spawn={spawn} keys={keys} exits={exits} reachable={len(seen)}/{len(floors)}")
    if ok:
        for k in keys:
            print("   key", k, "reachable:", bfs(g, spawn, k))
        for e in exits:
            print("   exit", e, "reachable:", bfs(g, spawn, e))
    for i, r in enumerate(rows):
        print(f"   {i:2} {r}")