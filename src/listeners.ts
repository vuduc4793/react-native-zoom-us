import { NativeModules } from "react-native";
import { addZoomListener } from "./events";
import type { ZoomRef } from "./commands";

/*
 * SDK objects built from JS, and SDK listener/delegate objects whose callbacks
 * arrive in JS. Both give back a ref: pass it as an argument to any zoom.*
 * call, or call methods on it with zoom.ref().
 */

const RNZoomUs = NativeModules.RNZoomUs;

function missing(method: string): Promise<never> {
  return Promise.reject(
    new Error(`[react-native-zoom-us] ${method} needs a native build that includes it (rebuild the app).`)
  );
}

/**
 * Build an SDK object: its no-arg constructor, then one setter (or field) per
 * prop. Class names are the SDK's own: "ChatMessageBuilder" (Android, looked up
 * in us.zoom.sdk) or "MobileRTCMeetingChatBuilder" (iOS).
 *
 *   const builder = await create("ChatMessageBuilder", { content: "hi" });
 *   const msg = await ref(builder).build();
 *   await zoom.InMeetingChatController.sendChatMsg(msg);
 *
 * Unknown props reject (ERR_ZOOM_CREATE) rather than being dropped.
 */
export function create(className: string, props: Record<string, unknown> = {}): Promise<{ __ref: string; __type: string } & Record<string, any>> {
  if (!RNZoomUs || typeof RNZoomUs.create !== "function") return missing("create");
  return RNZoomUs.create(className, props ?? {});
}

/**
 * An object implementing an SDK listener interface (Android) or delegate
 * protocol (iOS). Every callback is emitted as "onListenerCallback"; the
 * object answers each with the type's default (false / 0 / null). It stays
 * alive until releaseRef(). Prefer listen(), which wires the callbacks for you.
 */
export function createListener(typeName: string): Promise<{ __ref: string; __type: string }> {
  if (!RNZoomUs || typeof RNZoomUs.createListener !== "function") return missing("createListener");
  return RNZoomUs.createListener(typeName);
}

export interface ZoomListenerHandle {
  /** Pass this to the SDK call that takes the listener. */
  ref: { __ref: string; __type: string };
  /** Stop receiving callbacks and let native drop the object. */
  remove(): void;
}

/**
 * createListener() plus routing: `handlers[method](...args)` runs for each
 * callback (Android method name, or iOS selector such as "onFoo:bar:").
 *
 *   const l = await listen("MobileRTCRemoteControlDelegate", {
 *     "remoteControlPrivilegeChanged:": (on) => ...,
 *   });
 *   await zoom.RemoteControlService.setDelegate(l.ref);
 *   ...
 *   l.remove();
 */
export async function listen(
  typeName: string,
  handlers: Record<string, (...args: any[]) => void>
): Promise<ZoomListenerHandle> {
  const listener = await createListener(typeName);
  const id = listener?.__ref;
  const subscription = addZoomListener("onListenerCallback" as any, (payload: any) => {
    if (!payload || payload.listener !== id) return;
    const handler = handlers?.[payload.method];
    if (typeof handler !== "function") return;
    try {
      handler(...(Array.isArray(payload.args) ? payload.args : []));
    } catch (error) {
      console.warn(`[react-native-zoom-us] ${typeName}.${payload.method} handler threw`, error);
    }
  });
  let removed = false;
  return {
    ref: listener,
    remove() {
      if (removed) return;
      removed = true;
      subscription.remove();
      if (RNZoomUs && typeof RNZoomUs.releaseRef === "function" && id) RNZoomUs.releaseRef(id);
    },
  };
}

export type ZoomMeetingButton = "invite" | "end" | "audio" | "video" | "share" | "more" | "participants";

/**
 * Take over toolbar buttons of Zoom's own meeting UI. `true`: Zoom does
 * nothing on tap and the app reacts to "onClickMeetingButton" ({button,
 * handled}); `false` (default): Zoom's own action, and the event still fires.
 * iOS has no callback for "video" and "more".
 */
export function setButtonOverrides(overrides: Partial<Record<ZoomMeetingButton, boolean>>): Promise<void> {
  if (!RNZoomUs || typeof RNZoomUs.setButtonOverrides !== "function") return missing("setButtonOverrides");
  const clean: Record<string, boolean> = {};
  for (const [k, v] of Object.entries(overrides ?? {})) if (typeof v === "boolean") clean[k] = v;
  return RNZoomUs.setButtonOverrides(clean);
}

export type { ZoomRef };
