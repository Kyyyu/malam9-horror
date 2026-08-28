#!/usr/bin/env python3
from collections import deque

# 17 cols x 13 rows. '.' floor, '#' wall, 'P' spawn, 'K' keys, 'E' exit gap in border.
INTERIOR = [
"###############",
"P......#.......",
".#####.#.#####.",
".#.......#..K..",
".#...#####.###.",
".#...#.#.....#.",
".#.###.#.###.#.",
".#.#...#K..#.#.",
".#.#.#.#####.#.",
".#.#...#...#K#.",
".###.###...###.",
".............#.",
"#########..###.",
]
# exit gap marker; interior col index where border wall is open
EXIT_COL = 9
EXIT_ROW = 12

ROWS = []
for i, interior in enumerate(INTERIOR):
    assert len(interior) == 15, (i, len(interior), interior)
    if i == EXIT_ROW:
        # open the gap in the bottom border at EXIT_COL (interior col numbering 1..15)
        row = "#" + interior + "#"
    else:
        row = "#" + interior + "#"
    ROWS.append(row)

# enforce border + gap
for i, r in enumerate(ROWS):
    assert len(r) == 17, (i, len(r))
    if not (i == 0 or i == 12):
        assert r[0] == '#' and r[-1] == '#', (i, r)
for i, r in enumerate(ROWS):
    for j, ch in enumerate(r):
        if i == 0 or i == 12:
            # only the top border and col0/16 borders must be solid; bottom row may
            # be open near the exit approach (grid col of EXIT_COL)
            if i == 0 and ch != '#':
                print("top border violation", i, j, ch)
ROWS[EXIT_ROW] = list(ROWS[EXIT_ROW])
ROWS[EXIT_ROW][EXIT_COL + 1] = 'E'
ROWS[EXIT_ROW] = "".join(ROWS[EXIT_ROW])

print("map:")
for i, r in enumerate(ROWS):
    print(f"{i:2} {r}")

g = [list(r) for r in ROWS]

def bfs(start, goal):
    if g[start[0]][start[1]] == '#' or g[goal[0]][goal[1]] == '#':
        return False
    q = deque([start])
    seen = {start}
    while q:
        x, y = q.popleft()
        if (x, y) == goal:
            return True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < 13 and 0 <= ny < 17 and (nx, ny) not in seen and g[nx][ny] != '#':
                seen.add((nx, ny))
                q.append((nx, ny))
    return False

spawn = next((i, r.index('P')) for i, r in enumerate(ROWS) if 'P' in r)
goals = [(i, j) for i, r in enumerate(ROWS) for j, c in enumerate(r) if c == 'K']
ex = next((i, j) for i, r in enumerate(ROWS) for j, c in enumerate(r) if c == 'E')
print("spawn", spawn, "keys", goals, "exit", ex)
for gd in goals:
    print("key reachable:", bfs(spawn, gd))
print("exit reachable:", bfs(spawn, ex))