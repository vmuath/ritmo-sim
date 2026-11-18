#!/usr/bin/env python3
"""Strip-vs-page mismatch score for a screen recording of RITMO (iPhone 16 Pro, portrait).

iOS paints the area behind the clock (the "strip") itself, in one flat colour. The score is how long,
and by how much, that strip differs from the page right below it. Every frame is compared:
  strip = left of the clock (10 pt, 20 pt); page = just under the strip (10 pt, top + 12 pt),
where top is 62 pt (the page starts below the clock in RITMO's mode) unless --top is given.
A mismatch frame differs by more than --tol on any colour channel. Consecutive mismatch frames make
one event. Prints each event (start, length in ms, worst difference) and the total.

    python3 strip_score.py recording.mp4 [--top 62] [--tol 24] [--from 0] [--to 999]

Needs ffmpeg/ffprobe. Frames are taken at their real timestamps (screen recordings have a variable rate).
"""
import argparse, subprocess, sys, tempfile, os, glob

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video"); ap.add_argument("--top", type=float, default=62)
    ap.add_argument("--tol", type=int, default=24)
    ap.add_argument("--from", dest="t0", type=float, default=0); ap.add_argument("--to", dest="t1", type=float, default=1e9)
    a = ap.parse_args()
    from PIL import Image
    pts = [float(x.strip(",")) for x in subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "frame=pts_time", "-of", "csv=p=0", a.video],
        capture_output=True, text=True).stdout.split() if x.strip(",")]
    d = tempfile.mkdtemp()
    subprocess.run(["ffmpeg", "-v", "error", "-i", a.video, "-vsync", "0", "-vf", "scale=402:-1", f"{d}/%05d.png"], check=True)
    files = sorted(glob.glob(f"{d}/*.png"))
    events, cur, total = [], None, 0.0
    for i, f in enumerate(files):
        t = pts[i] if i < len(pts) else pts[-1]
        if t < a.t0 or t > a.t1: continue
        im = Image.open(f).convert("RGB")
        s = im.getpixel((10, 20)); p = im.getpixel((10, int(a.top + 12)))
        diff = max(abs(x - y) for x, y in zip(s, p))
        dt = (pts[i + 1] - t) if i + 1 < len(pts) else 1 / 60
        if diff > a.tol:
            if cur is None: cur = {"start": t, "ms": 0.0, "worst": 0, "strip": s, "page": p}
            cur["ms"] += dt * 1000; cur["worst"] = max(cur["worst"], diff); total += dt * 1000
        elif cur is not None:
            events.append(cur); cur = None
    if cur: events.append(cur)
    for e in events:
        print(f"{e['start']:7.3f}s  {e['ms']:6.0f} ms  worst {e['worst']:3d}  strip{e['strip']} page{e['page']}")
    print(f"TOTAL {total:.0f} ms over {len(events)} events")

if __name__ == "__main__":
    main()
