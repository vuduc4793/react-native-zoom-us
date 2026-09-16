import * as React from "react";
import {
  addZoomAnyListener,
  addZoomListener,
  ZoomEvent,
  ZoomEventName,
  ZoomEventPayloads,
} from "../events";

/**
 * Subscribe to one Zoom event for the lifetime of the component.
 *
 * The handler is kept in a ref, so passing an inline arrow function does not
 * resubscribe on every render.
 */
export function useZoomEvent<K extends ZoomEventName>(
  event: K,
  handler: (payload: ZoomEventPayloads[K] & { event: K }) => void
) {
  const ref = React.useRef(handler);
  ref.current = handler;

  React.useEffect(() => {
    const subscription = addZoomListener(event, (payload) => ref.current(payload));
    return () => subscription.remove();
  }, [event]);
}

/** Subscribe to every Zoom event. Handy while wiring up a new feature. */
export function useZoomAnyEvent(handler: (event: ZoomEvent) => void) {
  const ref = React.useRef(handler);
  ref.current = handler;

  React.useEffect(() => {
    const subscription = addZoomAnyListener((event) => ref.current(event));
    return () => subscription.remove();
  }, []);
}

/**
 * Number of people in the meeting, kept up to date from join/leave events.
 *
 * Zoom reports the count on its own channel and also reports joins and leaves
 * separately; both are folded in here so the value does not lag behind.
 */
export function useZoomParticipantCount(initial = 0) {
  const [count, setCount] = React.useState(initial);

  useZoomEvent("inMeetingUserCount", (payload) => {
    if (typeof payload.userList === "number") setCount(payload.userList);
  });
  useZoomEvent("userJoin", (payload) => {
    setCount((current) => current + (payload.userList?.length ?? 0));
  });
  useZoomEvent("userLeave", (payload) => {
    setCount((current) => Math.max(0, current - (payload.userList?.length ?? 0)));
  });

  return count;
}

/** The participants Zoom has told us about, as a live set of user ids. */
export function useZoomParticipants() {
  const [participants, setParticipants] = React.useState<number[]>([]);

  useZoomEvent("userJoin", (payload) => {
    setParticipants((current) => {
      const next = new Set(current);
      for (const id of payload.userList ?? []) next.add(id);
      return Array.from(next);
    });
  });
  useZoomEvent("userLeave", (payload) => {
    setParticipants((current) => {
      const leaving = new Set(payload.userList ?? []);
      return current.filter((id) => !leaving.has(id));
    });
  });

  return participants;
}
