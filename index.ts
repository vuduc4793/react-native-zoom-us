import { Platform } from "react-native";
import invariant from "invariant";
import { RNZoomUs } from "./native";

/**
 * The native module, or a stand-in that rejects every call with a message.
 *
 * RNZoomUs is legitimately absent on Android until the on-demand module is
 * installed -- the normal state of a fresh install -- and without this every
 * command fails as "Cannot read property 'initialize' of null", which says
 * nothing about what went wrong or what to do. Rejecting rather than throwing
 * keeps the failure on the promise these all return, so a caller's .catch()
 * sees it instead of an exception escaping mid-render.
 */
const native: any =
  RNZoomUs ??
  new Proxy(
    {},
    {
      get: (_target, key) => () =>
        Promise.reject(
          new Error(
            `[react-native-zoom-us] ZoomUs.${String(key)}() was called but the ` +
              `Zoom SDK is not loaded in this process. On Android it ships as an ` +
              `on-demand module: await ZoomModule.isInstalled(), and ` +
              `ZoomModule.install() if it is not there yet.`
          )
        ),
    }
  );
import events from "./src/events";

const DEFAULT_USER_TYPE = 2;

type Language =
  | "de"
  | "ja"
  | "en"
  | "zh-Hant"
  | "es"
  | "zh-Hans"
  | "it"
  | "ko"
  | "vi"
  | "ru"
  | "pt-PT"
  | "fr";

const applyLanguageMapping = (language: Language): string => {
  const androidLanguageMapping = {
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
  };
  if (Platform.OS === "android") {
    return androidLanguageMapping[language] || language;
  }

  return language;
};
interface RNZoomUsInitializeCommonParams {
  domain?: string;
  iosAppGroupId?: string;
  iosScreenShareExtensionId?: string;
}
export interface RNZoomUsInitializeParams
  extends RNZoomUsInitializeCommonParams {
  jwtToken: string;
}

type InitializeSettings = {
  language?: Language;
  enableCustomizedMeetingUI?: boolean;
  disableShowVideoPreviewWhenJoinMeeting?: boolean;
  disableMinimizeMeeting?: boolean;
  disableClearWebKitCache?: boolean;
  meetingShareHidden?: boolean;
  meetingVideoHidden?: boolean;
  meetingAudioHidden?: boolean;
  closeCaptionHidden?: boolean;
  disableCloudWhiteboard?: boolean;
  meetingMoreHidden?: boolean;

  /**
   * iOS only. Android hides the same things through joinMeeting/startMeeting
   * params instead -- noTextMeetingId, noTextPassword, noInvite, noTitlebar --
   * because its SDK has no equivalent on the settings object.
   *
   * These four were hardcoded on iOS before 14.0.0; the defaults below keep
   * that behaviour, so passing nothing changes nothing.
   */
  /** Hide the meeting title, which is what reveals the meeting id. @default true */
  meetingTitleHidden?: boolean;
  /** @default true */
  meetingPasswordHidden?: boolean;
  /** @default true */
  meetingInviteHidden?: boolean;
  /** @default true */
  meetingInviteUrlHidden?: boolean;
  /** @default true */
  disableCopyMeetingUrl?: boolean;
  /** @default true */
  disableDriveMode?: boolean;
  /** @default true */
  autoConnectInternetAudio?: boolean;
  /** Chat has always been visible on iOS; this is the knob for it. @default false */
  meetingChatHidden?: boolean;
};

export interface ZoomChatInfo {
  chatId?: string
  chatMessageType?: number
  content: string
  date?: string
  isChatToAll?: boolean
  isChatToAllPanelist?: boolean
  isChatToWaitingroom?: boolean
  isComment?: boolean
  isMyself?: boolean
  isPrivate?: boolean
  isThread?: boolean
  receiverId: number
  receiverName?: string
  senderId?: string
  senderName?: string
  threadID?: string
  hostId?: number
  messageToHost?: string
  previousChatId?: string
}

async function initialize(
  {
    domain = "zoom.us",
    ...params
  }: RNZoomUsInitializeParams,
  {
    language = "en",
    enableCustomizedMeetingUI = false,

    // ios only
    // more details inside: https://github.com/mieszko4/react-native-zoom-us/issues/28
    disableShowVideoPreviewWhenJoinMeeting = true,

    // ios only
    disableMinimizeMeeting = false,

    disableClearWebKitCache = false,
    ...settings
  }: InitializeSettings = {}
): Promise<string> {
  invariant(
    typeof params === "object",
    "ZoomUs.initialize expects object param. Consider to check migration docs. " +
    "Check Link: https://github.com/mieszko4/react-native-zoom-us/blob/master/docs/UPGRADING.md"
  );

  invariant(params.jwtToken, "ZoomUs.initialize requires jwtToken");

  const mappedSettings = {
    language: applyLanguageMapping(language),
    enableCustomizedMeetingUI,

    disableShowVideoPreviewWhenJoinMeeting,

    disableMinimizeMeeting,
    disableClearWebKitCache,
    ...settings
  };

  const mappedParams = {
    domain,
    ...params,
  };

  return native.initialize(mappedParams, mappedSettings);
}

function cleanup(): Promise<string> {
  return native.cleanup();
}

function isInitialized(): Promise<boolean> {
  return native.isInitialized();
}

export interface RNZoomUsJoinMeetingParams {
  userName: string;
  meetingNumber: string | number;
  password?: string;
  autoConnectAudio?: boolean;
  noAudio?: boolean;
  noVideo?: boolean;

  noButtonLeave?: boolean;
  noButtonMore?: boolean;
  noButtonParticipants?: boolean;
  noButtonShare?: boolean;
  noTextMeetingId?: boolean;
  noTextPassword?: boolean;
  webinarToken?: string;
  zoomAccessToken?: string;

  // android only fields:
  noInvite?: boolean;
  noBottomToolbar?: boolean;
  noPhoneDialIn?: boolean;
  noPhoneDialOut?: boolean;
  noMeetingEndMessage?: boolean;
  noMeetingErrorMessage?: boolean;
  noShare?: boolean;
  noTitlebar?: boolean;
  noDrivingMode?: boolean;
  noDisconnectAudio?: boolean;
  noRecord?: boolean;
  noUnmuteConfirmDialog?: boolean;
  noWebinarRegisterDialog?: boolean;
  noChatMsgToast?: boolean;
}
async function joinMeeting(params: RNZoomUsJoinMeetingParams) {
  let {
    meetingNumber,
    noAudio = false,
    noVideo = false,
    autoConnectAudio = false,
  } = params;
  invariant(meetingNumber, "ZoomUs.joinMeeting requires meetingNumber");
  if (typeof meetingNumber !== "string")
    meetingNumber = meetingNumber.toString();

  // without noAudio, noVideo fields SDK can stack on joining meeting room for release build
  return native.joinMeeting({
    ...params,
    meetingNumber,
    noAudio: !!noAudio, // required
    noVideo: !!noVideo, // required
    autoConnectAudio, // required
  });
}

async function joinMeetingWithPassword(
  userName: RNZoomUsJoinMeetingParams["userName"],
  meetingNumber: NonNullable<RNZoomUsJoinMeetingParams["meetingNumber"]>,
  password: NonNullable<RNZoomUsJoinMeetingParams["password"]>
) {
  console.warn(
    "ZoomUs.joinMeetingWithPassword is deprecated. Use joinMeeting({ password: 'xxx', ... })"
  );
  return joinMeeting({
    userName,
    meetingNumber,
    password,
  });
}

export interface RNZoomUsStartMeetingParams {
  userName: string;
  meetingNumber: string | number;
  userType?: number; // looks like can be different for IOS and Android
  zoomAccessToken: string;

  // android only fields:
  noInvite?: boolean;
  noShare?: boolean;
  noMeetingErrorMessage?: boolean;

  noButtonLeave?: boolean;
  noButtonMore?: boolean;
  noButtonParticipants?: boolean;
  noButtonShare?: boolean;
  noTextMeetingId?: boolean;
  noTextPassword?: boolean;
}
async function startMeeting(params: RNZoomUsStartMeetingParams) {
  let { userType = DEFAULT_USER_TYPE, meetingNumber } = params;

  invariant(meetingNumber, "ZoomUs.startMeeting requires meetingNumber");
  if (typeof meetingNumber !== "string")
    meetingNumber = meetingNumber.toString();

  return native.startMeeting({ userType, ...params, meetingNumber });
}

async function leaveMeeting() {
  return native.leaveMeeting();
}

async function connectAudio() {
  return native.connectAudio();
}

async function isMeetingConnected() {
  return native.isMeetingConnected();
}

async function isMeetingHost() {
  return native.isMeetingHost();
}

async function getInMeetingUserIdList() {
  return native.getInMeetingUserIdList();
}

async function rotateMyVideo(rotation: number) {
  if (Platform.OS === "android") {
    return native.rotateMyVideo(rotation);
  } else {
    throw new Error("Only support android");
  }
}

async function muteMyVideo(muted: boolean) {
  return native.muteMyVideo(muted);
}

async function muteMyAudio(muted: boolean) {
  return native.muteMyAudio(muted);
}

async function muteAttendee(userId: string, muted: boolean) {
  return native.muteAttendee(userId, muted);
}

async function muteAllAttendee(allowUnmuteSelf: boolean) {
  return native.muteAllAttendee(allowUnmuteSelf);
}

async function startShareScreen() {
  return native.startShareScreen();
}

async function stopShareScreen() {
  return native.stopShareScreen();
}

async function switchCamera() {
  return native.switchCamera();
}

async function raiseMyHand() {
  return native.raiseMyHand();
}

async function lowerMyHand() {
  return native.lowerMyHand();
}

async function joinBO() {
  return native.joinBO();
}

async function leaveBO() {
  return native.leaveBO();
}

async function requestForHelp() {
  return native.requestForHelp();
}

async function isHostInThisBO() {
  return native.isHostInThisBO();
}

async function getAllChatMessageID() {
  return native.getAllChatMessageID();
}

async function sendChatMsg(msgData: ZoomChatInfo) {
  return native.sendChatMsg(msgData);
}

async function deleteChatMessage(msgId: string)  {
  return native.deleteChatMessage(msgId);
}

async function isHostUser({ userId }: { userId: number }) {
  return native.isHostUser(userId);
}

async function getMyselfUserID(): Promise<number> {
  return native.getMyselfUserID();
}



// v1 component. Still exported unchanged; it positions video units from a
// hand-computed `layout` array and has to sit at the top of the view tree.
export { default as ZoomUsVideoView } from "./video-view";

// v2 component. Positions video units from ordinary React Native layout and can
// be nested anywhere. See docs/VIDEO-VIEW-V2.md.
export { ZoomVideoView } from "./src/components/ZoomVideoView";
export type { ZoomVideoViewProps } from "./src/components/ZoomVideoView";

export * from "./src/events";
export * from "./src/hooks";

// Android: the SDK is delivered as an on-demand module. See docs/DYNAMIC-FEATURE.md.
export { default as ZoomModule } from "./src/module";
export { zoom } from "./src/commands";
export type { ZoomNativeApi, ZoomObject } from "./src/commands";
export type {
  ZoomModuleStatus,
  ZoomModuleProgress,
  InstallOptions,
} from "./src/module";
export default {
  initialize,
  cleanup,
  joinMeeting,
  joinMeetingWithPassword,
  startMeeting,
  leaveMeeting,
  connectAudio,
  isInitialized,
  isMeetingHost,
  isMeetingConnected,
  getInMeetingUserIdList,
  rotateMyVideo,
  muteMyVideo,
  muteMyAudio,
  muteAttendee,
  muteAllAttendee,
  startShareScreen,
  stopShareScreen,
  switchCamera,
  raiseMyHand,
  lowerMyHand,
  joinBO,
  leaveBO,
  requestForHelp,
  isHostInThisBO,
  getAllChatMessageID,
  sendChatMsg,
  isHostUser,
  deleteChatMessage,
  getMyselfUserID,
  ...events,
};
