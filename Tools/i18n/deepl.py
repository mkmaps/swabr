# Translates Swabr's UI strings and help pages with the DeepL API (key in ~/.config/deepl/key).
#   python3 -I Tools/i18n/deepl.py ui fr            -> Tools/i18n/deepl/fr.json  {"<German key>": "…"}
#   python3 -I Tools/i18n/deepl.py help fr          -> Resources/Help/fr/*.md
#   python3 -I Tools/i18n/deepl.py glossary cs      -> Tools/i18n/glossary/cs.json from the hand-made UI strings
#
# English is the source (reviewed by hand). Placeholders and `code` are protected as ignored XML tags,
# every request carries a context hint, and the UI terms in glossary/<lang>.json are enforced: exact
# matches are taken as they are, longer texts go through a DeepL glossary built from the multi-word terms.
import glob, html, json, os, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
KEY = open(os.path.expanduser("~/.config/deepl/key")).read().strip()
API = "https://api-free.deepl.com/v2/" if KEY.endswith(":fx") else "https://api.deepl.com/v2/"
TARGET = {"pt-PT": "PT-PT", "fr": "FR", "es": "ES", "it": "IT", "cs": "CS", "sk": "SK", "hu": "HU", "ro": "RO", "hr": "HR", "el": "EL"}
# Apple's own tone per language: vous in French and Portuguese, tú/tu in Spanish and Italian.
FORMALITY = {"fr": "prefer_more", "pt-PT": "prefer_more", "es": "prefer_less", "it": "prefer_less"}
UI_CONTEXT = ("User interface text of Swabr, a macOS app that cleans up the Mac, uninstalls apps and shows storage use. "
              "Short texts are buttons, menu items, section titles or labels; use the wording of macOS itself.")
HELP_CONTEXT = ("Help page of Swabr, a macOS utility that cleans up the Mac. Keep the app's UI terms exactly as given "
                "and the tone of Apple's own help.")
SPEC = re.compile(r"%(\d+\$)?(lld|ld|d|@|\.1f|lf|f|%)")
load = lambda p: json.load(open(os.path.join(HERE, p), encoding="utf-8"))


def call(endpoint, payload=None, method="POST"):
    # curl uses the system's certificates (the python.org build of Python ships none); the key goes via stdin
    # config, so it never appears in the process list.
    config = f'header = "Authorization: DeepL-Auth-Key {KEY}"\nheader = "Content-Type: application/json"\n'
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(payload, f)
    try:
        args = ["--data-binary", "@" + f.name] if payload is not None else []
        r = subprocess.run(["curl", "-sS", "--fail-with-body", "-X", method, "-K", "-", *args, API + endpoint],
                           input=config, capture_output=True, text=True, timeout=300)
    finally:
        os.unlink(f.name)
    if r.returncode != 0:
        raise RuntimeError(f"DeepL {endpoint}: {r.stdout or r.stderr}")
    return json.loads(r.stdout) if r.stdout.strip() else {}


def drop_glossaries():
    """The free plan allows one glossary at a time: remove ours (and leftovers of aborted runs)."""
    for g in call("glossaries", method="GET").get("glossaries", []):
        if g["name"].startswith("swabr-"):
            call("glossaries/" + g["glossary_id"], method="DELETE")


def deepl_glossary(lang, glossary):
    """DeepL glossary from the multi-word terms only: single words like "Update" would also hit nouns in sentences."""
    if lang == "hr":
        return None  # DeepL has no glossaries for Croatian; terms are checked afterwards
    entries = {k: v for k, v in glossary.items() if len(k.split()) > 1 or k in ("Trash", "Finder", "Gatekeeper")}
    tsv = "\n".join(f"{k.replace(' …', '')}\t{v.replace('…', '').strip()}" for k, v in entries.items())
    g = call("glossaries", {"name": f"swabr-{lang}", "source_lang": "en", "target_lang": lang.split("-")[0],
                            "entries": tsv, "entries_format": "tsv"})
    return g["glossary_id"]


def translate(texts, lang, context, glossary_id):
    out = []
    for i in range(0, len(texts), 40):
        payload = {"text": texts[i:i + 40], "source_lang": "EN", "target_lang": TARGET[lang], "context": context,
                   "tag_handling": "xml", "ignore_tags": ["x", "k", "sep"], "preserve_formatting": True}
        if lang in FORMALITY:
            payload["formality"] = FORMALITY[lang]
        if glossary_id:
            payload["glossary_id"] = glossary_id
        out += [t["text"] for t in call("translate", payload)["translations"]]
    return out


def protect(s):
    s = html.escape(s, quote=False)
    return SPEC.sub(lambda m: f"<x>{m.group(0)}</x>", s)


def unprotect(s):
    return html.unescape(re.sub(r"</?x>", "", s))


def ui(lang):
    glossary = load(f"glossary/{lang}.json")
    en = load("en.json")
    for extra in ("extra.json", "extra_core.json"):
        for k, v in load(extra).items():
            en[k] = v["en"]
    keys = sorted(en)
    fixed = {k: glossary[en[k]] for k in keys if en[k] in glossary}
    todo = [k for k in keys if k not in fixed]
    drop_glossaries()
    gid = deepl_glossary(lang, glossary)
    try:
        done = translate([protect(en[k]) for k in todo], lang, UI_CONTEXT, gid)
    finally:
        drop_glossaries()
    result = dict(fixed)
    for k, t in zip(todo, done):
        t = unprotect(t)
        if sorted(SPEC.findall(t)) != sorted(SPEC.findall(en[k])):
            print("placeholder mismatch, kept English:", en[k], "->", t)
            t = en[k]
        result[k] = t
    os.makedirs(os.path.join(HERE, "deepl"), exist_ok=True)
    json.dump(result, open(os.path.join(HERE, f"deepl/{lang}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=True)
    print(lang, len(result), "strings,", len(fixed), "from the glossary")


INLINE = re.compile(r"\*\*(.+?)\*\*|`([^`]+)`")


def inline_xml(s):
    out, last = "", 0
    for m in INLINE.finditer(s):
        out += html.escape(s[last:m.start()], quote=False)
        out += f"<b>{html.escape(m.group(1), quote=False)}</b>" if m.group(1) else f"<x>{html.escape(m.group(2), quote=False)}</x>"
        last = m.end()
    return out + html.escape(s[last:], quote=False)


def inline_md(el):
    s = el.text or ""
    for c in el:
        inner = "".join(c.itertext())
        s += f"**{inner}**" if c.tag == "b" else inner if c.tag == "k" else f"`{inner}`"
        s += c.tail or ""
    return s


def pin_terms(s, glossary):
    """UI terms in bold or quotes that the glossary knows are replaced by the app's own wording up front
    and protected, so the help names buttons and sections exactly as the app shows them."""
    def bold(m):
        inner = m.group(1)
        core = inner.strip('"“”')
        if core in glossary:
            return "**" + inner.replace(core, "\x00" + glossary[core] + "\x01") + "**"
        return m.group(0)
    s = re.sub(r"\*\*(.+?)\*\*", bold, s)
    # Section names of the app wherever they appear capitalised ("Clean Up finds …", "open Optimize").
    for term in ("Clean Up", "Slim Down", "Optimize", "Storage", "Projects", "Installers", "History", "Full Disk Access", "Protected Data"):
        if term in glossary:
            s = re.sub(rf"(?<![\w\x00\"*]){re.escape(term)}(?![\w\x01\"*])", "\x00" + glossary[term] + "\x01", s)
    # Menu paths such as "Settings → Behavior": both ends are UI names.
    for term in sorted(glossary, key=len, reverse=True):
        s = re.sub(rf"(?<![\w\x00]){re.escape(term)}(?= →)|(?<=→ ){re.escape(term)}(?![\w\x01])",
                   lambda m: "\x00" + glossary[term] + "\x01", s)
    return re.sub(r'"([^"]+)"', lambda m: '"\x00' + glossary[m.group(1)] + '\x01"' if m.group(1) in glossary else m.group(0), s)


def tidy(s):
    """Markup slips DeepL sometimes makes around protected tags."""
    s = re.sub(r"\*{4,}([^*]+?)\*{4,}", r"**\1**", s)
    s = re.sub(r"``([^`]+)``", r"`\1`", s)
    s = re.sub(r"(\*\*[^*]+\*\*)[a-zà-ÿ]\b", r"\1", s)  # "**À vérifier**s"
    return s


def help_doc(lang, gid):
    """Each line and table cell is translated on its own, so the Markdown structure can't shift; the whole
    English page goes along as context (DeepL uses it for meaning but does not translate or bill it)."""
    os.makedirs(os.path.join(ROOT, "Resources/Help", lang), exist_ok=True)
    for path in sorted(glob.glob(os.path.join(ROOT, "Resources/Help/en/*.md"))):
        text = open(path, encoding="utf-8").read()
        layout, segments = [], []
        for line in text.split("\n"):
            t = line.strip()
            if not t:
                layout.append(("", None))
            elif t.startswith("|"):
                cells = [c.strip() for c in t.strip("|").split("|")]
                if all(set(c) <= set("-: ") for c in cells):
                    layout.append((t, None))
                else:
                    layout.append(("|", list(range(len(segments), len(segments) + len(cells)))))
                    segments += cells
            else:
                prefix = next((p for p in ("### ", "## ", "# ", "- ", "> ") if t.startswith(p)), "")
                layout.append((prefix, [len(segments)]))
                segments.append(t[len(prefix):])
        glossary = load(f"glossary/{lang}.json")
        if "Never clean (protect)" in glossary:  # the help names the menu item without its hint
            glossary["Never clean"] = re.sub(r"\s*\(.*\)$", "", glossary["Never clean (protect)"])
        prepared = [inline_xml(pin_terms(x, glossary)).replace("\x00", "<k>").replace("\x01", "</k>") for x in segments]
        done = translate(prepared, lang, HELP_CONTEXT + "\n\nFull page:\n" + html.escape(text, quote=False), gid)
        md = [tidy(inline_md(ET.fromstring(f"<s>{d}</s>")).strip()) for d in done]
        lines = []
        for prefix, idx in layout:
            if idx is None:
                lines.append(prefix)
            elif prefix == "|":
                lines.append("| " + " | ".join(md[i] for i in idx) + " |")
            else:
                lines.append(prefix + md[idx[0]])
        open(os.path.join(ROOT, "Resources/Help", lang, os.path.basename(path)), "w", encoding="utf-8").write("\n".join(lines))
    print(lang, "help done")


def glossary_from_catalog(lang):
    """For the hand-translated languages: the same UI terms, taken from their own catalogue."""
    terms = load("glossary/fr.json").keys()
    en = load("en.json")
    keys = load("keys_all.json")
    vals = load(f"manual/{lang}_1.json") + load(f"manual/{lang}_2.json")
    old = 'do shell script "%@" with prompt "Swabr möchte Wartungsaufgaben ausführen." with administrator privileges without altering line endings'
    target = dict(zip(["Swabr möchte Wartungsaufgaben ausführen." if k == old else k for k in keys], vals))
    by_en = {}
    for k, v in en.items():
        if v in terms and k in target and v not in by_en:
            by_en[v] = target[k]
    # Menu names appear in the app only inside paths ("System Settings → Privacy & Security → Automation");
    # take them from those strings, component by component.
    catalog = json.load(open(os.path.join(ROOT, "Resources/Localizable.xcstrings"), encoding="utf-8"))["strings"]
    def path_of(german, lang_):
        v = catalog[german]["localizations"][lang_]["stringUnit"]["value"]
        inner = v[v.index("(") + 1:v.rindex(")")] if "(" in v else v
        return [c.strip(" .") for c in inner.split("→")]
    for german, names in (("Swabr darf den Finder nicht steuern (Systemeinstellungen → Datenschutz & Sicherheit → Automation)",
                           ["System Settings", "Privacy & Security", "Automation"]),
                          ("Bitte in Systemeinstellungen → Allgemein → Anmeldeobjekte erlauben.", [None, "General", "Login Items"])):
        for name, value in zip(names, path_of(german, lang)):
            if name:
                by_en[name] = value
    json.dump(by_en, open(os.path.join(HERE, f"glossary/{lang}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(lang, len(by_en), "glossary terms")




def batch(src, dest, langs):
    """{German key: English} -> merged into dest ({German key: {lang: text}}), e.g. extra_core.json."""
    items = load(src)
    out = load(dest) if os.path.exists(os.path.join(HERE, dest)) else {}
    keys = list(items)
    for k in keys:
        out.setdefault(k, {})["en"] = items[k]
    for lang in langs:
        glossary = load(f"glossary/{lang}.json")
        drop_glossaries()
        gid = deepl_glossary(lang, glossary)
        try:
            done = translate([protect(items[k]) for k in keys], lang, UI_CONTEXT, gid)
        finally:
            drop_glossaries()
        for k, t in zip(keys, done):
            t = glossary.get(items[k], unprotect(t))
            out[k][lang] = t
        print(lang, len(keys))
    json.dump(out, open(os.path.join(HERE, dest), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    mode, lang = sys.argv[1], sys.argv[2]
    if mode == "ui":
        ui(lang)
    elif mode == "help":
        drop_glossaries()
        try:
            help_doc(lang, deepl_glossary(lang, load(f"glossary/{lang}.json")))
        finally:
            drop_glossaries()
    elif mode == "glossary":
        glossary_from_catalog(lang)
    elif mode == "batch":  # deepl.py batch <src.json> <dest.json> fr es …
        batch(sys.argv[2], sys.argv[3], sys.argv[4:])
