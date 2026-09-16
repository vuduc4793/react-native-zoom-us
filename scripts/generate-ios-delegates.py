#!/usr/bin/env python3
"""Forward every MobileRTCMeetingServiceDelegate callback to JavaScript.

The protocol has 250 void methods. RNZoomUsVideoView already implements most of
them but almost all just NSLog, so the events never reach JS; RNZoomUs
implements a smaller subset. Whichever object currently holds ms.delegate is the
one Zoom calls, so both classes need full coverage.

This script:
  * prepends an RNZoomUsEmit(...) call to delegate methods that already exist
  * generates the missing ones into a category per class

The 6 non-void methods are deliberately left alone: they are decision callbacks
(onClickedEndButton:, onCheckIfMeetingVoIPCallRunning, ...) whose return value
changes what the SDK does, so implementing them just to emit an event would
alter behaviour.

Usage:  python3 scripts/generate-ios-delegates.py [--dry-run]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HEADERS = Path(sys.argv[sys.argv.index("--headers") + 1]) if "--headers" in sys.argv else None
DRY = "--dry-run" in sys.argv

TARGETS = [
    ("ios/RNZoomUsVideoView.m", "RNZoomUsVideoView", "ios/RNZoomUsVideoView+GeneratedEvents.m"),
    ("ios/RNZoomUs.m", "RNZoomUs", "ios/RNZoomUs+GeneratedEvents.m"),
]

CLEAN = re.compile(r"\b(_Nonnull|_Nullable|__kindof|const|__strong|__weak|nullable|nonnull)\b")


def parse_protocol(header_text):
    """Return [(selector, [(type, name), ...])] for the void methods."""
    m = re.search(
        r"@protocol\s+MobileRTCMeetingServiceDelegate[^\n]*\n(.*?)@end", header_text, re.S
    )
    if not m:
        sys.exit("MobileRTCMeetingServiceDelegate not found in header")
    body = m.group(1)
    # Strip comments so they cannot be mistaken for declarations.
    body = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
    body = re.sub(r"//[^\n]*", "", body)
    # Deprecation attributes sit between the selector and the semicolon and would
    # otherwise make a no-argument declaration look unparseable.
    body = re.sub(r"\s*(?:DEPRECATED_MSG_ATTRIBUTE|DEPRECATED_ATTRIBUTE|API_[A-Z_]+)\s*(\([^()]*(?:\([^()]*\)[^()]*)*\))?", "", body)

    out = []
    skipped = []
    for decl in re.findall(r"^\s*-\s*\(\s*void\s*\)\s*([^;]+);", body, re.M):
        decl = " ".join(decl.split())
        if "(^" in decl:
            # The SDK hands these a completion block and waits for it to be
            # called. Implementing one just to emit an event would leave the
            # caller hanging, so they are never generated -- only an existing
            # implementation gets an emit prepended.
            skipped.append(decl)
            continue
        parts = re.findall(r"(\w+)\s*:\s*\(([^)]*)\)\s*(\w+)", decl)
        if not parts:
            name = decl.strip()
            if re.fullmatch(r"\w+", name):
                out.append((name, []))
            else:
                skipped.append(decl)
            continue
        selector = "".join(p[0] + ":" for p in parts)
        params = [(CLEAN.sub("", p[1]).strip(), p[2]) for p in parts]
        out.append((selector, params))
    if skipped:
        print(f"  bỏ qua {len(skipped)} method nhận completion block (không được implement bừa):")
        for d in skipped:
            print(f"    - {d[:100]}")
    return out, skipped


def skipped_selectors(decls):
    """Selectors of the block-taking methods, so an existing implementation can
    still be given an emit even though we never generate one."""
    return [selector_of(d) for d in decls]


def payload_entry(ctype, name):
    """(objc expression, wire key, TypeScript type) for one parameter.

    Returns None for parameters that cannot cross the bridge.
    """
    t = " ".join(ctype.split())
    if "^" in t or "char *" in t or "void *" in t:
        return None  # blocks and raw buffers cannot cross the bridge
    if t.strip() == "BOOL":
        return f'@"{name}": @({name})', name, "boolean"
    if "*" not in t:
        return f'@"{name}": @({name})', name, "number"  # scalar or enum
    if t.startswith("NSString"):
        return f'@"{name}": {name} ?: [NSNull null]', name, "string | null"
    m = re.match(r"NSArray\s*<\s*NS(Number|String)\s*\*\s*>", t)
    if m:
        ts = "number[]" if m.group(1) == "Number" else "string[]"
        return f'@"{name}": {name} ?: @[]', name, ts
    # Any other object: report presence, since the object itself is not
    # serialisable and handlers are only meaningful on the native side.
    return f'@"{name}Present": @({name} != nil)', f"{name}Present", "boolean"


MANIFEST = {}


def emit_call(selector, params):
    event = selector.rstrip(":").split(":")[0] if params else selector
    entries = [e for e in (payload_entry(t, n) for t, n in params) if e]
    MANIFEST.setdefault(event, [[key, ts] for _, key, ts in entries])
    if not entries:
        return f'    RNZoomUsEmit(@"{event}", nil);'
    inner = ", ".join(e[0] for e in entries)
    return f'    RNZoomUsEmit(@"{event}", @{{{inner}}});'


def selector_of(decl):
    """Selector for an Objective-C method declaration.

    Built from the `label:` occurrences rather than by parsing each parameter,
    because a block parameter such as `(void (^)(BOOL))completion` contains
    nested parentheses that a simple `([^)]*)` cannot match.
    """
    parts = re.findall(r"(\w+)\s*:", decl)
    return "".join(p + ":" for p in parts) if parts else decl.strip()


def implemented_selectors(source):
    """Selectors defined in a .m file -> (body offset, its own parameter names).

    The parameter names are taken from the implementation rather than the
    protocol: the two often disagree (the protocol calls it `error`, the
    implementation calls it `errorCode`), and the emitted code has to reference
    the names that are actually in scope.
    """
    found = {}
    for m in re.finditer(r"^-\s*\(\s*void\s*\)\s*([^{;]+)\{", source, re.M):
        decl = " ".join(m.group(1).split())
        parts = re.findall(r"(\w+)\s*:\s*\(([^)]*)\)\s*(\w+)", decl)
        params = [(CLEAN.sub("", t).strip(), n) for _, t, n in parts]
        found[selector_of(decl)] = (m.end(), params)
    return found


def signature(selector, params):
    if not params:
        return f"- (void){selector}"
    keys = selector.split(":")[:-1]
    return "- (void)" + " ".join(
        f"{k}:({t}){n}" for k, (t, n) in zip(keys, params)
    )


def main():
    header = (HEADERS / "MobileRTCMeetingDelegate.h").read_text(errors="ignore")
    methods, skipped = parse_protocol(header)
    block_selectors = skipped_selectors(skipped)
    print(f"protocol: {len(methods)} void methods")

    for rel, cls, out_rel in TARGETS:
        path = ROOT / rel
        source = path.read_text()
        if "RNZoomUsEmit(" in source:
            sys.exit(
                f"{rel} already contains generated emit calls. This script prepends "
                "rather than rewrites, so strip them before re-running."
            )
        have = implemented_selectors(source)

        patched = 0
        additions = []
        # Patch from the end so earlier offsets stay valid.
        inserts = []
        for selector, params in methods:
            if selector in have:
                offset, own = have[selector]
                # Prefer the implementation's own parameter names; fall back to
                # the protocol's only when the shapes agree.
                use = own if len(own) == len(params) else []
                inserts.append((offset, "\n" + emit_call(selector, use)))
                patched += 1
            else:
                additions.append((selector, params))

        # Block-taking callbacks are never generated, but if one is already
        # implemented its body handles the block, so emitting is safe.
        for selector in block_selectors:
            if selector in have:
                offset, _ = have[selector]
                event = selector.split(":")[0]
                inserts.append((offset, f'\n    RNZoomUsEmit(@"{event}", nil);'))
                patched += 1

        for offset, line in sorted(inserts, reverse=True):
            source = source[:offset] + line + source[offset:]

        print(f"{rel}: {patched} đã có -> chèn emit, {len(additions)} thiếu -> sinh category")

        if DRY:
            continue

        path.write_text(source)

        body = [
            "// AUTO-GENERATED by scripts/generate-ios-delegates.py. Do not edit by hand.",
            "//",
            f"// MobileRTCMeetingServiceDelegate callbacks {cls} did not implement.",
            "// They exist so no SDK callback is silently dropped: adding one later",
            "// would mean rebuilding and republishing the native library.",
            "",
            f'#import "{cls}.h"',
            '#import "RNZoomUsEvents.h"',
            "",
            f"@implementation {cls} (GeneratedEvents)",
            "",
        ]
        for selector, params in additions:
            body.append(signature(selector, params) + " {")
            body.append(emit_call(selector, params))
            body.append("}")
            body.append("")
        body.append("@end")
        (ROOT / out_rel).write_text("\n".join(body) + "\n")
        print(f"   -> {out_rel}")

    if not DRY:
        # Machine-readable record of what iOS emits, so the TypeScript event
        # types can cover both platforms without re-parsing Objective-C.
        manifest = ROOT / "src/events/ios-events.json"
        manifest.write_text(json.dumps(MANIFEST, indent=1, sort_keys=True) + "\n")
        print(f"wrote {manifest.relative_to(ROOT)} with {len(MANIFEST)} events")


if __name__ == "__main__":
    if HEADERS is None:
        sys.exit("pass --headers <MobileRTC.framework/Headers>")
    main()
