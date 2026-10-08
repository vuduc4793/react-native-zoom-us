import { NativeEventEmitter, EmitterSubscription } from "react-native";
import { RNZoomUs } from "../../native";
import { aliasesFor } from "./aliases";
import type {
  ZoomEvent,
  ZoomEventName,
  ZoomEventPayloads,
} from "./generated";

export * from "./generated";

// The pre-v2 helpers (onMeetingStatusChange / onMeetingJoined) keep working and
// keep their default export, so `import ZoomUs from '...'` is unchanged.
export * from "./legacy";
export { default } from "./legacy";

/**
 * Channel every SDK callback is forwarded on. Both platforms also keep emitting
 * the older "MeetingEvent" / "MeetingStatus" / "AuthEvent" channels, and those
 * are mirrored here too, so subscribing to this one channel is enough.
 */
export const ZOOM_EVENT_CHANNEL = "ZoomUsEvent";

/*
 * The legacy vocabulary (userJoin, success, hostChanged, ...) is shared by both
 * platforms, but each native side shaped some payloads its own way. They are
 * made identical here, in JavaScript, so a shape that still differs is an OTA
 * fix rather than a native release. Fields are added or retyped, never removed.
 */
const toNumber = (value: unknown): unknown => {
  if (typeof value === "string" && value.trim() !== "" && !isNaN(Number(value))) {
    return Number(value);
  }
  return value;
};


export function normalizeZoomEvent(raw: ZoomEvent): ZoomEvent {
  const event: any = { ...raw };
  // Older iOS binaries named the breakout-room states differently from
  // Android; one name on both.
  if (event.status === "MEETING_STATUS_JOIN_BO") event.status = "MEETING_STATUS_JOIN_BREAKOUT_ROOM";
  if (event.status === "MEETING_STATUS_LEAVE_BO") event.status = "MEETING_STATUS_LEAVE_BREAKOUT_ROOM";
  switch (event.event) {
    case "userJoin":
    case "userLeave":
      // Android sends ids as strings, iOS as numbers.
      event.userList = Array.isArray(event.userList)
        ? event.userList.map(toNumber).filter((id: unknown) => typeof id === "number")
        : [];
      break;
    case "inMeetingUserCount":
      // Android put the count in `userId`, the iOS view in `userList`.
      if (typeof event.count !== "number") {
        const count = [event.userId, event.userList].map(toNumber).find((v) => typeof v === "number");
        if (typeof count === "number") event.count = count;
      }
      break;
    case "hostChanged":
    case "coHostChanged":
      event.userId = toNumber(event.userId);
      break;
    case "onChatMessageNotification": {
      const info = event.chatInfo;
      if (info && typeof info === "object") {
        // Android spells it threadId, iOS threadID.
        const thread = info.threadId ?? info.threadID ?? null;
        event.chatInfo = { ...info, threadId: thread, threadID: thread };
      }
      break;
    }
  }
  return event as ZoomEvent;
}

type AnyListener = (event: ZoomEvent) => void;
type NamedListener = (payload: any, event: ZoomEvent) => void;

const named = new Map<string, Set<NamedListener>>();
const any = new Set<AnyListener>();

let emitter: NativeEventEmitter | null = null;
let subscription: EmitterSubscription | null = null;

/**
 * One native subscription is shared by every JS listener. Subscribing per
 * listener would mean up to 98 bridge subscriptions for a screen that watches a
 * handful of events.
 */
function ensureSubscribed() {
  if (subscription || !RNZoomUs) return;

  emitter = emitter ?? new NativeEventEmitter(RNZoomUs as any);
  subscription = emitter.addListener(ZOOM_EVENT_CHANNEL, (rawEvent: ZoomEvent) => {
    if (!rawEvent || typeof rawEvent.event !== "string") return;
    let event: ZoomEvent;
    try {
      event = normalizeZoomEvent(rawEvent);
    } catch (error) {
      console.error(`[react-native-zoom-us] normalizing "${rawEvent.event}" threw`, error);
      event = rawEvent;
    }

    // One subscriber throwing must not cost the others their event, and must
    // not escape into the native emitter's callback.
    const deliver = (listener: (...args: any[]) => void, ...args: any[]) => {
      try {
        listener(...args);
      } catch (error) {
        console.error(`[react-native-zoom-us] listener for "${event.event}" threw`, error);
      }
    };

    const deliverNamed = (name: string, payload: ZoomEvent) => {
      const listeners = named.get(name);
      if (!listeners) return;
      // Copy before iterating: a listener may unsubscribe itself.
      for (const listener of Array.from(listeners)) deliver(listener, payload, payload);
    };
    deliverNamed(event.event, event);
    // The same event under the other platform's name (src/events/aliases.ts).
    let extras: ZoomEvent[] = [];
    try {
      extras = aliasesFor(event);
    } catch (error) {
      console.error(`[react-native-zoom-us] aliasing "${event.event}" threw`, error);
    }
    for (const extra of extras) deliverNamed(extra.event, extra);
    for (const listener of Array.from(any)) deliver(listener, event);
  });
}

function releaseIfIdle() {
  if (named.size === 0 && any.size === 0 && subscription) {
    subscription.remove();
    subscription = null;
  }
}

/** Subscribe to one event, with its payload typed. */
export function addZoomListener<K extends ZoomEventName>(
  event: K,
  listener: (payload: ZoomEventPayloads[K] & { event: K }) => void
): EmitterSubscription {
  ensureSubscribed();

  let set = named.get(event);
  if (!set) {
    set = new Set();
    named.set(event, set);
  }
  set.add(listener as NamedListener);

  return {
    remove() {
      const current = named.get(event);
      if (!current) return;
      current.delete(listener as NamedListener);
      if (current.size === 0) named.delete(event);
      releaseIfIdle();
    },
  } as EmitterSubscription;
}

/**
 * Subscribe to every event. Useful for logging and for reacting to callbacks
 * that have no dedicated handler yet.
 */
export function addZoomAnyListener(listener: AnyListener): EmitterSubscription {
  ensureSubscribed();
  any.add(listener);

  return {
    remove() {
      any.delete(listener);
      releaseIfIdle();
    },
  } as EmitterSubscription;
}
