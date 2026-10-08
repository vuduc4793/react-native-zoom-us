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
    "inMeetingUserCount": [("count", "number")],
    "hostChanged": [("userId", "number")],
    "coHostChanged": [("userId", "number"), ("isCoHost", "boolean")],
    "myAudioTypeChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "success": [("status", "string")],
    # Every participant; ordinal matches MobileRTC_AudioStatus / MobileRTC_VideoStatus.
    "onUserAudioStatusChanged": [("userId", "number"), ("audioStatus", "number"), ("audioStatusName", "string")],
    "onUserVideoStatusChanged": [("userId", "number"), ("videoStatus", "number"), ("videoStatusName", "string")],
    "showMinimizeMeeting": [("status", "string")],
    "backFullScreenMeeting": [("status", "string")],
    "askUnMuteAudio": [],
    "askUnMuteVideo": [],
    "screenShareStarted": [],
    "screenShareStopped": [],
    "screenShareSuccess": [],
    "screenShareError": [],
    "myAudioStatusChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "myVideoStatusChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "myAudioSourceTypeChanged": [("userRole", "string"), ("audioType", "number"), ("isTalking", "boolean"), ("isMutedAudio", "boolean"), ("isMutedVideo", "boolean")],
    "onChatMessageNotification": [("chatInfo", "ZoomChatMessage | null")],
}

# Legacy names the iOS module emits as well (RNZoomUs.m mirrors its legacy
# channel onto the unified one). Payloads match after normalizeZoomEvent.
IOS_LEGACY = {
    "userJoin", "userLeave", "inMeetingUserCount", "hostChanged", "coHostChanged",
    "askUnMuteAudio", "askUnMuteVideo", "myAudioStatusChanged", "myVideoStatusChanged",
    "myAudioTypeChanged", "myAudioSourceTypeChanged", "success", "onChatMessageNotification",
    "showMinimizeMeeting", "backFullScreenMeeting",
}
# Rebuilt in JS by src/events/aliases.ts (derivedOnAndroid / derivedOnIos).
DERIVED_ON_ANDROID = {
    "onSinkMeetingUserJoin", "onSinkMeetingUserLeft", "onMeetingHostChange", "onMeetingCoHostChange",
    "onSinkMeetingAudioRequestUnmuteByHost", "onSinkMeetingVideoRequestUnmuteByHost",
    "onSinkMeetingUserRaiseHand", "onSinkMeetingUserLowerHand", "onMeetingStateChange",
}
DERIVED_ON_IOS = {"onLowOrRaiseHandStatusChanged"}

# iOS-only legacy names (myAudioTypeChanged is aliased to Android's name in JS).
IOS_LEGACY_ONLY = {"showMinimizeMeeting", "backFullScreenMeeting"}


def ts_for(line):
    m = re.match(r'\s*__p\.put(\w+)\("(\w+)",\s*(.*)\);\s*$', line)
    if not m:
        return None
    kind, key, expr = m.group(1), m.group(2), m.group(3)
    if kind == "Boolean":
        return key, "boolean"
    if kind in ("Double", "Int"):
        return key, "number"
    if kind == "String":
        # Enums and other nullable references are emitted with a null guard.
        return key, "string | null" if "== null" in expr or "name()" in expr else "string"
    if kind == "Array":
        return key, "number[]" if "toLongArray" in expr else "string[]"
    if kind == "Map":
        return key, "ZoomMeetingParameter | null" if key == "meetingParameter" else "Record<string, unknown> | null"
    return key, "unknown"


def main():
    src = MODULE.read_text()
    blocks = re.findall(
        # The emit block may follow other statements (a Log line, an early
        # return), so anchor on the line, not on the method's opening brace.
        r'\n((?:[ \t]*WritableMap __p = Arguments\.createMap\(\);\n)(?:.*?\n)*?)\s*emitZoomEvent\("(\w+)", __p\);',
        src,
    )
    if not blocks:
        sys.exit(f"no generated emitters found in {MODULE}; did the codegen shape change?")

    entries = {}
    for body, name in blocks:
        entries[name] = [r for r in (ts_for(l) for l in body.splitlines()) if r]
    for name, fields in LEGACY.items():
        entries.setdefault(name, fields)
    # Callbacks forwarded by RNZoomUsListeners (reflective proxies). Values are
    # serialized at runtime, so named keys are `unknown` unless iOS types them;
    # `args` carries every argument in order.
    listener_manifest = ROOT / "src/events/android-listener-events.json"
    if listener_manifest.exists():
        ios_types = json.loads(IOS_MANIFEST.read_text()) if IOS_MANIFEST.exists() else {}
        renamed = dict(json.loads((ROOT / "src/events/event-aliases.json").read_text())["rename"])
        for name, keys in json.loads(listener_manifest.read_text()).items():
            # Keys borrowed from the iOS callback carry its types too.
            known = dict(ios_types.get(name) or ios_types.get(renamed.get(name, ""), []))
            fields = [(k, known.get(k, "unknown")) for k in keys] + [("args", "unknown[]")]
            entries.setdefault(name, fields)

    # Merge what iOS emits. scripts/generate-ios-delegates.py records the real
    # Objective-C types, so this does not have to re-parse them.
    ios = json.loads(IOS_MANIFEST.read_text()) if IOS_MANIFEST.exists() else {}
    android_names = set(entries) - IOS_LEGACY_ONLY
    ios_names = set(ios) | IOS_LEGACY
    # src/events/aliases.ts delivers each renamed pair under both names and
    # rebuilds some iOS-named events on Android, so they exist on both.
    aliases = json.loads((ROOT / "src/events/event-aliases.json").read_text())
    for android, ios_name in aliases["rename"]:
        if android in android_names:
            android_names.add(ios_name)
        if ios_name in ios_names:
            ios_names.add(android)
    android_names |= DERIVED_ON_ANDROID
    ios_names |= DERIVED_ON_IOS
    android_only = android_names - ios_names
    ios_only = ios_names - android_names
    both = android_names & ios_names
    for name, fields in ios.items():
        merged = {k: t for k, t in entries.get(name, [])}
        for key, ts in fields:
            if merged.get(key) == "unknown":
                merged[key] = ts
            elif key in merged and merged[key] != ts:
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
        "/** A chat message, as both platforms send it inside onChatMessageNotification. */",
        "export interface ZoomChatMessage {",
        "  chatId: string | null;",
        "  senderId: string | null;",
        "  senderName: string | null;",
        "  receiverId: string | null;",
        "  receiverName: string | null;",
        "  content: string | null;",
        "  date: string | null;",
        "  chatMessageType?: number;",
        "  isMyself?: boolean;",
        "  isPrivate?: boolean;",
        "  isChatToAll?: boolean;",
        "  isChatToAllPanelist?: boolean;",
        "  isChatToWaitingroom?: boolean;",
        "  isComment?: boolean;",
        "  isThread?: boolean;",
        "  /** Same value as threadID; both spellings are filled in. */",
        "  threadId: string | null;",
        "  threadID: string | null;",
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
