import { NativeEventEmitter, Platform, EmitterSubscription } from "react-native";
import { RNZoomUsLoader } from "../native";

/**
 * Controls the on-demand module that carries the Zoom SDK on Android.
 *
 * Zoom is roughly 140 MB of the Android build, which is what pushes the app over
 * Google Play's 200 MB per-device download limit. Delivering it on demand keeps
 * it out of the initial download entirely.
 *
 * On iOS the SDK is always part of the app, so isInstalled() resolves true and
 * install() does nothing -- the same call sequence works on both platforms.
 */

export type ZoomModuleStatus =
  | "pending"
  | "downloading"
  | "downloaded"
  | "installing"
  | "installed"
  | "failed"
  | "canceling"
  | "canceled"
  | "requiresUserConfirmation"
  | "unknown";

export interface ZoomModuleProgress {
  status: ZoomModuleStatus;
  bytesDownloaded: number;
  totalBytesToDownload: number;
  errorCode: number;
}

const Loader = RNZoomUsLoader;

const INSTALL_EVENT = "ZoomUsModuleInstall";

/** Is the Zoom SDK available in this process right now? */
async function isInstalled(): Promise<boolean> {
  if (Platform.OS !== "android") return true;
  if (!Loader) return false;
  return Loader.isInstalled();
}

/** Watch download progress. Android only; a no-op elsewhere. */
function addProgressListener(
  listener: (progress: ZoomModuleProgress) => void
): EmitterSubscription {
  if (Platform.OS !== "android" || !Loader) {
    return { remove() {} } as EmitterSubscription;
  }
  return new NativeEventEmitter(Loader).addListener(INSTALL_EVENT, listener);
}

export interface InstallOptions {
  onProgress?: (progress: ZoomModuleProgress) => void;
}

/**
 * Download and install the Zoom module.
 *
 * Resolves `true` when the module was installed, in which case **the process
 * restarts immediately** -- the split's classes, resources and native libraries
 * only become visible to the framework on a fresh process. Resolves `false` when
 * the module was already present and nothing had to be done.
 *
 * Because the app relaunches, make sure the screen that needs Zoom is reachable
 * again afterwards: deep link back into it, or persist enough state to restore
 * it.
 *
 * Rejects -- always, rather than leaving the caller awaiting -- with:
 *   `ERR_ZOOM_MODULE_CANCELED`      the download was canceled, including by the
 *                                   user declining Play's own confirmation
 *                                   dialog, which it shows for a module this
 *                                   large on a metered connection
 *   `ERR_ZOOM_MODULE_CONFIRMATION`  that dialog could not be shown, because no
 *                                   activity is in the foreground
 *   `ERR_ZOOM_MODULE_BUSY`          an install is already in progress
 *   `ERR_ZOOM_MODULE_INSTALL`       Play reported a failure; the message carries
 *                                   its error code
 */
async function install({ onProgress }: InstallOptions = {}): Promise<boolean> {
  if (Platform.OS !== "android") return false;
  if (!Loader) {
    throw new Error(
      "[react-native-zoom-us] RNZoomUsLoader native module is not linked."
    );
  }

  const subscription = onProgress ? addProgressListener(onProgress) : null;
  try {
    return await Loader.install();
  } finally {
    subscription?.remove();
  }
}

/**
 * Restart the process. install() already does this; exposed for the case where
 * the module is reported installed but its classes are not loadable yet, which
 * means the process has not restarted since.
 */
function restart(): void {
  if (Platform.OS === "android" && Loader) Loader.restart();
}

export default {
  isInstalled,
  install,
  restart,
  addProgressListener,
};
