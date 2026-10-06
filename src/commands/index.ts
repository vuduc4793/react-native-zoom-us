import { NativeModules, Platform } from "react-native";
import { ZOOM_ROUTES } from "./routes";
import type { ZoomNativeApi } from "./generated";

export type { ZoomNativeApi, ZoomObject } from "./generated";
export { ZOOM_ROUTES } from "./routes";

/**
 * Every Zoom SDK method, by name.
 *
 *   await zoom.InMeetingWaitingRoomController.admitToMeeting(userId);
 *   await zoom.InMeetingChatController.isChatDisabled();
 *   const info = await zoom.InMeetingService.getMyUserInfo();
 *
 * The hand-written commands on the default export cover the common path and
 * keep their nicer shapes. This is the rest of the SDK -- 967 methods across 57
 * objects -- reachable without a wrapper per call, so nothing has to be rebuilt
 * and republished the day a screen needs one more of them.
 *
 * Android only for now: the native side is one reflective invoke(), and iOS has
 * no counterpart yet. Calls there reject rather than silently doing nothing.
 *
 * Regenerate the surface after an SDK upgrade with
 * `python3 scripts/generate-commands.py`.
 */
const RNZoomUs = NativeModules.RNZoomUs;

function unsupported(controller: string, method: string): Promise<never> {
  return Promise.reject(
    new Error(
      `[react-native-zoom-us] zoom.${controller}.${method}() is not available on ` +
        `${Platform.OS}. The generic SDK bridge is Android only; use the typed ` +
        `commands on the default export, which both platforms implement.`
    )
  );
}

function controllerProxy(controller: string, route: string) {
  return new Proxy(
    {},
    {
      get(_target, key) {
        // Reading .then on a plain object must stay undefined: an await on this
        // proxy would otherwise treat it as a thenable and never settle.
        if (typeof key !== "string" || key === "then") return undefined;

        return (...args: unknown[]) => {
          if (!RNZoomUs || typeof RNZoomUs.invoke !== "function") {
            return unsupported(controller, key);
          }
          return RNZoomUs.invoke(route, key, args);
        };
      },
    }
  );
}

const cache = new Map<string, object>();

export const zoom = new Proxy({} as ZoomNativeApi, {
  get(_target, key) {
    if (typeof key !== "string" || key === "then") return undefined;

    const route = ZOOM_ROUTES[key];
    if (route === undefined) {
      throw new Error(
        `[react-native-zoom-us] no Zoom SDK object called "${key}". ` +
          `Known objects are listed in src/commands/routes.ts.`
      );
    }

    let proxy = cache.get(key);
    if (!proxy) {
      proxy = controllerProxy(key, route);
      cache.set(key, proxy);
    }
    return proxy;
  },
}) as ZoomNativeApi;

export default zoom;
