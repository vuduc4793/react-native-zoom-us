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
import { zoom } from "./src/commands";

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

  lastSettings = mappedSettings;
  lastInitParams = mappedParams;
  const result = await native.initialize(mappedParams, mappedSettings);
  await applyAndroidSettings(mappedSettings);
  return result;
}

/*
 * One set of keys on both platforms.
 *
 * The two SDKs put the same switches in different places: iOS keeps them on
 * MobileRTCMeetingSettings (set once, at initialize), Android splits them
 * between MeetingSettingsHelper / ZoomUIService and per-join MeetingOptions.
 * Each side's keys are translated to the other's here, in JavaScript, through
 * the generic bridge -- so a mapping that turns out wrong is an OTA fix.
 *
 * Every call is best-effort: a setting that fails is logged and must never be
 * the reason a join does not happen.
 */
let lastSettings: Record<string, any> = {};
let lastInitParams: Record<string, any> | null = null;

/** Zoom's "unable to join external meeting" (63 on both SDKs). */
export function isExternalMeetingError(error: any): boolean {
  const info = error?.userInfo;
  if (info && (info.errorCode === 63 || info.errorName === "unableToJoinExternalMeeting")) return true;
  return typeof error?.message === "string" && /errorCode=63\b/.test(error.message);
}

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Error 63 is intermittent for the same meeting: a retry often works, but
 * only after the app is restarted. A restart re-creates the SDK, so do that
 * here -- cleanup, initialize with the same token and settings -- and try the
 * join once more. A second failure is returned to the caller unchanged.
 */
async function withExternalMeetingRecovery<T>(label: string, attempt: () => Promise<T>): Promise<T> {
  try {
    return await attempt();
  } catch (error) {
    if (!isExternalMeetingError(error) || !lastInitParams) throw error;
    console.warn(`[react-native-zoom-us] ${label}: error 63, re-initializing the SDK and retrying once`);
    try {
      await wait(1500);
      await native.cleanup();
      await native.initialize(lastInitParams, lastSettings);
      await applyAndroidSettings(lastSettings);
    } catch (reinitError) {
      console.warn(`[react-native-zoom-us] ${label}: re-initialize failed`, reinitError);
      throw error;
    }
    return attempt();
  }
}

const PRIVACY_DEFAULTS = {
  meetingTitleHidden: true,
  meetingPasswordHidden: true,
  meetingInviteHidden: true,
  meetingInviteUrlHidden: true,
  disableCopyMeetingUrl: true,
};

async function bestEffort(label: string, call: () => Promise<unknown>) {
  try {
    await call();
  } catch (error) {
    console.warn(`[react-native-zoom-us] ${label} failed`, error);
  }
}

async function applyAndroidSettings(settings: Record<string, any>) {
  if (Platform.OS !== "android") return;
  const s: Record<string, any> = { ...PRIVACY_DEFAULTS, ...settings };
  const z: any = zoom;
  const jobs: Promise<void>[] = [
    bestEffort("disableCopyMeetingUrl", () =>
      z.MeetingSettingsHelper.disableCopyMeetingUrl(!!s.disableCopyMeetingUrl)),
    bestEffort("meetingInviteUrlHidden", () =>
      z.ZoomUIService.hideMeetingInviteUrl(!!s.meetingInviteUrlHidden)),
  ];
  // These change behaviour rather than hide information, so Android keeps its
  // own default unless the app asks.
  if (typeof s.autoConnectInternetAudio === "boolean") {
    jobs.push(bestEffort("autoConnectInternetAudio", () =>
      z.MeetingSettingsHelper.setAutoConnectVoIPWhenJoinMeeting(s.autoConnectInternetAudio)));
  }
  if (typeof s.meetingChatHidden === "boolean") {
    jobs.push(bestEffort("meetingChatHidden", () =>
      z.MeetingSettingsHelper.disableChatUI(s.meetingChatHidden)));
  }
  if (typeof s.disableMinimizeMeeting === "boolean") {
    jobs.push(bestEffort("disableMinimizeMeeting", () =>
      z.ZoomUIService.enableMinimizeMeeting(!s.disableMinimizeMeeting)));
  }
  await Promise.all(jobs);
}

/** Android: initialize settings that Android only accepts per join. */
function androidJoinDefaults(): Record<string, boolean> {
  if (Platform.OS !== "android") return {};
  const s: Record<string, any> = { ...PRIVACY_DEFAULTS, ...lastSettings };
  const out: Record<string, boolean> = {
    noTextMeetingId: !!s.meetingTitleHidden,
    noTextPassword: !!s.meetingPasswordHidden,
    noInvite: !!s.meetingInviteHidden,
  };
  if (typeof s.disableDriveMode === "boolean") out.noDrivingMode = s.disableDriveMode;
  return out;
}

/** iOS: join/start options that iOS only accepts as meeting settings. */
const IOS_JOIN_OPTION_SETTERS: Record<string, string[]> = {
  noButtonLeave: ["setMeetingLeaveHidden"],
  noButtonMore: ["setMeetingMoreHidden"],
  noButtonParticipants: ["setMeetingParticipantHidden"],
  noButtonShare: ["setMeetingShareHidden"],
  noShare: ["setMeetingShareHidden"],
  noTextMeetingId: ["setMeetingTitleHidden"],
  noTextPassword: ["setMeetingPasswordHidden"],
  noInvite: ["setMeetingInviteHidden", "setMeetingInviteUrlHidden"],
  noTitlebar: ["setTopBarHidden"],
  noBottomToolbar: ["setBottomBarHidden"],
  noDrivingMode: ["disableDriveMode"],
};

async function applyIosJoinOptions(params: Record<string, any>) {
  if (Platform.OS !== "ios") return;
  const z: any = zoom;
  const jobs: Promise<void>[] = [];
  for (const [key, setters] of Object.entries(IOS_JOIN_OPTION_SETTERS)) {
    // Only what the caller passed: an absent key leaves initialize's setting.
    if (typeof params[key] !== "boolean") continue;
    for (const setter of setters) {
      jobs.push(bestEffort(`${key} -> ${setter}`, () => z.MeetingSettings[setter](params[key])));
    }
  }
  await Promise.all(jobs);
}

async function prepareJoin(params: Record<string, any>) {
  await applyAndroidSettings(lastSettings);
  await applyIosJoinOptions(params);
  return { ...androidJoinDefaults(), ...params };
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
  /**
   * Required to join a meeting hosted by a different Zoom account than the one
   * that owns the SDK key; without it Zoom fails the join with error 63
   * (unableToJoinExternalMeeting). Issued by your backend through Zoom's API.
   */
  onBehalfToken?: string;
  /** Grants in-meeting privileges such as local recording or raw streaming. */
  appPrivilegeToken?: string;
  joinToken?: string;

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

  return withExternalMeetingRecovery("joinMeeting", async () => {
    const prepared = await prepareJoin(params);
    // without noAudio, noVideo fields SDK can stack on joining meeting room for release build
    return native.joinMeeting({
      ...prepared,
      meetingNumber,
      noAudio: !!noAudio, // required
      noVideo: !!noVideo, // required
      autoConnectAudio, // required
    });
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

  const prepared = await prepareJoin(params);
  return native.startMeeting({ userType, ...prepared, meetingNumber });
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

/**
 * @param rotation Android Surface.ROTATION_* -- 0, 1 (90°), 2 (180°), 3 (270°).
 * The same values work on iOS; they are translated to UIDeviceOrientation.
 */
async function rotateMyVideo(rotation: number) {
  if (Platform.OS === "android") {
    return native.rotateMyVideo(rotation);
  }
  // Surface.ROTATION_90 is the device turned counter-clockwise, which iOS calls
  // UIDeviceOrientationLandscapeLeft (3); ROTATION_270 is LandscapeRight (4).
  const orientation = ({ 0: 1, 1: 3, 2: 2, 3: 4 } as Record<number, number>)[rotation];
  if (orientation === undefined) {
    throw new Error(`rotateMyVideo: rotation must be 0, 1, 2 or 3, got ${rotation}`);
  }
  const ok = await (zoom as any).MeetingService.rotateMyVideo(orientation);
  if (!ok) throw new Error("Error: Rotate video failed");
  return null;
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

async function getAllChatMessageID(): Promise<string[]> {
  // Android has no hand-written export for this; the SDK call is the same.
  const ids =
    Platform.OS === "android"
      ? await (zoom as any).InMeetingChatController.getAllChatMessageID()
      : await native.getAllChatMessageID();
  return Array.isArray(ids) ? ids : [];
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

/**
 * Who answers a prompt Zoom hands over as a one-shot callback.
 *
 * - "auto" (default): native answers as it always has.
 * - "js": the event carries `responder`; call
 *   `zoom.ref(payload.responder).respond(true | false)`. If JS has not
 *   answered within `timeoutMs` (default 10 s), the default answer is used, so
 *   a JS that forgets can never leave Zoom waiting.
 *
 * "videoUnmuteRequest" -- the host asks to start your camera
 * (onSinkMeetingVideoRequestUnmuteByHost). iOS only: Android's SDK shows its
 * own dialog for this and has nothing to hand over; the call resolves there.
 */
export type ZoomPrompt = "videoUnmuteRequest";
async function setPromptMode(prompt: ZoomPrompt, mode: "auto" | "js", timeoutMs = 10000): Promise<void> {
  if (typeof native.setPromptMode !== "function") return;
  return native.setPromptMode(prompt, mode, timeoutMs);
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
export * from "./src/enums";
export * from "./src/hooks";

// Android: the SDK is delivered as an on-demand module. See docs/DYNAMIC-FEATURE.md.
export { default as ZoomModule } from "./src/module";
export { zoom, ref, releaseRef } from "./src/commands";
export type { ZoomRef } from "./src/commands";
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
  setPromptMode,
  ...events,
};
