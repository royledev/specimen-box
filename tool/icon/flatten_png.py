#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""透過 PNG を背景色で塗りつぶして不透過 RGB PNG にする（標準ライブラリのみ）。

iOS アプリアイコンは透過不可のため、四隅などの透明部分を背景色で合成する。
背景色は未指定なら画像上部中央 (w/2, 24) のピクセルから自動取得する。

使い方: flatten_png.py <in.png> <out.png> [#RRGGBB]
対応: 8bit / colortype 2(RGB) or 6(RGBA) / 非インターレース
"""
import sys, zlib, struct

def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos = 8
    width = height = bitd = ctype = inter = None
    idat = bytearray()
    plte = None
    trns = None
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos+4])[0]
        typ = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+ln]
        if typ == b"IHDR":
            width, height, bitd, ctype, comp, filt, inter = struct.unpack(">IIBBBBB", chunk)
        elif typ == b"PLTE":
            plte = chunk
        elif typ == b"tRNS":
            trns = chunk
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
        pos += 12 + ln
    assert bitd == 8, f"unsupported bit depth {bitd}"
    assert inter == 0, "interlaced not supported"
    raw = zlib.decompress(bytes(idat))

    if ctype == 6:
        ch = 4
    elif ctype == 2:
        ch = 3
    elif ctype == 3:
        ch = 1
    else:
        raise SystemExit(f"unsupported color type {ctype}")

    stride = width * ch
    out = bytearray(stride * height)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        ft = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if ft == 1:  # Sub
            for i in range(ch, stride):
                line[i] = (line[i] + line[i-ch]) & 255
        elif ft == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:  # Average
            for i in range(stride):
                a = line[i-ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:  # Paeth
            for i in range(stride):
                a = line[i-ch] if i >= ch else 0
                b = prev[i]
                c = prev[i-ch] if i >= ch else 0
                pp = a + b - c
                pa = abs(pp - a); pb = abs(pp - b); pc = abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y*stride:(y+1)*stride] = line
        prev = line

    # パレット展開（必要なら）
    if ctype == 3:
        rgba = bytearray(width*height*4)
        for i in range(width*height):
            idx = out[i]
            rgba[i*4] = plte[idx*3]; rgba[i*4+1] = plte[idx*3+1]; rgba[i*4+2] = plte[idx*3+2]
            rgba[i*4+3] = trns[idx] if (trns and idx < len(trns)) else 255
        return width, height, 4, rgba
    return width, height, ch, out

def write_rgb_png(path, w, h, rgb):
    raw = bytearray()
    stride = w*3
    for y in range(h):
        raw.append(0)  # filter none
        raw += rgb[y*stride:(y+1)*stride]
    comp = zlib.compress(bytes(raw), 9)
    def chunk(typ, body):
        return struct.pack(">I", len(body)) + typ + body + struct.pack(">I", zlib.crc32(typ+body) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))

def main():
    inp, outp = sys.argv[1], sys.argv[2]
    w, h, ch, px = read_png(inp)
    if len(sys.argv) > 3:
        c = sys.argv[3].lstrip("#")
        bg = (int(c[0:2],16), int(c[2:4],16), int(c[4:6],16))
    else:
        # 上部中央のピクセルを背景色とする
        sx, sy = w//2, 24
        i = (sy*w+sx)*ch
        bg = (px[i], px[i+1], px[i+2])
    print("bg = #%02X%02X%02X" % bg)
    rgb = bytearray(w*h*3)
    for j in range(w*h):
        si = j*ch
        if ch == 4:
            a = px[si+3]
            for k in range(3):
                rgb[j*3+k] = (px[si+k]*a + bg[k]*(255-a) + 127)//255
        else:
            for k in range(3):
                rgb[j*3+k] = px[si+k]
    write_rgb_png(outp, w, h, rgb)
    print("wrote", outp)

if __name__ == "__main__":
    main()
