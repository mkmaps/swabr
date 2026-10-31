"""Checks manual translations against English: same count, same placeholders in the same order."""
import json, re, sys
spec = re.compile(r'%(\d+\$)?(lld|ld|d|@|lf|\.\df|f|%)')
en = json.load(open('en_part1.json')) + json.load(open('en_part2.json'))
for lang in sys.argv[1:]:
    t = json.load(open(f'manual/{lang}_1.json')) + json.load(open(f'manual/{lang}_2.json'))
    problems = [i for i, (a, b) in enumerate(zip(en, t)) if spec.findall(a) != spec.findall(b)]
    print(lang, len(t), "von", len(en), "· Platzhalter-Fehler:", [(i, en[i], t[i]) for i in problems][:5])
