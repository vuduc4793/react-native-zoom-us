import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";
import type { Int32, UnsafeObject } from "react-native/Libraries/Types/CodegenTypes";

/**
 * Codegen spec for the RNZoomUs native module.
 *
 * Parameter bags such as the initialize/join/start options are typed as
 * UnsafeObject rather than exhaustive object literals: the shapes are large,
 * differ between Android and iOS, and are already described by the hand-written
 * types in `index.ts`, which is what callers actually see. Spelling them out
 * twice would guarantee the two drift apart.
 */
export interface Spec extends TurboModule {
  initialize(params: UnsafeObject, settings: UnsafeObject): Promise<string>;
  cleanup(): Promise<string>;
  isInitialized(): Promise<boolean>;

  joinMeeting(params: UnsafeObject): Promise<void>;
  startMeeting(params: UnsafeObject): Promise<void>;
  leaveMeeting(): Promise<void>;
  isMeetingConnected(): Promise<boolean>;
  isMeetingHost(): Promise<boolean>;

  addVideoView(tagId: Int32): Promise<void>;
  removeVideoView(tagId: Int32): Promise<void>;

  connectAudio(): Promise<void>;
  muteMyAudio(muted: boolean): Promise<void>;
  muteMyVideo(muted: boolean): Promise<void>;
  muteAttendee(userId: string, muted: boolean): Promise<void>;
  muteAllAttendee(allowUnmuteSelf: boolean): Promise<void>;
  switchCamera(): Promise<void>;
  rotateMyVideo(rotation: Int32): Promise<void>;

  startShareScreen(): Promise<void>;
  stopShareScreen(): Promise<void>;

  raiseMyHand(): Promise<void>;
  lowerMyHand(): Promise<void>;

  getInMeetingUserIdList(): Promise<UnsafeObject>;
  getMyselfUserID(): Promise<Int32>;
  isHostUser(userId: Int32): Promise<boolean>;

  joinBO(): Promise<void>;
  leaveBO(): Promise<void>;
  isHostInThisBO(): Promise<boolean>;
  requestForHelp(): Promise<void>;

  sendChatMsg(msgData: UnsafeObject): Promise<void>;
  deleteChatMessage(msgId: string): Promise<void>;

  getAllChatMessageID(): Promise<UnsafeObject>;

  // Generic bridge: any SDK method by path, or on an object JS received (ref).
  invoke(path: string, method: string, args: UnsafeObject): Promise<UnsafeObject>;
  invokeRef(ref: string, method: string, args: UnsafeObject): Promise<UnsafeObject>;
  releaseRef(ref: string): void;
  setPromptMode(prompt: string, mode: string, timeoutMs: number): Promise<void>;

  // Required by NativeEventEmitter.
  addListener(eventName: string): void;
  removeListeners(count: Int32): void;
}

export default TurboModuleRegistry.get<Spec>("RNZoomUs");
