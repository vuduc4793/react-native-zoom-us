#!/usr/bin/env python3
"""Introspect the Zoom iOS SDK headers and generate the typed command surface.

The iOS bridge is one NSInvocation in ios/RNZoomUsCommands.m, mirroring the
single reflective invoke() on Android, so this script emits no Objective-C: it
emits the *types*, which is what turns "any selector" into something with
autocomplete. A method added by a future SDK becomes callable the moment this is
re-run -- no native change, so it can ship as an OTA update.

Run from the repository root:  python3 scripts/generate-ios-commands.py
Override the headers with ZOOM_IOS_HEADERS=/path/to/MobileRTC.framework/Headers
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = ROOT / "src/commands/ios-api.json"
OUT_TS = ROOT / "src/commands/ios-generated.ts"
OUT_ROUTES = ROOT / "src/commands/ios-routes.ts"

# Parameters the bridge cannot carry. A block or a delegate has nothing on the
# JavaScript side to hand over (those arrive as events instead), and UIKit
# objects, structs and out-parameters cannot be marshalled either.
UNSUPPORTED_PARAM = re.compile(
    r"\^|id\s*<|Delegate|Handler\s*\*|\bUIView|\bUIViewController|\bUIImage|\bUIScene|"
    r"\bUINavigationController|\bUITraitCollection|\bCGRect|\bCGSize|\bCGPoint|"
    r"\bNSError\s*\*\s*\*|\bSEL\b|\bClass\b|\bvoid\s*\*"
)


def strip_comments(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)


def clean_type(t):
    t = re.sub(r"\b(_Nonnull|_Nullable|_Null_unspecified|nullable|nonnull|const|__kindof|__strong|__weak|__unsafe_unretained)\b", " ", t)
    return " ".join(t.split())


def ts_for(objc):
    t = clean_type(objc)
    if t in ("void",):
        return "void"
    if t == "BOOL":
        return "boolean"
    if "NSArray" in t:
        inner = re.search(r"NSArray\s*<([^>]*)>", t)
        if inner:
            it = clean_type(inner.group(1))
            if "NSString" in it:
                return "string[]"
            if "NSNumber" in it:
                return "number[]"
            return "ZoomObject[]"
        return "unknown[]"
    if "NSDictionary" in t:
        return "ZoomObject"
    if "NSString" in t:
        return "string | null"
    if "NSNumber" in t:
        return "number | null"
    if "NSData" in t:
        return "{ byteLength: number } | null"
    if "NSDate" in t:
        return "number | null"
    if t.endswith("*") or t.startswith("id"):
        return "ZoomObject | null"
    # NSInteger/NSUInteger/int/long/float/double and every MobileRTC enum: all
    # integers or doubles on the wire.
    return "number"


METHOD = re.compile(r"^\s*([-+])\s*\(([^)]*)\)\s*([^;{]+);", re.M)
PROPERTY = re.compile(r"^\s*@property\s*(?:\(([^)]*)\))?\s*(.+?)\s*(\w+)\s*;", re.M)


def parse_properties(body):
    """@property becomes its accessors: reading one is a zero-argument call and
    writing one is setX:, which is how they cross the bridge."""
    out = []
    for m in PROPERTY.finditer(body):
        attrs = [a.strip() for a in (m.group(1) or "").split(",")]
        objc_type, name = m.group(2), m.group(3)
        getter = next((a.split("=", 1)[1].strip() for a in attrs if a.startswith("getter")), name)
        out.append(("-", objc_type, getter, []))
        if "readonly" in attrs:
            continue
        setter = next((a.split("=", 1)[1].strip() for a in attrs if a.startswith("setter")),
                      "set" + name[0].upper() + name[1:] + ":")
        out.append(("-", "void", setter, [(objc_type, name)]))
    return out


def parse_methods(body):
    """[(kind, return type, selector, [(objc type, name)])]"""
    out = []
    for m in METHOD.finditer(body):
        kind, ret, sig = m.group(1), m.group(2), " ".join(m.group(3).split())
        sig = re.sub(r"\bDEPRECATED[A-Z_]*(_MSG)?_ATTRIBUTE\s*\([^)]*\)", "", sig)
        sig = re.sub(r"\b__attribute__\s*\(\(.*?\)\)", "", sig).strip()
        parts = re.findall(r"([A-Za-z_]\w*)\s*:\s*\(([^)]*)\)\s*(\w+)", sig)
        if parts:
            selector = "".join(p[0] + ":" for p in parts)
            params = [(p[1], p[2]) for p in parts]
        else:
            name = re.match(r"([A-Za-z_]\w*)\s*$", sig)
            if not name:
                continue
            selector, params = name.group(1), []
        out.append((kind, ret, selector, params))
    return out


def main():
    headers = Path(os.environ.get(
        "ZOOM_IOS_HEADERS",
        ROOT / "ios/MobileRTC.framework/Headers"))
    if not headers.is_dir():
        sys.exit(f"headers not found: {headers}\n"
                 f"set ZOOM_IOS_HEADERS to MobileRTC.framework/Headers")

    # class -> methods, merging every @interface block including categories
    classes = {}
    for path in sorted(headers.glob("*.h")):
        src = strip_comments(path.read_text(errors="replace"))
        for m in re.finditer(r"@interface\s+(\w+)\s*(?:\(([^)]*)\))?[^\n]*\n(.*?)\n@end", src, re.S):
            cls, body = m.group(1), m.group(3)
            classes.setdefault(cls, []).extend(parse_methods(body))
            classes[cls].extend(parse_properties(body))

    if "MobileRTC" not in classes:
        sys.exit("MobileRTC not found in the headers; did the layout change?")

    # Routes: zero-argument getters on MobileRTC returning an SDK object.
    routes = {"MobileRTC": ""}
    owner = {"MobileRTC": "MobileRTC"}
    for kind, ret, selector, params in classes["MobileRTC"]:
        if kind != "-" or params or ":" in selector:
            continue
        t = clean_type(ret)
        m = re.match(r"(MobileRTC\w+)\s*\*$", t)
        if not m:
            continue
        cls = m.group(1)
        name = cls[len("MobileRTC"):] or cls
        routes[name] = selector
        owner[name] = cls

    api, skipped, total = {}, 0, 0
    for name, cls in sorted(owner.items()):
        entries = {}
        for kind, ret, selector, params in classes.get(cls, []):
            if kind != "-":
                continue
            if any(UNSUPPORTED_PARAM.search(clean_type(t)) for t, _ in params):
                skipped += 1
                continue
            if selector.startswith(("alloc", "new", "copy", "mutableCopy", "init")):
                skipped += 1
                continue
            # Arity 0 and 1 are callable by bare name -- the native side appends
            # the colon. Anything longer needs the real selector, because the
            # labels cannot be guessed from a name.
            key = selector[:-1] if len(params) == 1 else (selector if params else selector)
            entries[key] = {
                "selector": selector,
                "returns": clean_type(ret),
                "params": [{"type": clean_type(t), "name": n} for t, n in params],
            }
            total += 1
        if entries:
            api[name] = {"route": routes[name], "class": cls, "methods": entries}

    OUT_JSON.write_text(json.dumps(api, indent=1, sort_keys=True) + "\n")

    lines = [
        "// AUTO-GENERATED by scripts/generate-ios-commands.py from the Zoom iOS",
        "// SDK headers (MobileRTC.framework). Do not edit by hand.",
        f"// {len(api)} objects reachable from [MobileRTC sharedRTC], {total} callable methods.",
        f"// Not generated: {skipped} that take a block, a delegate, a UIKit object or a",
        "// struct -- nothing on the JavaScript side can be handed over as one, and",
        "// callbacks arrive as events instead.",
        "//",
        "// Reaching these needs no new native code: the bridge is one NSInvocation",
        "// (ios/RNZoomUsCommands.m), so a method added by a future SDK becomes callable",
        "// as soon as this file is regenerated -- an OTA update, not a rebuild.",
        "",
        'import type { ZoomObject } from "./generated";',
        "",
        "export interface ZoomIosApi {",
    ]
    for name, info in sorted(api.items()):
        lines.append(f"  /** [MobileRTC sharedRTC]{'' if not info['route'] else ' -> ' + info['route'] + '()'} : {info['class']} */")
        lines.append(f"  {name}: {{")
        for key, m in sorted(info["methods"].items()):
            args = ", ".join(f"a{i}: {ts_for(p['type'])}" for i, p in enumerate(m["params"]))
            sig = " ".join(f"{p['type']} {p['name']}" for p in m["params"])
            lines.append(f"    /** `{m['returns']} {m['selector']}{(' ' + sig) if sig else ''}` */")
            ident = key if re.match(r"^[A-Za-z_]\w*$", key) else f'"{key}"'
            lines.append(f"    {ident}({args}): Promise<{ts_for(m['returns'])}>;")
        lines.append("  };")
    lines += ["}", ""]
    OUT_TS.write_text("\n".join(lines))

    rl = [
        "// AUTO-GENERATED by scripts/generate-ios-commands.py. Do not edit by hand.",
        "",
        "/** Route from [MobileRTC sharedRTC] to each callable object. */",
        "export const ZOOM_IOS_ROUTES: Record<string, string> = {",
    ]
    for name, info in sorted(api.items()):
        rl.append(f'  {name}: "{info["route"]}",')
    rl += ["};", ""]
    OUT_ROUTES.write_text("\n".join(rl))

    print(f"{OUT_JSON.relative_to(ROOT)}: {len(api)} objects, {total} methods")
    print(f"{OUT_TS.relative_to(ROOT)}: written ({skipped} methods skipped)")
    print(f"{OUT_ROUTES.relative_to(ROOT)}: written")


if __name__ == "__main__":
    main()
