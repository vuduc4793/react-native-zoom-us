import { NativeEventEmitter, EmitterSubscription } from "react-native";
import { RNZoomUs } from "../../native";
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
  subscription = emitter.addListener(ZOOM_EVENT_CHANNEL, (event: ZoomEvent) => {
    if (!event || typeof event.event !== "string") return;

    // One subscriber throwing must not cost the others their event, and must
    // not escape into the native emitter's callback.
    const deliver = (listener: (...args: any[]) => void, ...args: any[]) => {
      try {
        listener(...args);
      } catch (error) {
        console.error(`[react-native-zoom-us] listener for "${event.event}" threw`, error);
      }
    };

    const listeners = named.get(event.event);
    if (listeners) {
      // Copy before iterating: a listener may unsubscribe itself.
      for (const listener of Array.from(listeners)) deliver(listener, event, event);
    }
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
