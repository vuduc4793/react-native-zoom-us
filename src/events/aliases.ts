import { Platform } from "react-native";
import type { ZoomEvent } from "./generated";
import table from "./event-aliases.json";

/*
 * One event vocabulary on both platforms.
 *
 * The two SDKs name many of the same callbacks differently, and for the core
 * meeting events Android only emits the shared legacy names (success,
 * userJoin, hostChanged ...) while iOS emits those *and* its own (on*).
 * Here every event is also delivered under its other platform's name, so a
 * listener written against either name works on both:
 *
 *   - rename: [android, ios] pairs for the same callback (event-aliases.json)
 *   - derived: the iOS on* event rebuilt from the shared legacy one on
 *     Android, where the SDK has no separately named callback
 *
 * Only the platform that lacks a name gets it, so nothing arrives twice. Done
 * in JavaScript, so a missing or wrong pair is an OTA fix.
 */

const ANDROID_TO_IOS = new Map<string, string>();
const IOS_TO_ANDROID = new Map<string, string>();
for (const [android, ios] of table.rename as [string, string][]) {
  ANDROID_TO_IOS.set(android, ios);
  IOS_TO_ANDROID.set(ios, android);
}

const STATE_BY_STATUS = table.meetingStateByStatus as Record<string, number>;

/** Both spellings of the id keys the two SDKs disagree on. */
function withIdSpellings(payload: Record<string, any>): Record<string, any> {
  const out = { ...payload };
  if (out.userId !== undefined && out.userID === undefined) out.userID = out.userId;
  if (out.userID !== undefined && out.userId === undefined) out.userId = out.userID;
  return out;
}

const toNumber = (v: unknown) =>
  typeof v === "string" && v.trim() !== "" && !isNaN(Number(v)) ? Number(v) : v;

/** Android: the iOS-named events the legacy emits stand for. */
function derivedOnAndroid(e: Record<string, any>): Record<string, any>[] {
  switch (e.event) {
    case "userJoin":
    case "userLeave": {
      const name = e.event === "userJoin" ? "onSinkMeetingUserJoin" : "onSinkMeetingUserLeft";
      const ids: unknown[] = Array.isArray(e.userList) ? e.userList : [];
      return ids.map((id) => ({ event: name, userID: toNumber(id), userId: toNumber(id) }));
    }
    case "hostChanged":
      return [{ event: "onMeetingHostChange", hostId: toNumber(e.userId), userId: toNumber(e.userId) }];
    case "coHostChanged":
      return [
        {
          event: "onMeetingCoHostChange",
          userID: toNumber(e.userId),
          userId: toNumber(e.userId),
          isCoHost: e.isCoHost,
        },
      ];
    case "askUnMuteAudio":
      return [{ event: "onSinkMeetingAudioRequestUnmuteByHost", userId: e.userId }];
    case "askUnMuteVideo":
      return [{ event: "onSinkMeetingVideoRequestUnmuteByHost", userId: e.userId }];
    case "onLowOrRaiseHandStatusChanged": {
      const id = toNumber(e.userId ?? e.userID ?? (Array.isArray(e.args) ? e.args[0] : undefined));
      const raised = e.isRaisedHand ?? (Array.isArray(e.args) ? e.args[1] : undefined);
      if (typeof raised !== "boolean") return [];
      return [{ event: raised ? "onSinkMeetingUserRaiseHand" : "onSinkMeetingUserLowerHand", userID: id, userId: id }];
    }
  }
  // The meeting-status emit: named after the error ("success" when none),
  // carrying the MeetingStatus name. The MeetingStatus channel's mirror has no
  // `status`, so it is not counted twice.
  if (e.channel === "MeetingEvent" && typeof e.status === "string" && e.status.startsWith("MEETING_STATUS_")) {
    const state = STATE_BY_STATUS[e.status];
    return [{ event: "onMeetingStateChange", state: state ?? null, status: e.status }];
  }
  return [];
}

/** iOS: the Android-named events its own callbacks stand for. */
function derivedOnIos(e: Record<string, any>): Record<string, any>[] {
  switch (e.event) {
    case "onSinkMeetingUserRaiseHand":
    case "onSinkMeetingUserLowerHand": {
      const id = toNumber(e.userID ?? e.userId);
      return [{ event: "onLowOrRaiseHandStatusChanged", userId: id, userID: id, isRaisedHand: e.event === "onSinkMeetingUserRaiseHand" }];
    }
  }
  return [];
}

/**
 * The extra deliveries for one event: the same payload under the other
 * platform's name, plus anything derived from it. Never includes the event
 * itself.
 */
export function aliasesFor(event: ZoomEvent): ZoomEvent[] {
  const e = event as Record<string, any>;
  if (!e || typeof e.event !== "string") return [];
  const out: Record<string, any>[] = [];
  const isAndroid = Platform.OS === "android";

  const renamed = isAndroid ? ANDROID_TO_IOS.get(e.event) : IOS_TO_ANDROID.get(e.event);
  if (renamed) out.push({ ...withIdSpellings(e), event: renamed, aliasOf: e.event });

  for (const d of isAndroid ? derivedOnAndroid(e) : derivedOnIos(e)) {
    out.push({ ...d, aliasOf: e.event });
  }
  return out as ZoomEvent[];
}
