import { NativeModules, Platform } from "react-native";
import { ZOOM_ROUTES } from "./routes";
import { ZOOM_IOS_ROUTES } from "./ios-routes";
import type { ZoomNativeApi } from "./generated";
import type { ZoomIosApi } from "./ios-generated";

export type { ZoomNativeApi, ZoomObject } from "./generated";
export type { ZoomIosApi } from "./ios-generated";
export { ZOOM_ROUTES } from "./routes";
export { ZOOM_IOS_ROUTES } from "./ios-routes";

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
 * Both platforms: Android goes through one reflective invoke()
 * (RNZoomUsCommands.java, 56 objects / 948 methods) and iOS through one
 * NSInvocation (ios/RNZoomUsCommands.m, 10 objects / 707 methods). Neither
 * needs a wrapper per call, which is the point: a screen that turns out to need
 * one more SDK call ships as an OTA update instead of a native rebuild and a
 * republish.
 *
 * The two SDKs do not name their objects alike -- Android nests controllers
 * (`InMeetingService.getInMeetingChatController`) where iOS puts everything in
 * categories on `MeetingService` -- so a name usually exists on one platform
 * only. The type is the union of both so each autocompletes; at runtime an
 * object the current platform does not have throws, naming the platform, and a
 * selector the object does not implement rejects with "does not respond to".
 *
 * Regenerate after an SDK upgrade with
 * `python3 scripts/generate-commands.py` and
 * `ZOOM_IOS_HEADERS=... python3 scripts/generate-ios-commands.py`.
 */
const RNZoomUs = NativeModules.RNZoomUs;

/** Route table for the platform actually running. */
const ROUTES: Record<string, string> =
  Platform.OS === "ios" ? ZOOM_IOS_ROUTES : ZOOM_ROUTES;

function unsupported(controller: string, method: string): Promise<never> {
  return Promise.reject(
    new Error(
      `[react-native-zoom-us] zoom.${controller}.${method}() cannot reach the ` +
        `native bridge on ${Platform.OS}: NativeModules.RNZoomUs.invoke is ` +
        `missing. The installed binary predates the generic bridge, so this ` +
        `call needs an app update rather than a JavaScript one.`
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

export const zoom = new Proxy({} as ZoomNativeApi & ZoomIosApi, {
  get(_target, key) {
    if (typeof key !== "string" || key === "then") return undefined;

    const route = ROUTES[key];
    if (route === undefined) {
      const other = Platform.OS === "ios" ? ZOOM_ROUTES : ZOOM_IOS_ROUTES;
      const hint =
        other[key] !== undefined
          ? ` It exists on ${Platform.OS === "ios" ? "Android" : "iOS"} only -- ` +
            `the two SDKs do not name their objects alike.`
          : "";
      throw new Error(
        `[react-native-zoom-us] no Zoom SDK object called "${key}" on ` +
          `${Platform.OS}.${hint} Known objects: ` +
          `${Platform.OS === "ios" ? "src/commands/ios-routes.ts" : "src/commands/routes.ts"}.`
      );
    }

    let proxy = cache.get(key);
    if (!proxy) {
      proxy = controllerProxy(key, route);
      cache.set(key, proxy);
    }
    return proxy;
  },
}) as ZoomNativeApi & ZoomIosApi;

export default zoom;
