#!/usr/bin/env python3
"""Gera as notas da release (markdown) a partir de assets/changelog.json."""
import json
import sys

version = sys.argv[1]
entries = json.load(open("assets/changelog.json", encoding="utf-8"))
e = next((x for x in entries if x["version"] == version), None)
if e is None:
    print(f"Master Music {version}")
    sys.exit(0)

out = [f"## {e['title']}", ""]
for key, label in (("added", "✨ Adicionado"), ("improved", "⚡ Melhorado"), ("fixed", "🛠️ Corrigido")):
    items = e.get(key) or []
    if items:
        out.append(f"### {label}")
        out += [f"- {i}" for i in items]
        out.append("")
print("\n".join(out))
