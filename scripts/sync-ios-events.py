#!/usr/bin/env python3
"""Rewrite src/events/ios-events.json from the RNZoomUsEmit calls in ios/*.m.

generate-ios-delegates.py wrote that manifest once, as a side effect of
generating the delegate categories, and it refuses to run again once the sources
contain emit calls. So every event added by hand afterwards was missing from the
TypeScript types -- nine of them by the time this was written. Reading the emit
sites instead makes the manifest reproducible: the sources are the truth.

Run from the repository root:  python3 scripts/sync-ios-events.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = sorted((ROOT / "ios").glob("*.m"))
OUT = ROOT / "src/events/ios-events.json"


def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    return re.sub(r'//[^\n]*', '', s)


def ts_for_objc(objc_type):
    t = objc_type.strip()
    if re.match(r'^BOOL$', t):
        return "boolean"
    if "NSArray" in t:
        return "string[]" if "NSString" in t else "number[]"
    if "NSString" in t:
        return "string | null"
    if re.search(r'\*', t):
        return "boolean"          # object params are emitted as "<name>Present"
    return "number"               # NSUInteger/NSInteger/int and every enum


def params_of(signature):
    """[(label, objc type, name)] for a method signature."""
    return [(m.group(1), m.group(2), m.group(3)) for m in
            re.finditer(r'([A-Za-z_]\w*)\s*:\s*\(([^)]*)\)\s*(\w+)', signature)]


def type_for_value(expr, by_name):
    expr = expr.strip()
    m = re.match(r'^@\(\s*(\w+)\s*!=\s*nil\s*\)$', expr)
    if m:
        return "boolean"
    m = re.match(r'^@\(\s*(\w+)\s*\)$', expr)
    if m and m.group(1) in by_name:
        return ts_for_objc(by_name[m.group(1)])
    m = re.match(r'^(\w+)\s*\?:\s*\[NSNull null\]$', expr)
    if m:
        return ts_for_objc(by_name.get(m.group(1), "NSString *"))
    m = re.match(r'^(\w+)\s*\?:\s*@\[\]$', expr)
    if m:
        return ts_for_objc(by_name.get(m.group(1), "NSArray<NSNumber *> *"))
    if expr.startswith('@"'):
        return "string"
    if re.match(r'^@\(', expr):
        return "number"
    return "unknown"


def split_pairs(body):
    """@{@"k": v, @"k2": v2} -> [(k, v)], respecting nesting."""
    out, i, n = [], 0, len(body)
    while i < n:
        m = re.compile(r'@"(\w+)"\s*:').search(body, i)
        if not m:
            break
        key, j, depth = m.group(1), m.end(), 0
        while j < n:
            c = body[j]
            if c in '([{':
                depth += 1
            elif c in ')]}':
                if depth == 0:
                    break
                depth -= 1
            elif c == ',' and depth == 0:
                break
            j += 1
        out.append((key, body[m.end():j]))
        i = j + 1
    return out


def main():
    manifest = {}
    conflicts = []
    for path in SOURCES:
        src = strip_comments(path.read_text(errors="replace"))
        # enclosing method for each offset
        methods = []
        for m in re.finditer(r'(?:^|\n)\s*[-+]\s*\([^)]*\)([^;{]*?)\s*;?\s*\{', src):
            methods.append((m.start(), m.group(1)))
        for m in re.finditer(r'RNZoomUsEmit\(\s*@"(\w+)"\s*,\s*(nil|@\{)', src):
            event, kind = m.group(1), m.group(2)
            sig = ""
            for off, s in methods:
                if off <= m.start():
                    sig = s
                else:
                    break
            by_name = {n: t for _, t, n in params_of(sig)}
            if kind == "nil":
                fields = []
            else:
                j, depth = m.end() - 1, 0
                while j < len(src):
                    if src[j] == '{':
                        depth += 1
                    elif src[j] == '}':
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                fields = [(k, type_for_value(v, by_name))
                          for k, v in split_pairs(src[m.end():j])]
            prev = manifest.get(event)
            if prev is not None and dict(prev) != dict(fields):
                conflicts.append((event, path.name, dict(prev), dict(fields)))
                merged = dict(prev)
                for k, t in fields:
                    if k in merged and merged[k] != t:
                        merged[k] = " | ".join(sorted({merged[k], t}))
                    else:
                        merged.setdefault(k, t)
                manifest[event] = sorted(merged.items())
            else:
                manifest[event] = sorted(fields)

    if conflicts:
        print(f"{len(conflicts)} event có payload khác nhau giữa các file, đã hợp nhất:")
        for e, f, a, b in conflicts[:10]:
            print(f"  {e} ({f}): {a} vs {b}")
    OUT.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
    print(f"wrote {OUT.relative_to(ROOT)} with {len(manifest)} events")


if __name__ == "__main__":
    main()
