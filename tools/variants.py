"""Builds the bisect variants under pages/ (run on the runner before the test):
r1..r4: RITMO Dev's own build (black-translucent) with parts of its head removed; s1, s2: the SB static test page
(s2 with RITMO's theme-color and manifest added). Each gets its own folder, title and manifest name, so each installs
as its own Home Screen app ("B r1" ...)."""
import json, re, shutil, sys
from pathlib import Path
P = Path(sys.argv[1] if len(sys.argv) > 1 else "pages")
src = P / "ritmo-dist"
THEME = re.compile(r'<meta name="theme-color" content="#f4f2ec"/>')
MANI = re.compile(r'<link rel="manifest" href="./manifest.webmanifest">')
ICON = re.compile(r'<link rel="apple-touch-icon" href="./apple-touch-icon.png"/>')

def ritmo(name, drop):
    d = P / name
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(src, d)
    h = (d / "index.html").read_text()
    for meta in ("apple-mobile-web-app-title", "application-name"):
        h, n = re.subn(f'<meta name="{meta}" content="RITMO"/>', f'<meta name="{meta}" content="B {name}"/>', h); assert n == 1, (name, meta)
    h = h.replace("<title>RITMO</title>", f"<title>B {name}</title>")
    for what, rx in (("theme", THEME), ("manifest", MANI), ("icon", ICON)):
        if what in drop:
            h, n = rx.subn("", h); assert n == 1, (name, what, n)
    (d / "index.html").write_text(h)
    m = json.loads((d / "manifest.webmanifest").read_text()); m["name"] = m["short_name"] = f"B {name}"
    (d / "manifest.webmanifest").write_text(json.dumps(m))
    print(name, "drops", drop or "nothing", "| theme", '<meta name="theme-color"' in h, "manifest", 'rel="manifest"' in h)

ritmo("r1", [])
ritmo("r2", ["theme"])
ritmo("r3", ["manifest"])
ritmo("r4", ["theme", "manifest", "icon"])

base = (P / "static-v5.html").read_text()
for name, head in (("s1", ""), ("s2", '<meta name="theme-color" content="#f4f2ec">\n<link rel="manifest" href="./manifest.webmanifest">\n')):
    d = P / name; d.mkdir(exist_ok=True)
    h = base.replace('content="SB static"', f'content="B {name}"').replace("<title>SB static</title>", f"<title>B {name}</title>")
    h = h.replace('<meta name="apple-mobile-web-app-title"', head + '<meta name="apple-mobile-web-app-title"', 1)
    (d / "index.html").write_text(h)
    (d / "manifest.webmanifest").write_text(json.dumps({"name": f"B {name}", "short_name": f"B {name}", "start_url": "./", "display": "standalone", "background_color": "#f4f2ec", "theme_color": "#f4f2ec"}))
    print(name, "theme+manifest" if head else "as SB static")
