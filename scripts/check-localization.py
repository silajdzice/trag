#!/usr/bin/env python3
"""Fails if a string used in the app is missing from Localizable.xcstrings or lacks a Bosnian translation.

Usage: check-localization.py <DerivedData path>  (after an app build, which extracts .stringsdata files)
"""
import glob
import json
import sys
from pathlib import Path

LANGUAGES = ["bs"]
root = Path(__file__).resolve().parent.parent
catalog = json.loads((root / "Trag/Resources/Localizable.xcstrings").read_text(encoding="utf-8"))["strings"]

used = set()
for path in glob.glob(f"{sys.argv[1]}/**/Trag.build/**/*.stringsdata", recursive=True):
    for entries in json.loads(Path(path).read_text(encoding="utf-8")).get("tables", {}).values():
        used.update(entry["key"] for entry in entries)

if not used:
    sys.exit("No extracted strings found. Build the app first.")

problems = [f"missing from catalog: {key!r}" for key in sorted(used - catalog.keys())]
for key, entry in catalog.items():
    for language in LANGUAGES:
        localization = entry.get("localizations", {}).get(language)
        if not localization:
            problems.append(f"no {language} translation: {key!r}")
        elif "stringUnit" in localization and localization["stringUnit"].get("state") != "translated":
            problems.append(f"{language} not marked translated: {key!r}")
problems += [f"unused in code: {key!r}" for key in sorted(catalog.keys() - used)]

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"Localization OK: {len(used)} strings, translated into {', '.join(LANGUAGES)}")
