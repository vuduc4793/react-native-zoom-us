#!/usr/bin/env python3
"""Introspect the Zoom Android SDK and generate the typed command surface.

The bridge itself is one reflective invoke() on the native side, so this script
does not emit Java: it emits the *types*, which is what makes 1000+ SDK calls
reachable from JavaScript with autocomplete instead of stringly-typed guesses.

Run from the repository root:  python3 scripts/generate-commands.py
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_JSON = Path(os.environ.get("ZOOM_API_JSON", ROOT / "src/commands/android-api.json"))
OUT_TS = Path(os.environ.get("ZOOM_API_TS", ROOT / "src/commands/generated.ts"))

# Methods taking a listener cannot cross the bridge: there is no object on the
# JavaScript side to hand to the SDK. Events already come through the emitter.
LISTENER_RE = re.compile(r"Listener|Callback|Handler|\$")

PRIMITIVES = {
    "boolean": "boolean",
    "int": "number", "long": "number", "short": "number", "byte": "number",
    "float": "number", "double": "number", "char": "string",
    "void": "void",
    "java.lang.String": "string",
    "java.lang.CharSequence": "string",
    "java.lang.Boolean": "boolean",
    "java.lang.Integer": "number", "java.lang.Long": "number",
    "java.lang.Float": "number", "java.lang.Double": "number",
}


def find_classes_jar():
    # An explicit path wins: an upgrade has to be diffable before the new AAR is
    # published anywhere Gradle can resolve it.
    if len(sys.argv) > 1:
        aar = Path(sys.argv[1])
        if not aar.exists():
            sys.exit(f"no such AAR: {aar}")
        return aar

    gradle = Path.home() / ".gradle/caches/modules-2/files-2.1"
    version = re.search(r"ZOOM_SDK_VERSION\s*=\s*'([^']+)'",
                        (ROOT / "android-impl/build.gradle").read_text())
    aars = sorted(gradle.rglob(f"*zoom-us-{version.group(1)}.aar")) if version else []
    if not aars:
        aars = sorted(gradle.rglob("*zoom-us-*.aar"))
    if not aars:
        sys.exit("no Zoom AAR in the Gradle cache; build the Android side once first")
    return aars[-1]


def ts_type(java):
    java = java.strip()
    if java in PRIMITIVES:
        return PRIMITIVES[java]
    m = re.match(r"java\.util\.(List|Set|Collection)<(.+)>$", java)
    if m:
        return f"{ts_type(m.group(2))}[]"
    if java.endswith("[]"):
        return f"{ts_type(java[:-2])}[]"
    if java.startswith("java.util.Map"):
        return "Record<string, unknown>"
    # Enums marshal as their name(); every other SDK object as a plain record of
    # its getters, which is what the native side flattens them to.
    return "string | number" if java in enums else "ZoomObject"


enums = set()


def main():
    aar = find_classes_jar()
    # The AAR holds classes.jar; javap needs that, not the AAR.
    work = Path(tempfile.mkdtemp(prefix="zoom-sdk-"))
    subprocess.run(["unzip", "-o", "-q", str(aar), "classes.jar", "-d", str(work)], check=True)
    jar = work / "classes.jar"
    names = subprocess.run(["unzip", "-l", str(jar)], capture_output=True, text=True).stdout
    classes = sorted({
        m.replace("/", ".")[:-6]
        for m in re.findall(r"us/zoom/sdk/[A-Za-z0-9$]+\.class", names)
    })

    # One javap per class is thousands of processes; batch them instead. The
    # output is one "Compiled from" block per class, in the order asked for.
    dumps = {}
    BATCH = 150
    for i in range(0, len(classes), BATCH):
        chunk = classes[i:i + BATCH]
        out = subprocess.run(["javap", "-cp", str(jar), *chunk],
                             capture_output=True, text=True).stdout
        for block in re.split(r'(?m)^(?=Compiled from )', out):
            m = re.search(r"^(?:public |final |abstract )*(?:class|interface|enum) ([\w.$]+)",
                          block, re.M)
            if not m:
                continue
            dumps[m.group(1)] = block
            if "extends java.lang.Enum" in block:
                enums.add(m.group(1))

    # Every method of every class, before deciding which are reachable.
    table, skipped = {}, 0
    for cls, out in dumps.items():
        if "$" in cls or cls in enums:
            continue
        methods = []
        for line in out.splitlines():
            m = re.match(r"\s+public (?:abstract |static |final )*"
                         r"([\w.$<>\[\], ]+?)\s+(\w+)\(([^)]*)\);", line)
            if not m:
                continue
            ret, name, raw = m.group(1), m.group(2), m.group(3)
            params = [p.strip() for p in raw.split(",") if p.strip()]
            if name in ("values", "valueOf") or LISTENER_RE.search(raw) or name.endswith("Listener"):
                skipped += 1
                continue
            methods.append({"name": name, "returns": ret, "params": params})
        table[cls] = methods

    # A method is only callable if something can hand the native side the object
    # to call it on. That means walking no-argument getters out from
    # ZoomSDK.getInstance() and recording the path, so the bridge follows a
    # known route instead of guessing.
    ROOT_CLASS = "us.zoom.sdk.ZoomSDK"
    if ROOT_CLASS not in table:
        sys.exit("us.zoom.sdk.ZoomSDK not found; did the SDK layout change?")

    paths = {ROOT_CLASS: []}
    queue = [ROOT_CLASS]
    while queue:
        cls = queue.pop(0)
        for mth in table.get(cls, []):
            ret = mth["returns"]
            if mth["params"] or not ret.startswith("us.zoom.sdk."):
                continue
            if ret in enums or ret not in table or ret in paths:
                continue
            paths[ret] = paths[cls] + [mth["name"]]
            queue.append(ret)

    api = {
        cls.split(".")[-1]: {"path": paths[cls], "methods": table[cls]}
        for cls in sorted(paths)
        if table.get(cls)
    }
    unreachable = sum(len(v) for c, v in table.items() if c not in paths)

    OUT_JSON.write_text(json.dumps(api, indent=1, sort_keys=True))

    total = sum(len(v["methods"]) for v in api.values())
    lines = [
        "// AUTO-GENERATED by scripts/generate-commands.py from the Zoom Android",
        f"// SDK ({aar.name}). Do not edit by hand.",
        f"// {len(api)} objects reachable from ZoomSDK.getInstance(), {total} callable methods.",
        f"// Not generated: {skipped} that take an SDK listener (nothing on the",
        f"// JavaScript side can be handed to the SDK as one -- those arrive as events",
        f"// instead), and {unreachable} on classes no no-argument getter returns,",
        "// which are data objects the native side flattens rather than things to call.",
        "//",
        "// Reaching these needs no new native code: the bridge is one reflective",
        "// invoke(), so a method added by a future SDK becomes callable as soon as",
        "// this file is regenerated.",
        "",
        "/** An SDK object, flattened to its getters by the native side. */",
        "export type ZoomObject = Record<string, unknown>;",
        "",
        "export interface ZoomNativeApi {",
    ]
    for cls in sorted(api):
        route = " -> ".join(["ZoomSDK.getInstance()"] + [f"{p}()" for p in api[cls]["path"]])
        lines.append(f"  /** {route} */")
        lines.append(f"  {cls}: {{")
        for mth in sorted(api[cls]["methods"], key=lambda x: x["name"]):
            sig = ", ".join(f"a{i}: {ts_type(p)}" for i, p in enumerate(mth["params"]))
            ret = ts_type(mth["returns"])
            java = f'{mth["returns"].split(".")[-1]} {mth["name"]}({", ".join(p.split(".")[-1] for p in mth["params"])})'
            lines.append(f"    /** `{java}` */")
            lines.append(f"    {mth['name']}({sig}): Promise<{ret}>;")
        lines.append("  };")
    lines += ["}", ""]
    OUT_TS.write_text("\n".join(lines))

    # The runtime only needs the route to each object, not the whole signature
    # dump, so that is all that gets bundled into the app.
    routes = [
        "// AUTO-GENERATED by scripts/generate-commands.py. Do not edit by hand.",
        "",
        "/** Route from ZoomSDK.getInstance() to each callable object. */",
        "export const ZOOM_ROUTES: Record<string, string> = {",
    ]
    for cls in sorted(api):
        routes.append(f'  {cls}: "{".".join(api[cls]["path"])}",')
    routes += ["};", ""]
    (ROOT / "src/commands/routes.ts").write_text("\n".join(routes))
    print(f"{OUT_JSON}: {len(api)} controllers, {total} methods")
    print(f"{OUT_TS}: written ({skipped} listener methods skipped)")


if __name__ == "__main__":
    main()
