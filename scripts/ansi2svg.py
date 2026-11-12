#!/usr/bin/env python3
"""Render ANSI terminal output (tmux capture-pane -e) to an SVG.

Used by scripts/shot.sh to turn a pane capture into a PNG so the colours and
alignment can be inspected instead of guessed at.

Usage: ansi2svg.py input.ansi output.svg [fg] [bg] [font-size]
"""

import re
import sys
from collections import Counter
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



# Box-drawing characters are drawn as lines rather than glyphs: in most
# monospace fonts the glyph has a small gap at the cell edge, which makes a
# continuous border look dashed in a screenshot.
BOX_SEGMENTS = {
    "\u2500": "lr", "\u2501": "lr", "\u2550": "lr",
    "\u2502": "ud", "\u2503": "ud", "\u2551": "ud",
    "\u250c": "rd", "\u250f": "rd", "\u2554": "rd", "\u256d": "rd",
    "\u2510": "ld", "\u2513": "ld", "\u2557": "ld", "\u256e": "ld",
    "\u2514": "ru", "\u2517": "ru", "\u255a": "ru", "\u256f": "ru",
    "\u2518": "lu", "\u251b": "lu", "\u255d": "lu", "\u2570": "lu",
    "\u251c": "udr", "\u2523": "udr", "\u2560": "udr", "\u255e": "udr",
    "\u2524": "udl", "\u252b": "udl", "\u2563": "udl", "\u2561": "udl",
    "\u252c": "lrd", "\u2533": "lrd", "\u2566": "lrd", "\u2564": "lrd",
    "\u2534": "lru", "\u253b": "lru", "\u2569": "lru", "\u2567": "lru",
    "\u253c": "lrud", "\u254b": "lrud", "\u256c": "lrud", "\u256a": "lrud",
    "\u256b": "lrud", "\u2568": "lrud", "\u2565": "lrud",
}


def box_lines(char, x, y_top, height, char_w, y_mid, row_mid_x):
    """Return (x1, y1, x2, y2) segments for one box character."""
    x_mid = x + char_w / 2
    segs = BOX_SEGMENTS.get(char)
    if not segs:
        return []
    out = []
    if "l" in segs:
        out.append((x, y_mid, x_mid, y_mid))
    if "r" in segs:
        out.append((x_mid, y_mid, x + char_w, y_mid))
    if "u" in segs:
        out.append((x_mid, y_top, x_mid, y_mid))
    if "d" in segs:
        out.append((x_mid, y_mid, x_mid, y_top + height))
    return out


def auto_colours(raw):
    """Pick the editor background/foreground from the capture itself.

    The old approach asked a separate headless nvim for `Normal`, which can run
    under a different XDG config than the tmux pane and return the wrong theme
    (a dark fallback painted the screenshots black). The captured pane carries
    the real colours, so take the most common non-empty background and text
    colour from it.
    """
    fgs, bgs = Counter(), Counter()
    state = {"fg": None, "bg": None, "bold": False, "reverse": False}
    for line in raw:
        for ch, fg, bg, _bold, _reverse in parse(line, state):
            if bg:
                bgs[bg] += 1
            if fg and ch.strip():
                fgs[fg] += 1
    fg = fgs.most_common(1)[0][0] if fgs else "#2f2a22"
    bg = bgs.most_common(1)[0][0] if bgs else "#e3d7c7"
    return fg, bg


def main():
    src, dst = sys.argv[1], sys.argv[2]
    default_fg = sys.argv[3] if len(sys.argv) > 3 else "auto"
    default_bg = sys.argv[4] if len(sys.argv) > 4 else "auto"
    size = int(sys.argv[5]) if len(sys.argv) > 5 else 15

    raw = open(src, encoding="utf-8", errors="replace").read().split("\n")
    if default_fg == "auto" or default_bg == "auto":
        auto_fg, auto_bg = auto_colours(raw)
        default_fg = auto_fg if default_fg == "auto" else default_fg
        default_bg = auto_bg if default_bg == "auto" else default_bg
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

        row_top = int(row * line_h)
        row_height = max(1, int((row + 1) * line_h) - row_top)
        y_mid = row_top + row_height / 2
        stroke_w = max(1.0, size * 0.08)
        for start, text, style in runs:
            fg, bg, bold, reverse = style or (None, None, False, False)
            if reverse:
                fg, bg = bg or default_bg, fg or default_fg
            fill = fg or default_fg
            rect_fill = bg
            x = int(start * char_w + 6)
            if rect_fill and rect_fill != default_bg:
                # Cover the whole row band: per-row integer rounding used to
                # leave 1px gaps between background rectangles (striping).
                parts.append(
                    f'<rect x="{x}" y="{row_top}" '
                    f'width="{int(len(text) * char_w)}" height="{row_height}" fill="{rect_fill}"/>'
                )

            buffer, buffer_start = [], start
            for offset, char in enumerate(text):
                if char in BOX_SEGMENTS:
                    if buffer:
                        parts.append(
                            f'<text x="{int(buffer_start * char_w + 6)}" y="{y}" '
                            f'fill="{fill}" xml:space="preserve">{escape("".join(buffer))}</text>'
                        )
                        buffer = []
                    cx = int((start + offset) * char_w + 6)
                    for x1, y1, x2, y2 in box_lines(char, cx, row_top, row_height, char_w, y_mid, 0):
                        parts.append(
                            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                            f'stroke="{fill}" stroke-width="{stroke_w:.1f}"/>'
                        )
                    buffer_start = start + offset + 1
                else:
                    if not buffer:
                        buffer_start = start + offset
                    buffer.append(char)
            if buffer:
                weight = ' font-weight="bold"' if bold else ""
                parts.append(
                    f'<text x="{int(buffer_start * char_w + 6)}" y="{y}" fill="{fill}"{weight} '
                    f'xml:space="preserve">{escape("".join(buffer))}</text>'
                )

    parts.append("</svg>")
    open(dst, "w", encoding="utf-8").write("\n".join(parts))


if __name__ == "__main__":
    main()
