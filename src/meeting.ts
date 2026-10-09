import { NativeModules, Platform } from "react-native";
import { zoom } from "./commands";

/*
 * Cross-platform reads and actions for an in-meeting UI.
 *
 * The two SDKs expose the same facts under different objects, method names,
 * key spellings and enum orders (Android `isRaisedHand()` -> `raisedHand`,
 * iOS `handRaised`; Android role USERROLE_PANELIST is 3, iOS Attendee is 3).
 * Everything here goes through the generic bridge and returns one shape, so a
 * custom meeting UI never branches on Platform.OS -- and any mismatch found
 * later is an OTA fix in this file.
 */

const RNZoomUs = NativeModules.RNZoomUs;
const isAndroid = Platform.OS === "android";
const z = zoom as any;

export type ZoomRole = "host" | "cohost" | "panelist" | "attendee" | "moderator" | "none";

export interface ZoomParticipant {
  userId: number;
  userName: string;
  role: ZoomRole;
  isHost: boolean;
  isCoHost: boolean;
  isMySelf: boolean;
  /** Joined audio (VoIP or phone). */
  audioConnected: boolean;
  audioMuted: boolean;
  isTalking: boolean;
  videoOn: boolean;
  handRaised: boolean;
  inWaitingRoom: boolean;
  /** The SDK object, for anything not normalised here (zoom.ref(raw)). */
  raw: any;
}

const ANDROID_ROLES: Record<string, ZoomRole> = {
  USERROLE_HOST: "host",
  USERROLE_COHOST: "cohost",
  USERROLE_PANELIST: "panelist",
  USERROLE_BREAKOUTROOM_MODERATOR: "moderator",
  USERROLE_ATTENDEE: "attendee",
};
/** MobileRTCUserRole numbers. */
const IOS_ROLES: Record<number, ZoomRole> = { 1: "host", 2: "cohost", 3: "attendee", 4: "panelist", 5: "moderator" };

/** Android's AUDIO_TYPE and iOS MobileRTCAudioType agree: 2 = not connected. */
const AUDIO_TYPE_NONE = 2;

function bool(value: unknown): boolean {
  return value === true || value === 1;
}

/** One SDK user-info object, from either platform, as a ZoomParticipant. */
export function toParticipant(info: any): ZoomParticipant | null {
  if (!info || typeof info !== "object") return null;
  const audio = info.audioStatus ?? {};
  const video = info.videoStatus ?? {};
  const userId = Number(info.userId ?? info.userID);
  if (!Number.isFinite(userId)) return null;

  const role: ZoomRole = isAndroid
    ? ANDROID_ROLES[info.inMeetingUserRole] ?? "none"
    : IOS_ROLES[Number(info.userRole)] ?? "none";
  const audioType = Number(audio.audioType ?? AUDIO_TYPE_NONE);

  return {
    userId,
    userName: String(info.userName ?? ""),
    role,
    isHost: bool(info.host ?? info.isHost) || role === "host",
    isCoHost: bool(info.isCohost) || role === "cohost",
    isMySelf: bool(info.mySelf ?? info.isMySelf),
    audioConnected: audioType !== AUDIO_TYPE_NONE,
    audioMuted: bool(audio.muted ?? audio.isMuted) || audioType === AUDIO_TYPE_NONE,
    isTalking: bool(audio.talking ?? audio.isTalking),
    videoOn: bool(video.sending ?? video.isSending),
    handRaised: bool(info.raisedHand ?? info.handRaised),
    inWaitingRoom: bool(info.inWaitingRoom ?? info.isInWaitingRoom),
    raw: info,
  };
}

/** One participant, or null when the id is not (or no longer) in the meeting. */
export async function getParticipant(userId: number): Promise<ZoomParticipant | null> {
  try {
    const info = isAndroid
      ? await z.InMeetingService.getUserInfoById(userId)
      : await z.MeetingService.userInfoByID(userId);
    return toParticipant(info);
  } catch {
    return null;
  }
}

export async function getMyUserId(): Promise<number | null> {
  try {
    const id = isAndroid ? await z.InMeetingService.getMyUserID() : await z.MeetingService.myselfUserID();
    return typeof id === "number" && id > 0 ? id : null;
  } catch {
    return null;
  }
}

export async function getMyself(): Promise<ZoomParticipant | null> {
  const id = await getMyUserId();
  return id == null ? null : getParticipant(id);
}

/** Ids of everyone in the meeting (not the waiting room), myself included. */
export async function getParticipantIds(): Promise<number[]> {
  try {
    const ids = await RNZoomUs.getInMeetingUserIdList();
    return Array.isArray(ids) ? ids.map(Number).filter((n: number) => Number.isFinite(n) && n > 0) : [];
  } catch {
    return [];
  }
}

/**
 * Everyone, with details. One bridge call per person: prefer
 * getParticipantIds() plus getParticipant() for large meetings.
 */
export async function getParticipants(): Promise<ZoomParticipant[]> {
  const people = await Promise.all((await getParticipantIds()).map(getParticipant));
  return people.filter((p): p is ZoomParticipant => p != null);
}

/** Who Zoom is showing as the speaker right now (0 / null when nobody). */
export async function getActiveVideoUserId(): Promise<number | null> {
  try {
    const id = isAndroid
      ? await z.InMeetingVideoController.activeVideoUserID()
      : await z.MeetingService.activeUserID();
    return typeof id === "number" && id > 0 ? id : null;
  } catch {
    return null;
  }
}

/** Users whose screen share can be viewed, first one first. */
export async function getSharingUserIds(): Promise<number[]> {
  try {
    const ids = isAndroid
      ? await z.InMeetingShareController.getViewableSharingUserList()
      : await z.MeetingService.getViewableSharingUserList();
    return Array.isArray(ids) ? ids.map(Number).filter((n) => Number.isFinite(n) && n > 0) : [];
  } catch {
    return [];
  }
}

/** Whether I am sharing my screen right now. */
export async function isSharingOut(): Promise<boolean> {
  try {
    return bool(
      isAndroid
        ? await z.InMeetingShareController.isSharingOut()
        : await z.MeetingService.isStartingShare()
    );
  } catch {
    return false;
  }
}

export async function getMeetingTopic(): Promise<string> {
  try {
    const topic = isAndroid
      ? await z.InMeetingService.getCurrentMeetingTopic()
      : await z.InviteHelper.ongoingMeetingTopic();
    return typeof topic === "string" ? topic : "";
  } catch {
    return "";
  }
}

export async function isWebinar(): Promise<boolean> {
  try {
    return bool(isAndroid ? await z.InMeetingService.isWebinarMeeting() : await z.MeetingService.isWebinarMeeting());
  } catch {
    return false;
  }
}

export async function isChatDisabled(): Promise<boolean> {
  try {
    return bool(isAndroid ? await z.InMeetingChatController.isChatDisabled() : await z.MeetingService.isChatDisabled());
  } catch {
    return false;
  }
}

export async function canUnmuteMyVideo(): Promise<boolean> {
  try {
    return bool(isAndroid ? await z.InMeetingVideoController.canUnmuteMyVideo() : await z.MeetingService.canUnmuteMyVideo());
  } catch {
    return false;
  }
}

/** Join meeting audio over the internet (needed before unmuting in a custom UI). */
export async function connectAudio(): Promise<void> {
  if (isAndroid) {
    await z.InMeetingAudioController.connectAudioWithVoIP();
  } else {
    await RNZoomUs.connectAudio();
  }
}

export type ZoomReaction = "clap" | "thumbsup" | "heart" | "joy" | "openmouth" | "tada";
/** Same positions in Android SDKEmojiReactionType and iOS MobileRTCEmojiReactionType. */
const REACTION_INDEX: Record<ZoomReaction, number> = {
  clap: 1,
  thumbsup: 2,
  heart: 3,
  joy: 4,
  openmouth: 5,
  tada: 6,
};
const REACTION_BY_INDEX = Object.fromEntries(
  Object.entries(REACTION_INDEX).map(([k, v]) => [v, k])
) as Record<number, ZoomReaction>;
const REACTION_BY_NAME: Record<string, ZoomReaction> = {
  Clap: "clap",
  Thumbsup: "thumbsup",
  Heart: "heart",
  Joy: "joy",
  Openmouth: "openmouth",
  Tada: "tada",
};

/** A reaction value from an event (Android enum name or iOS number) as a ZoomReaction. */
export function toReaction(value: unknown): ZoomReaction | null {
  if (typeof value === "number") return REACTION_BY_INDEX[value] ?? null;
  if (typeof value === "string") {
    const key = value.replace(/^MobileRTCEmojiReactionType_/, "");
    return REACTION_BY_NAME[key] ?? null;
  }
  return null;
}

export async function sendReaction(reaction: ZoomReaction): Promise<void> {
  const index = REACTION_INDEX[reaction];
  if (isAndroid) {
    // The bridge accepts an enum constant by ordinal.
    await z.IEmojiReactionController.sendEmojiReaction(index);
  } else {
    await z.MeetingService.sendEmojiReaction(index);
  }
}

export interface ZoomChatMessageInfo {
  messageId: string;
  senderId: number | null;
  senderName: string;
  receiverId: number | null;
  content: string;
  /** epoch ms when the platform gives one */
  time: number | null;
  isMine: boolean;
  isPrivate: boolean;
  raw: any;
}

/**
 * Message time as epoch ms. The SDKs give seconds or ms as a number, and the
 * bridge's legacy chat payload gives "dd-MM-yyyy HH:mm:ss" (device local time).
 */
function parseMessageTime(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return value < 1e12 ? value * 1000 : value;
  }
  if (typeof value === "string") {
    const m = value.match(/^(\d{2})-(\d{2})-(\d{4}) (\d{2}):(\d{2}):(\d{2})$/);
    if (m) return new Date(+m[3], +m[2] - 1, +m[1], +m[4], +m[5], +m[6]).getTime();
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

/** Private when the SDK says so, or when it says the message is not to everyone. */
function isPrivateMessage(msg: any): boolean {
  if (msg.privateMsg !== undefined || msg.isPrivate !== undefined) return bool(msg.privateMsg ?? msg.isPrivate);
  const toAll = msg.chatToAll ?? msg.isChatToAll;
  return toAll !== undefined && !bool(toAll);
}

export function toChatMessage(msg: any, myUserId?: number | null): ZoomChatMessageInfo | null {
  if (!msg || typeof msg !== "object") return null;
  const senderId = Number(msg.senderUserId ?? msg.senderId);
  const receiverId = Number(msg.receiverUserId ?? msg.receiverId);
  const time = parseMessageTime(msg.time ?? msg.date);
  return {
    messageId: String(msg.msgId ?? msg.chatId ?? msg.messageId ?? ""),
    senderId: Number.isFinite(senderId) ? senderId : null,
    senderName: String(msg.senderDisplayName ?? msg.senderName ?? ""),
    receiverId: Number.isFinite(receiverId) ? receiverId : null,
    content: String(msg.content ?? ""),
    time,
    isMine: bool(msg.myself ?? msg.isMyself) || (myUserId != null && senderId === myUserId),
    isPrivate: isPrivateMessage(msg),
    raw: msg,
  };
}

/** Chat history the SDK still holds, oldest first. */
export async function getChatHistory(): Promise<ZoomChatMessageInfo[]> {
  let ids: unknown = [];
  try {
    ids = isAndroid
      ? await z.InMeetingChatController.getAllChatMessageID()
      : await RNZoomUs.getAllChatMessageID();
  } catch {
    return [];
  }
  if (!Array.isArray(ids)) return [];
  const me = await getMyUserId();
  const messages = await Promise.all(
    ids.map(async (id) => {
      try {
        const msg = isAndroid
          ? await z.InMeetingChatController.getChatMessageById(String(id))
          : await z.MeetingService.meetingChatByID(String(id));
        return toChatMessage(msg, me);
      } catch {
        return null;
      }
    })
  );
  return messages.filter((m): m is ZoomChatMessageInfo => m != null);
}

export interface ZoomReminder {
  title: string;
  text: string;
  /** The meeting waits until it is answered. */
  blocking: boolean;
  /** SDK enum name/number, for apps that word each kind themselves. */
  type: unknown;
  handler: { __ref: string } | null;
  raw: any;
}

/**
 * The "onReminderNotify" payload (setPromptMode("reminder", "js")): a
 * disclaimer Zoom needs an answer to -- recording, AI companion, live stream.
 */
export function toReminder(payload: any): ZoomReminder | null {
  const content = payload?.content;
  if (!content || typeof content !== "object") return null;
  const handlerRef = payload?.handler?.__ref;
  return {
    title: String(content.title ?? ""),
    text: String(content.content ?? ""),
    blocking: bool(content.blocking ?? content.isBlock ?? content.isBlocking),
    type: content.type,
    handler: typeof handlerRef === "string" && handlerRef ? { __ref: handlerRef } : null,
    raw: payload,
  };
}

/** Answer a reminder. "decline" maps to the iOS selector `declined`. */
export async function answerReminder(reminder: ZoomReminder, answer: "accept" | "decline" | "ignore"): Promise<void> {
  if (!reminder?.handler || !RNZoomUs || typeof RNZoomUs.invokeRef !== "function") return;
  try {
    await RNZoomUs.invokeRef(reminder.handler.__ref, answer, []);
  } catch (error) {
    console.warn("[react-native-zoom-us] answerReminder failed", error);
  }
}
