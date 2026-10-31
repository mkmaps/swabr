# Builds the two String Catalogs (app and SwabrCore) from the translation sources in Tools/i18n.
#   python3 -I Tools/i18n/build_catalogs.py
import json, os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(os.path.dirname(here))
load = lambda p: json.load(open(os.path.join(here, p), encoding="utf-8"))

OLD = 'do shell script "%@" with prompt "Swabr möchte Wartungsaufgaben ausführen." with administrator privileges without altering line endings'
NEW = "Swabr möchte Wartungsaufgaben ausführen."
keys = [NEW if k == OLD else k for k in load("keys_all.json")]
fix = lambda ks: [NEW if k == OLD else k for k in ks]

# German is the source language; listing it explicitly makes the build emit a de.lproj, so German
# is a real localization and not just the fallback (otherwise de-DE users could land on English).
langs = {"de": {k: k for k in keys}, "en": load("en.json")}
langs.update(load("mt.json"))
for lang in ("cs", "sk", "hu", "ro", "el", "hr"):
    vals = load(f"manual/{lang}_1.json") + load(f"manual/{lang}_2.json")
    langs[lang] = dict(zip(keys, vals))

# Strings added after the big translation pass: {"<German key>": {"<lang>": "…"}}, app catalog only.
extra = load("extra.json")
for k, by_lang in extra.items():
    langs["de"][k] = k
    for l, v in by_lang.items():
        langs[l][k] = v

# Texts that no longer exist in the app (dropped from every catalogue).
REMOVED: set[str] = set()

# Strings of the core library added later (rule names of the clean-up catalogue and the like).
extra_core = load("extra_core.json")
for k, by_lang in extra_core.items():
    langs["de"][k] = k
    for l, v in by_lang.items():
        langs[l][k] = v

# DeepL translations (fr, es, it, pt-PT) replace the earlier machine translations; corrections from
# proofreading (deepl/overrides.json, keyed by the English text) win over DeepL.
english = dict(langs["en"])
for k, v in list(extra.items()) + list(extra_core.items()):
    english[k] = v["en"]
overrides = load("deepl/overrides.json")
for lang in ("fr", "es", "it", "pt-PT"):
    path = os.path.join(here, f"deepl/{lang}.json")
    if not os.path.exists(path):
        continue
    langs[lang].update(load(f"deepl/{lang}.json"))  # keeps later additions from extra*.json
    for k, by_lang in list(extra.items()) + list(extra_core.items()):
        if lang in by_lang and k not in load(f"deepl/{lang}.json"):
            langs[lang][k] = by_lang[lang]
    for k, en in english.items():
        if lang in overrides.get(en, {}):
            langs[lang][k] = overrides[en][lang]

# Every translation must keep exactly the format specifiers of its German key and no stray "%":
# a lone "%" followed by a letter is itself a specifier and would crash or garble the text.
SPEC = re.compile(r"%(\d+\$)?(lld|ld|d|@|\.1f|lf|f|%)")
errors = []
for lang, m in langs.items():
    for k, v in m.items():
        if sorted(x.group(0) for x in SPEC.finditer(v)) != sorted(x.group(0) for x in SPEC.finditer(k)) or "%" in SPEC.sub("", v):
            errors.append(f"{lang}: {k!r} -> {v!r}")
if errors:
    sys.exit("Format specifiers broken:\n" + "\n".join(errors))

def catalog(subset):
    strings = {}
    for k in sorted(subset):
        locs = {l: {"stringUnit": {"state": "translated", "value": m[k]}} for l, m in sorted(langs.items()) if k in m}
        strings[k] = {"localizations": locs}
    return {"sourceLanguage": "de", "strings": strings, "version": "1.0"}

for subset, path in (([k for k in fix(load("keys_app.json")) if k not in REMOVED] + list(extra), "Resources/Localizable.xcstrings"),
                     (load("keys_core.json") + [k for k in extra_core if k not in load("keys_core.json")], "Packages/SwabrCore/Sources/SwabrCore/Resources/Localizable.xcstrings")):
    with open(os.path.join(root, path), "w", encoding="utf-8") as f:
        json.dump(catalog(subset), f, ensure_ascii=False, indent=2, sort_keys=True)
    print(path, len(subset), sorted(langs))
