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
# r5: r1 with the page lock no longer pinning <body> (position stays static; html overflow hidden is kept)
ritmo("r5", [])
for js in (P / "r5" / "assets").glob("*.js"):
    t = js.read_text()
    if 'n(document.body.style,"position","fixed")' in t:
        js.write_text(t.replace('n(document.body.style,"position","fixed")', 'n(document.body.style,"position","static")')); print("r5 lock unpinned in", js.name)
ritmo("r2", ["theme"])
ritmo("r3", ["manifest"])
ritmo("r4", ["theme", "manifest", "icon"])

base = (P / "static-v5.html").read_text()
LOCK = """<script>
// s3: while a sheet is open, pin <body> the way RITMO's page lock does (position fixed, top -scrollY, width 100%).
(function () { var o = HTMLDialogElement.prototype.showModal, c = HTMLDialogElement.prototype.close;
  HTMLDialogElement.prototype.showModal = function () { var b = document.body.style; b.position = "fixed"; b.top = -scrollY + "px"; b.left = "0px"; b.width = "100%"; b.overflow = "hidden"; return o.apply(this, arguments); };
  HTMLDialogElement.prototype.close = function () { var b = document.body.style; b.position = b.top = b.left = b.width = b.overflow = ""; return c.apply(this, arguments); }; })();
</script>
"""
for name, head in (("s1", ""), ("s2", '<meta name="theme-color" content="#f4f2ec">\n<link rel="manifest" href="./manifest.webmanifest">\n'), ("s3", LOCK)):
    d = P / name; d.mkdir(exist_ok=True)
    h = base.replace('content="SB static"', f'content="B {name}"').replace("<title>SB static</title>", f"<title>B {name}</title>")
    h = h.replace('<meta name="apple-mobile-web-app-title"', head + '<meta name="apple-mobile-web-app-title"', 1)
    (d / "index.html").write_text(h)
    (d / "manifest.webmanifest").write_text(json.dumps({"name": f"B {name}", "short_name": f"B {name}", "start_url": "./", "display": "standalone", "background_color": "#f4f2ec", "theme_color": "#f4f2ec"}))
    print(name, {"": "as SB static"}.get(head, "with " + ("page lock" if "s3" in head else "theme+manifest")))
