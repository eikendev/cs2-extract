#!/usr/bin/env python3
"""Flatten the colorized tree.txt into one full path per line."""
import re
import sys

ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')
SIZE_RE = re.compile(r' - [\d.]+ [kmg]?b$', re.IGNORECASE)

# vpkeditcli --file-tree indents each level by 3 columns of box-drawing chars.
INDENT_COLS = 3


def parse(src, dst):
    stack = []
    written = 0
    with open(src, 'r', encoding='utf-8') as fin, open(dst, 'w', encoding='utf-8') as fout:
        for raw in fin:
            line = raw.rstrip('\r\n')
            if not line.strip():
                continue
            # Position of first ANSI escape = visual column of the name
            # (box-drawing chars before it are 1 char each; no other invisible bytes).
            col = line.find('\x1b[')
            if col < 0:
                continue
            depth = 0 if col == 0 else col // INDENT_COLS - 1
            content = ANSI_RE.sub('', line[col:])
            size_m = SIZE_RE.search(content)
            name = content[:size_m.start()] if size_m else content

            while stack and stack[-1][0] >= depth:
                stack.pop()

            full_path = '/'.join([n for _, n in stack] + [name])
            fout.write(full_path + '\n')
            written += 1

            if not size_m:
                stack.append((depth, name))
    return written


if __name__ == '__main__':
    src = sys.argv[1] if len(sys.argv) > 1 else 'tree.txt'
    dst = sys.argv[2] if len(sys.argv) > 2 else 'tree_flat.txt'
    n = parse(src, dst)
    print(f'wrote {n} lines to {dst}')
