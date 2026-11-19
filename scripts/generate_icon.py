#!/usr/bin/env python3
"""
Genera le icone PNG dell'app Sveglia (sfondo OLED scuro,
anello sveglia con gradiente arancio-corallo e simbolo matematico +/=).
Genera sia AppIcon-1024.png (Asset Catalog) sia AppIcon60x60@2x/3x.png (bundle diretto).
Usa solo libreria standard Python (math, os, struct, zlib).
"""

import math
import os
import struct
import zlib


def clamp_byte(v: float) -> int:
    return max(0, min(255, int(v)))


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def sd_rounded_box(px: float, py: float, bx: float, by: float, r: float) -> float:
    qx = abs(px) - bx + r
    qy = abs(py) - by + r
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def write_png(path: str, width: int, height: int, rows: list[bytes]) -> None:
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + r for r in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # RGB 8-bit
    png_data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, level=6))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png_data)


def render_icon(size: int) -> list[bytes]:
    rows: list[bytes] = []
    half = size / 2.0
    inv = 1.0 / half

    for y in range(size):
        ny = (y - half + 0.5) * inv
        row = bytearray(size * 3)
        for x in range(size):
            nx = (x - half + 0.5) * inv
            r_dist = math.hypot(nx, ny)

            # Sfondo OLED con leggero bagliore caldo al centro
            glow = math.exp(-r_dist * r_dist * 3.2)
            bg_r = 8.0 + 34.0 * glow
            bg_g = 9.0 + 12.0 * glow
            bg_b = 14.0 + 8.0 * glow

            # Anello esterno dell'orologio
            ring_sdf = abs(r_dist - 0.58) - 0.055
            ring_alpha = 1.0 - smoothstep(-0.008, 0.008, ring_sdf)

            # Campane superiori della sveglia
            bell_alpha = 0.0
            for sign in (-1.0, 1.0):
                bx = nx - sign * 0.48
                by = ny + 0.48
                bd = math.hypot(bx, by)
                ear_sdf = abs(bd - 0.16) - 0.045
                if sign * nx > 0.15 and ny < -0.25:
                    bell_alpha = max(bell_alpha, 1.0 - smoothstep(-0.008, 0.008, ear_sdf))

            # Simbolo + al centro
            bar_h = sd_rounded_box(nx, ny + 0.06, 0.24, 0.055, 0.025)
            bar_v = sd_rounded_box(nx, ny + 0.06, 0.055, 0.24, 0.025)
            plus_sdf = min(bar_h, bar_v)
            plus_alpha = 1.0 - smoothstep(-0.008, 0.008, plus_sdf)

            # Sbarretta inferiore
            eq_top = sd_rounded_box(nx, ny - 0.25, 0.16, 0.032, 0.015)
            eq_alpha = 1.0 - smoothstep(-0.008, 0.008, eq_top)

            # Gradiente caldo per anello e campane (#FF3B30 -> #FF9500)
            grad_t = max(0.0, min(1.0, (1.0 - ny) * 0.5))
            accent_r = 255.0
            accent_g = 59.0 + (154.0 - 59.0) * grad_t
            accent_b = 48.0 * (1.0 - grad_t)

            col_r, col_g, col_b = bg_r, bg_g, bg_b

            outer_alpha = max(ring_alpha, bell_alpha)
            if outer_alpha > 0.0:
                col_r = col_r * (1.0 - outer_alpha) + accent_r * outer_alpha
                col_g = col_g * (1.0 - outer_alpha) + accent_g * outer_alpha
                col_b = col_b * (1.0 - outer_alpha) + accent_b * outer_alpha

            if plus_alpha > 0.0:
                col_r = col_r * (1.0 - plus_alpha) + 255.0 * plus_alpha
                col_g = col_g * (1.0 - plus_alpha) + 255.0 * plus_alpha
                col_b = col_b * (1.0 - plus_alpha) + 255.0 * plus_alpha

            if eq_alpha > 0.0:
                col_r = col_r * (1.0 - eq_alpha) + 255.0 * eq_alpha
                col_g = col_g * (1.0 - eq_alpha) + 175.0 * eq_alpha
                col_b = col_b * (1.0 - eq_alpha) + 64.0 * eq_alpha

            idx = x * 3
            row[idx] = clamp_byte(col_r)
            row[idx + 1] = clamp_byte(col_g)
            row[idx + 2] = clamp_byte(col_b)
        rows.append(bytes(row))
    return rows


def main() -> None:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    asset_1024 = os.path.join(
        repo_root,
        "Sveglia",
        "Resources",
        "Assets.xcassets",
        "AppIcon.appiconset",
        "AppIcon-1024.png",
    )
    icons_dir = os.path.join(repo_root, "Sveglia", "Resources", "Icons")

    targets = [
        (1024, asset_1024),
        (1024, os.path.join(icons_dir, "AppIcon-1024.png")),
        (180, os.path.join(icons_dir, "AppIcon60x60@3x.png")),
        (120, os.path.join(icons_dir, "AppIcon60x60@2x.png")),
    ]

    cache: dict[int, list[bytes]] = {}
    for size, path in targets:
        print(f"Generazione icona {size}x{size} in {path}...")
        if size not in cache:
            cache[size] = render_icon(size)
        write_png(path, size, size, cache[size])

    print("Tutte le icone generate con successo.")


if __name__ == "__main__":
    main()
