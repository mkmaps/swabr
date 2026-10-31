# Inventory: cache/log/temp-like folders in the home folder that no Swabr clean rule covers (>= 20 MB).
#   python3 -I Tools/rules/inventory.py Packages/SwabrCore/Sources/SwabrCore/Resources/clean_rules.json inventory.tsv
import json, os, re, sys, glob, fnmatch, subprocess

HOME = os.path.expanduser("~")
rules = json.load(open(sys.argv[1]))

def braces(p):
    m = re.search(r"\{([^{}]*)\}", p)
    if not m:
        return [p]
    out = []
    for alt in m.group(1).split(","):
        out += braces(p[:m.start()] + alt + p[m.end():])
    return out

covered = set()
excl = []
for r in rules:
    for pat in r["paths"]:
        for p in braces(pat.replace("~", HOME, 1)):
            for hit in glob.glob(p):
                covered.add(hit)
    for e in r.get("exclude") or []:
        excl.append(e.replace("~", HOME, 1))
# dynamic rules
for d in [".npm/_cacache", ".npm/_npx", ".npm/_logs", ".bun/install/cache", ".cache/uv", ".cache/node/corepack",
          ".rustup/downloads", ".rustup/tmp"]:
    for hit in glob.glob(os.path.join(HOME, d, "*")):
        covered.add(hit)

def is_covered(path):
    if path in covered:
        return True
    # covered if it is a child of a covered path, or a parent whose children are all covered
    a = path
    while len(a) > len(HOME):
        if a in covered:
            return True
        a = os.path.dirname(a)
    try:
        kids = [os.path.join(path, k) for k in os.listdir(path)]
    except OSError:
        return False
    return bool(kids) and all(k in covered for k in kids if not os.path.basename(k).startswith("."))

NAME = re.compile(r"(?i)^(caches?|.*[-_ ]cache|cache[-_ ].*|cachedata|cached.*|logs?|tmp|temp|crashpad|crash.?reports?|"
                  r"gpucache|code cache|shadercache|blob_storage|updates?|downloads?|thumbnails?|\.cache|webcache.*)$")
ROOTS = ["Library/Application Support", "Library/Caches", "Library/Containers", "Library/Group Containers",
         "Library/Logs", "Library/Developer", "Library/HTTPStorages", "Library/WebKit"]
cands = []
def walk(root, maxdepth):
    base = root.count(os.sep)
    for dirpath, dirnames, _ in os.walk(root):
        depth = dirpath.count(os.sep) - base
        keep = []
        for d in dirnames:
            full = os.path.join(dirpath, d)
            if os.path.islink(full):
                continue
            if NAME.match(d):
                cands.append(full)
            elif depth < maxdepth:
                keep.append(d)
        dirnames[:] = keep
for r in ROOTS:
    walk(os.path.join(HOME, r), 6 if "Containers" in r else 4)
# top-level of ~/Library/Caches: every vendor folder counts
for d in glob.glob(os.path.join(HOME, "Library/Caches/*")):
    cands.append(d)
for d in glob.glob(os.path.join(HOME, ".*")):
    if os.path.isdir(d) and not os.path.islink(d):
        walk(d, 3)

def du(p):
    try:
        out = subprocess.run(["/usr/bin/du", "-skx", p], capture_output=True, text=True, timeout=60).stdout
        return int(out.split()[0]) * 1024
    except Exception:
        return 0

rows = []
seen = set()
for c in sorted(set(cands)):
    if any(c.startswith(s + "/") for s in seen):
        continue
    if is_covered(c):
        continue
    if any(fnmatch.fnmatch(c, e) for e in excl) and "com.apple" in c:
        tag = "excluded-apple"
    else:
        tag = "uncovered"
    size = du(c)
    if size < 20 * 1024 * 1024:
        continue
    seen.add(c)
    rows.append((size, tag, c.replace(HOME, "~")))
rows.sort(reverse=True)
with open(sys.argv[2], "w") as f:
    for s, t, p in rows:
        f.write(f"{s/1048576:.0f} MB\t{t}\t{p}\n")
print(len(covered), "covered paths;", len(rows), "uncovered candidates >= 20 MB")
