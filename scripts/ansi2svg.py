#!/usr/bin/env python3
"""Render ANSI terminal output (tmux capture-pane -e) to an SVG.

Used by scripts/shot.sh to turn a pane capture into a PNG so the colours and
alignment can be inspected instead of guessed at.

Usage: ansi2svg.py input.ansi output.svg [fg] [bg] [font-size]
"""

import re
import sys
from xml.sax.saxutils import escape

SGR = re.compile(r"\x1b\[([0-9;]*)m")
CSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
OSC = re.compile(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")

PALETTE = {
    0: "#000000", 1: "#cc5555", 2: "#55aa66", 3: "#d0a040", 4: "#5599cc",
    5: "#aa66cc", 6: "#44aaaa", 7: "#c8c8c8", 8: "#666666", 9: "#ff7777",
    10: "#77dd88", 11: "#ffcc66", 12: "#77bbff", 13: "#dd88ff", 14: "#66dddd",
    15: "#ffffff",
}


def colour_from_256(n):
    if n < 16:
        return PALETTE.get(n, "#cccccc")
    if n < 232:
        n -= 16
        r, g, b = n // 36, (n % 36) // 6, n % 6
        scale = lambda v: 55 + v * 40
        return "#%02x%02x%02x" % (scale(r), scale(g), scale(b))
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


def apply_sgr(body, state):
    params = [p for p in body.split(";") if p != ""]
    params = [int(p) if p.isdigit() else 0 for p in params] or [0]
    j = 0
    while j < len(params):
        p = params[j]
        if p == 0:
            state.update(fg=None, bg=None, bold=False, reverse=False)
        elif p == 1:
            state["bold"] = True
        elif p == 22:
            state["bold"] = False
        elif p == 7:
            state["reverse"] = True
        elif p == 27:
            state["reverse"] = False
        elif 30 <= p <= 37:
            state["fg"] = PALETTE[p - 30]
        elif 90 <= p <= 97:
            state["fg"] = PALETTE[p - 90 + 8]
        elif 40 <= p <= 47:
            state["bg"] = PALETTE[p - 40]
        elif 100 <= p <= 107:
            state["bg"] = PALETTE[p - 100 + 8]
        elif p == 39:
            state["fg"] = None
        elif p == 49:
            state["bg"] = None
        elif p in (38, 48):
            key = "fg" if p == 38 else "bg"
            if j + 2 < len(params) and params[j + 1] == 5:
                state[key] = colour_from_256(params[j + 2])
                j += 2
            elif j + 4 < len(params) and params[j + 1] == 2:
                state[key] = "#%02x%02x%02x" % (
                    params[j + 2],
                    params[j + 3],
                    params[j + 4],
                )
                j += 4
        j += 1


def parse(line, state):
    """Yield (char, fg, bg, bold, reverse) for one line, updating state.

    Escape sequences are consumed by hand: CSI parameters can contain `:`
    (e.g. `4:3` underline styles), and an incomplete regex match used to leak
    fragments like `[0;4:3m` into the image.
    """
    out = []
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "\x1b":
            nxt = line[i + 1] if i + 1 < len(line) else ""
            if nxt == "[":
                j = i + 2
                while j < len(line) and not ("@" <= line[j] <= "~"):
                    j += 1
                if j < len(line):
                    if line[j] == "m":
                        apply_sgr(line[i + 2 : j].replace(":", ";"), state)
                    j += 1
                i = j
                continue
            if nxt == "]":
                j = i + 2
                while j < len(line):
                    if line[j] == "\x07":
                        j += 1
                        break
                    if line[j] == "\x1b" and j + 1 < len(line) and line[j + 1] == "\\":
                        j += 2
                        break
                    j += 1
                i = j
                continue
            i += 2
            continue
        if ord(ch) < 32 and ch != "\t":
            i += 1
            continue
        out.append((ch, state["fg"], state["bg"], state["bold"], state["reverse"]))
        i += 1
    return out


def main():
    src, dst = sys.argv[1], sys.argv[2]
    default_fg = sys.argv[3] if len(sys.argv) > 3 else "#2f2a22"
    default_bg = sys.argv[4] if len(sys.argv) > 4 else "#e3d7c7"
    size = int(sys.argv[5]) if len(sys.argv) > 5 else 15

    raw = open(src, encoding="utf-8", errors="replace").read().split("\n")
    state = {"fg": None, "bg": None, "bold": False, "reverse": False}

    char_w = size * 0.6
    line_h = size * 1.35
    width = max((len(CSI.sub("", OSC.sub("", line))) for line in raw), default=80)
    height = len(raw)

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{int(width * char_w + 12)}" '
        f'height="{int(height * line_h + 12)}" font-family="DejaVu Sans Mono, monospace">',
        f'<rect width="100%" height="100%" fill="{default_bg}"/>',
    ]

    for row, line in enumerate(raw):
        cells = parse(line, state)
        y = int(row * line_h + size)
        # Group runs with identical styling.
        col = 0
        run_start = 0
        run_style = None
        runs = []

        def flush(end):
            if end <= run_start:
                return
            text = "".join(c[0] for c in cells[run_start:end])
            runs.append((run_start, text, run_style))

        for idx, (ch, fg, bg, bold, reverse) in enumerate(cells):
            style = (fg, bg, bold, reverse)
            if style != run_style:
                flush(idx)
                run_start = idx
                run_style = style
        flush(len(cells))

        for start, text, style in runs:
            fg, bg, bold, reverse = style or (None, None, False, False)
            if reverse:
                fg, bg = bg or default_bg, fg or default_fg
            fill = fg or default_fg
            rect_fill = bg
            x = int(start * char_w + 6)
            if rect_fill and rect_fill != default_bg:
                parts.append(
                    f'<rect x="{x}" y="{int(row * line_h + 2)}" '
                    f'width="{int(len(text) * char_w)}" height="{int(line_h)}" fill="{rect_fill}"/>'
                )
            weight = ' font-weight="bold"' if bold else ""
            parts.append(
                f'<text x="{x}" y="{y}" fill="{fill}"{weight} '
                f'xml:space="preserve">{escape(text)}</text>'
            )

    parts.append("</svg>")
    open(dst, "w", encoding="utf-8").write("\n".join(parts))


if __name__ == "__main__":
    main()
