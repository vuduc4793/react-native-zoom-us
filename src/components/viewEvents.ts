import * as React from "react";
import { Platform } from "react-native";
import { addZoomAnyListener } from "../events";
import type { ZoomEvent } from "../events";

/**
 * Event props of the video view components, identical on both platforms.
 *
 * iOS delivers these from the native view. The Android view emits nothing, so
 * there the same props are fed from the module's unified event channel and
 * reshaped to what the iOS view sends -- one component API instead of "props on
 * iOS, NativeEventEmitter on Android". Done in JavaScript, so a payload that
 * still differs is an OTA fix.
 */
export interface ZoomViewEventProps {
  /** `{event: "userJoin", userList: number[]}` */
  onSinkMeetingUserJoin?: (event: any) => void;
  /** `{event: "userLeave", userList: number[]}` */
  onSinkMeetingUserLeft?: (event: any) => void;
  /** `{event: "success", status: "MEETING_STATUS_*"}` */
  onMeetingStateChange?: (event: any) => void;
  /** `{event: "meetingCount", userList: number}` -- the count, despite the name. */
  onInMeetingUserCount?: (event: any) => void;
  /** `{event: "success", status: "MobileRTCBOStatus_*"}` */
  onBOStatusChanged?: (event: any) => void;
  /** `{event: "onHasAttendeeRightsNotification", boName: string | null}` */
  onHasAttendeeRightsNotification?: (event: any) => void;
  /** `{event: "REQUEST_AUDIO", status: true}` */
  onMeetingAudioRequestUnmuteByHost?: (event: any) => void;
  /** `{event: "REQUEST_VIDEO", status: true}` */
  onMeetingVideoRequestUnmuteByHost?: (event: any) => void;
  /** `{event, userID, audioStatus}` -- MobileRTC_AudioStatus numbering on both. */
  onSinkMeetingAudioStatusChange?: (event: any) => void;
  /** iOS only: Android's SDK has no preview-stopped callback. */
  onMeetingPreviewStopped?: (event: any) => void;
  /** `{event, userID, videoStatus}` -- MobileRTC_VideoStatus numbering on both. */
  onSinkMeetingVideoStatusChange?: (event: any) => void;
  /** `{event, chatInfo: ZoomChatMessage | null}` */
  onChatMessageNotification?: (event: any) => void;
  /** `{event, msgDelete: {msgID, deleteBy} | null}` */
  onChatMsgDeleteNotification?: (event: any) => void;
}

export const ZOOM_VIEW_EVENT_PROPS = [
  "onSinkMeetingUserJoin",
  "onSinkMeetingUserLeft",
  "onMeetingStateChange",
  "onInMeetingUserCount",
  "onBOStatusChanged",
  "onHasAttendeeRightsNotification",
  "onMeetingAudioRequestUnmuteByHost",
  "onMeetingVideoRequestUnmuteByHost",
  "onSinkMeetingAudioStatusChange",
  "onMeetingPreviewStopped",
  "onSinkMeetingVideoStatusChange",
  "onChatMessageNotification",
  "onChatMsgDeleteNotification",
] as const;

type ViewEventProp = (typeof ZOOM_VIEW_EVENT_PROPS)[number];

/**
 * Android: which view prop a unified-channel event stands for, with the payload
 * the iOS view would have sent. The event has already been through
 * normalizeZoomEvent, so ids are numbers and the count is in `count`.
 */
export function translateForView(raw: ZoomEvent): [ViewEventProp, object] | null {
  const e: any = raw;
  switch (e?.event) {
    case "userJoin":
      return ["onSinkMeetingUserJoin", { event: "userJoin", userList: e.userList ?? [] }];
    case "userLeave":
      return ["onSinkMeetingUserLeft", { event: "userLeave", userList: e.userList ?? [] }];
    case "inMeetingUserCount":
      return typeof e.count === "number"
        ? ["onInMeetingUserCount", { event: "meetingCount", userList: e.count }]
        : null;
    case "onBOStatusChanged":
      return typeof e.status === "string"
        ? ["onBOStatusChanged", { event: "success", status: e.status }]
        : null;
    case "onHasAttendeeRightsNotification":
      return [
        "onHasAttendeeRightsNotification",
        { event: "onHasAttendeeRightsNotification", boName: e.boName ?? e.status ?? null },
      ];
    case "askUnMuteAudio":
      return ["onMeetingAudioRequestUnmuteByHost", { event: "REQUEST_AUDIO", status: true }];
    case "askUnMuteVideo":
      return ["onMeetingVideoRequestUnmuteByHost", { event: "REQUEST_VIDEO", status: true }];
    case "onUserAudioStatusChanged":
      return [
        "onSinkMeetingAudioStatusChange",
        { event: "onSinkMeetingAudioStatusChange", userID: e.userId, audioStatus: e.audioStatus ?? null },
      ];
    case "onUserVideoStatusChanged":
      return [
        "onSinkMeetingVideoStatusChange",
        { event: "onSinkMeetingVideoStatusChange", userID: e.userId, videoStatus: e.videoStatus ?? null },
      ];
    case "onChatMessageNotification":
      return ["onChatMessageNotification", { event: "onChatMessageNotification", chatInfo: e.chatInfo ?? null }];
    case "onChatMsgDeleteNotification":
      return [
        "onChatMsgDeleteNotification",
        { event: "onChatMsgDeleteNotification", msgDelete: e.msgDelete ?? null },
      ];
  }
  // Android's meeting-status emit is named after the error ("success" when
  // there is none) and carries the MeetingStatus name; the MeetingStatus
  // channel's mirror has no `status` field and is skipped here.
  if (
    e?.channel === "MeetingEvent" &&
    typeof e.status === "string" &&
    e.status.startsWith("MEETING_STATUS_")
  ) {
    return ["onMeetingStateChange", { event: "success", status: e.status }];
  }
  return null;
}

/**
 * Wire the view event props for the running platform. Returns the props to
 * spread on the native view (iOS); on Android it subscribes to the module
 * channel instead and returns nothing to spread.
 */
export function useZoomViewEvents(props: ZoomViewEventProps): Record<string, (event: any) => void> {
  const ref = React.useRef(props);
  ref.current = props;

  React.useEffect(() => {
    if (Platform.OS !== "android") return;
    const subscription = addZoomAnyListener((event) => {
      const hit = translateForView(event);
      if (!hit) return;
      const handler = (ref.current as Record<string, unknown>)[hit[0]];
      if (typeof handler !== "function") return;
      try {
        handler(hit[1]);
      } catch (error) {
        console.error(`[react-native-zoom-us] ${hit[0]} handler threw`, error);
      }
    });
    return () => subscription.remove();
  }, []);

  return React.useMemo(() => {
    if (Platform.OS !== "ios") return {};
    const native: Record<string, (event: any) => void> = {};
    for (const prop of ZOOM_VIEW_EVENT_PROPS) {
      native[prop] = (event) => {
        const handler = (ref.current as Record<string, unknown>)[prop];
        if (typeof handler === "function") handler(event?.nativeEvent);
      };
    }
    return native;
  }, []);
}
