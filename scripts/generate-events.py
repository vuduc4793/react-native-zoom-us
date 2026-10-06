#!/usr/bin/env python3
"""Regenerate src/events/generated.ts from the native emitters on both platforms.

The Android module is the single source of truth for what events exist and what
they carry: every SDK listener callback forwards to emitZoomEvent(), so parsing
the put* calls in those bodies yields payload types that cannot drift from the
native side.

Run from the repository root:  python3 scripts/generate-events.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULE = ROOT / "android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java"
OUT = ROOT / "src/events/generated.ts"
IOS_MANIFEST = ROOT / "src/events/ios-events.json"

# Events that predate the unified channel and are emitted with hand-written
# payloads rather than a generated body, so they have to be described here.
LEGACY = {
    "userJoin": [("userList", "number[]")],
    "userLeave": [("userList", "number[]")],
    "inMeetingUserCount": [("userList", "number")],
    "hostChanged": [("userId", "number")],
    "coHostChanged": [("userId", "number")],
    "askUnMuteAudio": [],
    "askUnMuteVideo": [],
    "screenShareStarted": [],
    "screenShareStopped": [],
    "screenShareSuccess": [],
    "screenShareError": [],
    "myAudioStatusChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "myVideoStatusChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "myAudioSourceTypeChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "onChatMessageNotification": [("chatId", "string"), ("senderId", "string"), ("senderName", "string"), ("receiverId", "string"), ("receiverName", "string"), ("content", "string"), ("date", "string")],
}


def ts_for(line):
    m = re.match(r'\s*__p\.put(\w+)\("(\w+)",\s*(.*)\);\s*$', line)
    if not m:
        return None
    kind, key, expr = m.group(1), m.group(2), m.group(3)
    if kind == "Boolean":
        return key, "boolean"
    if kind == "Double":
        return key, "number"
    if kind == "String":
        # Enums and other nullable references are emitted with a null guard.
        return key, "string | null" if "== null" in expr or "name()" in expr else "string"
    if kind == "Array":
        return key, "number[]" if "toLongArray" in expr else "string[]"
    if kind == "Map":
        return key, "ZoomMeetingParameter | null"
    return key, "unknown"


def main():
    src = MODULE.read_text()
    blocks = re.findall(
        r'\{\s*\n((?:\s*WritableMap __p = Arguments\.createMap\(\);\n)(?:.*?\n)*?)\s*emitZoomEvent\("(\w+)", __p\);',
        src,
    )
    if not blocks:
        sys.exit(f"no generated emitters found in {MODULE}; did the codegen shape change?")

    entries = {}
    for body, name in blocks:
        entries[name] = [r for r in (ts_for(l) for l in body.splitlines()) if r]
    for name, fields in LEGACY.items():
        entries.setdefault(name, fields)

    # Merge what iOS emits. scripts/generate-ios-delegates.py records the real
    # Objective-C types, so this does not have to re-parse them.
    ios = json.loads(IOS_MANIFEST.read_text()) if IOS_MANIFEST.exists() else {}
    android_only = set(entries) - set(ios)
    ios_only = set(ios) - set(entries)
    both = set(entries) & set(ios)
    for name, fields in ios.items():
        merged = {k: t for k, t in entries.get(name, [])}
        for key, ts in fields:
            if key in merged and merged[key] != ts:
                # Platforms disagree on the shape; widen rather than pick one.
                merged[key] = " | ".join(sorted({merged[key], ts}))
            else:
                merged.setdefault(key, ts)
        entries[name] = list(merged.items())

    out = [
        "// AUTO-GENERATED from the native emitters on both platforms:",
        "//   android-impl/src/main/java/ch/milosz/reactnative/RNZoomUsModule.java",
        "//   src/events/ios-events.json (written by scripts/generate-ios-delegates.py)",
        "// Regenerate with scripts/generate-events.py. Do not edit by hand.",
        f"// {len(android_only)} Android-only, {len(ios_only)} iOS-only, {len(both)} on both.",
        "",
        "export interface ZoomMeetingParameter {",
        "  meetingType: string | null;",
        "  isViewOnly: boolean;",
        "  isAutoRecordingLocal: boolean;",
        "  isAutoRecordingCloud: boolean;",
        "  meetingNumber: number;",
        "  meetingTopic: string | null;",
        "  meetingHost: string | null;",
        "}",
        "",
        "/** Every event the native side can emit, with its payload. */",
        "export interface ZoomEventPayloads {",
    ]
    # Which platform actually emits each one. The two SDKs do not have the same
    # listener surface -- most of the iOS delegate has no Android counterpart --
    # so the honest thing is to say so per event rather than pretend parity.
    def platform(name):
        if name in both:
            return "android + ios"
        return "android only" if name in android_only else "ios only"

    for name in sorted(entries):
        fields = entries[name]
        out.append(f"  /** {platform(name)} */")
        if not fields:
            out.append(f"  {name}: Record<string, never>;")
        else:
            out.append(f"  {name}: {{")
            out += [f"    {k}: {t};" for k, t in fields]
            out.append("  };")
    out += [
        "}",
        "",
        "export type ZoomEventName = keyof ZoomEventPayloads;",
        "",
        "/** Payload as delivered on the wire: the event name travels with it. */",
        "export type ZoomEvent<K extends ZoomEventName = ZoomEventName> = {",
        "  [E in K]: ZoomEventPayloads[E] & { event: E; channel?: string };",
        "}[K];",
        "",
    ]
    OUT.write_text("\n".join(out))
    print(f"wrote {OUT.relative_to(ROOT)} with {len(entries)} events")


if __name__ == "__main__":
    main()
