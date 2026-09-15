#!/usr/bin/env python3
"""uiautomator dump → okunabilir metin / dokunma koordinatı.

Kullanım:
  uia.py dump.xml                     ekrandaki tüm metinleri (sırayla) yaz
  uia.py dump.xml --find "Ayarlar"    metni/content-desc'i eşleşen ilk node'un
                                      merkez koordinatını "x y" olarak yaz
"""
import re
import sys
import xml.etree.ElementTree as ET


def nodes(path):
    tree = ET.parse(path)
    for n in tree.iter("node"):
        b = n.get("bounds") or ""
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
        if not m:
            continue
        x1, y1, x2, y2 = (int(v) for v in m.groups())
        yield {
            "text": (n.get("text") or "").strip(),
            "desc": (n.get("content-desc") or "").strip(),
            "cls": n.get("class") or "",
            "clickable": n.get("clickable") == "true",
            "cx": (x1 + x2) // 2,
            "cy": (y1 + y2) // 2,
        }


def main():
    if len(sys.argv) < 2:
        print("kullanım: uia.py <dump.xml> [--find <metin>]", file=sys.stderr)
        return 2
    path = sys.argv[1]
    try:
        items = list(nodes(path))
    except Exception as e:  # bozuk/boş dump
        print("(dump okunamadı: %s)" % e)
        return 1

    if "--find" in sys.argv:
        needle = sys.argv[sys.argv.index("--find") + 1].lower()
        for it in items:
            if needle in it["text"].lower() or needle in it["desc"].lower():
                print("%d %d" % (it["cx"], it["cy"]))
                return 0
        return 1

    seen = []
    for it in items:
        label = it["text"] or it["desc"]
        if not label:
            continue
        seen.append(label)
    print("\n".join(seen) if seen else "(ekranda metin yok)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
