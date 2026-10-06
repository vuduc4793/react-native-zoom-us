import {
  NativeModules,
  HostComponent,
  requireNativeComponent,
  StyleProp,
  ViewStyle,
} from "react-native";

export const VideoAspectModeEnum = {
  VIDEO_ASPECT_ORIGINAL: 0,
  VIDEO_ASPECT_FULL_FILLED: 1,
  VIDEO_ASPECT_LETTER_BOX: 2,
  VIDEO_ASPECT_PAN_AND_SCAN: 3,
  VIDEO_ASPECT_TRUSTEE: 4,
} as const;

type Values<T> = T[keyof T];
export type VideoAspectMode = Values<typeof VideoAspectModeEnum>;

export interface NativeLayoutUnit {
  kind: "active" | "preview" | "share" | "attendee" | "active-share";
  x: number;
  y: number;
  width: number;
  height: number;
  border?: boolean;
  showUsername?: boolean;
  showAudioOff?: boolean;
  /**
   * Index into the participant list Zoom reports, excluding yourself. Fragile:
   * the index shifts as people join and leave. Prefer userId.
   */
  userIndex?: number;
  /** Zoom user id. Takes precedence over userIndex when both are given. */
  userId?: number;
  background?: string;
  aspectMode?: VideoAspectMode;
}

export interface NativeVideoProps {
  style?: StyleProp<ViewStyle>;
  layout: NativeLayoutUnit[];
  /** Android only. How the video surface is composited. */
  zOrder?: "mediaOverlay" | "onTop" | "behind";
  muteMyCamera?: boolean
  muteMyAudio?: boolean
  onSinkMeetingUserJoin?: (event: any) => void;
  onSinkMeetingUserLeft?: (event: any) => void;
  onMeetingStateChange?: (event: any) => void;
  onInMeetingUserCount?: (event: any) => void;
  onBOStatusChanged?: (event: any) => void;
  onHasAttendeeRightsNotification?: (event: any) => void;
  onMeetingAudioRequestUnmuteByHost?: (event: any) => void;
  onMeetingVideoRequestUnmuteByHost?: (event: any) => void;
  onSinkMeetingAudioStatusChange?: (event: any) => void;
  onMeetingPreviewStopped?: (event: any) => void;
  onSinkMeetingVideoStatusChange?: (event: any) => void;
  onChatMessageNotification?: (event: any) => void;
  onChatMsgDeleteNotification?: (event: any) => void;
}

// Both platforms register this view: RNZoomUsVideoViewManager on Android,
// ios/RNZoomUsVideoViewManager.m on iOS. The old "iOS not implemented" note was
// left over from before ios/RNZoomUsVideoView.m existed, and the branch it
// guarded had the same call on both sides anyway.
export const RNZoomUsVideoView = requireNativeComponent(
  "RNZoomUsVideoView"
) as HostComponent<NativeVideoProps> | null;

export const RNZoomUs = NativeModules.RNZoomUs;

/**
 * On Android the SDK ships in an on-demand module, so RNZoomUs is legitimately
 * absent until that module is installed -- which is the normal state of a fresh
 * install. Only the loader's absence means the library is not linked at all.
 * Reporting the expected case with console.error would raise a red box on every
 * launch in development.
 */
export const RNZoomUsLoader = NativeModules.RNZoomUsLoader;

if (!RNZoomUs && !RNZoomUsLoader) {
  console.error("[react-native-zoom-us] RNZoomUs native module is not linked.");
}
