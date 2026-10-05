package ch.milosz.reactnative.loader;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import com.google.android.play.core.splitinstall.SplitInstallManager;
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory;
import com.google.android.play.core.splitinstall.SplitInstallRequest;
import com.google.android.play.core.splitinstall.SplitInstallSessionState;
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener;
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus;

/**
 * Downloads the on-demand module that carries the Zoom SDK.
 *
 * This class must not reference anything from us.zoom.* -- it ships in the base
 * APK, where those classes do not exist yet.
 */
@ReactModule(name = RNZoomUsLoaderModule.NAME)
public class RNZoomUsLoaderModule extends ReactContextBaseJavaModule {

    public static final String NAME = "RNZoomUsLoader";

    /** Must match the Gradle project name of the dynamic feature module. */
    public static final String FEATURE_MODULE = "zoom";

    private static final String TAG = "RNZoomUsLoader";
    private static final String EVENT = "ZoomUsModuleInstall";

    private final SplitInstallManager splitInstallManager;
    private SplitInstallStateUpdatedListener listener;
    /** The install() promise still in flight, or null. Settled exactly once. */
    private Promise pendingInstall;

    public RNZoomUsLoaderModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.splitInstallManager = SplitInstallManagerFactory.create(reactContext);
    }

    @NonNull
    @Override
    public String getName() {
        return NAME;
    }

    public static boolean isModuleInstalled(Context context) {
        try {
            return SplitInstallManagerFactory.create(context)
                    .getInstalledModules()
                    .contains(FEATURE_MODULE);
        } catch (Throwable t) {
            Log.e(TAG, "Could not query installed modules", t);
            return false;
        }
    }

    @ReactMethod
    public void isInstalled(Promise promise) {
        promise.resolve(isModuleInstalled(getReactApplicationContext()));
    }

    @ReactMethod
    public void install(final Promise promise) {
        if (isModuleInstalled(getReactApplicationContext())) {
            promise.resolve(false); // already present, no restart needed
            return;
        }

        // A second call must not unregister the first one's listener: that would
        // leave the first promise unsettled forever, and the caller awaiting it.
        if (pendingInstall != null) {
            promise.reject("ERR_ZOOM_MODULE_BUSY", "An install is already in progress");
            return;
        }
        pendingInstall = promise;

        listener = new SplitInstallStateUpdatedListener() {
            @Override
            public void onStateUpdate(@NonNull SplitInstallSessionState state) {
                if (!state.moduleNames().contains(FEATURE_MODULE)) return;

                emitProgress(state);

                switch (state.status()) {
                    case SplitInstallSessionStatus.INSTALLED:
                        clearListener();
                        // The split's classes, resources and .so files only become
                        // visible to the framework once the process restarts. Doing
                        // that here avoids every SplitCompat problem, including the
                        // ones in Zoom's own activities, which cannot be patched.
                        settleResolve(true);
                        restartProcess();
                        break;
                    case SplitInstallSessionStatus.FAILED:
                        clearListener();
                        settleReject("ERR_ZOOM_MODULE_INSTALL",
                                "Install failed with error code " + state.errorCode());
                        break;
                    case SplitInstallSessionStatus.CANCELED:
                        // Play asks for confirmation on a download this size over a
                        // metered connection; declining lands here. Its own code, so
                        // the caller can stay quiet instead of showing an error.
                        clearListener();
                        settleReject("ERR_ZOOM_MODULE_CANCELED",
                                "The download was canceled");
                        break;
                    case SplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION:
                        Activity activity = getCurrentActivity();
                        if (activity == null || state.resolutionIntent() == null) {
                            // Nothing can show the dialog, so the session would sit
                            // in this state indefinitely. Report it rather than
                            // leaving the caller awaiting a promise that never
                            // settles.
                            Log.e(TAG, "Install needs confirmation but no activity is available");
                            clearListener();
                            settleReject("ERR_ZOOM_MODULE_CONFIRMATION",
                                    "The download needs confirmation, but no activity is in the foreground");
                            break;
                        }
                        try {
                            activity.startIntentSender(
                                    state.resolutionIntent().getIntentSender(), null, 0, 0, 0);
                        } catch (Throwable t) {
                            Log.e(TAG, "Could not show install confirmation", t);
                            clearListener();
                            settleReject("ERR_ZOOM_MODULE_CONFIRMATION", t.getMessage());
                        }
                        break;
                    default:
                        break;
                }
            }
        };

        splitInstallManager.registerListener(listener);
        splitInstallManager
                .startInstall(SplitInstallRequest.newBuilder().addModule(FEATURE_MODULE).build())
                .addOnFailureListener(e -> {
                    clearListener();
                    settleReject("ERR_ZOOM_MODULE_INSTALL", e.getMessage());
                });
    }

    private void clearListener() {
        if (listener != null) {
            splitInstallManager.unregisterListener(listener);
            listener = null;
        }
    }

    /**
     * Settle the in-flight install() promise, at most once.
     *
     * Play reports states on its own thread and can report more than one
     * terminal state for a session, so every exit goes through here.
     */
    private void settleResolve(boolean value) {
        Promise promise = pendingInstall;
        pendingInstall = null;
        if (promise != null) promise.resolve(value);
    }

    private void settleReject(String code, String message) {
        Promise promise = pendingInstall;
        pendingInstall = null;
        if (promise != null) promise.reject(code, message);
    }

    private void emitProgress(SplitInstallSessionState state) {
        WritableMap params = Arguments.createMap();
        params.putString("status", statusName(state.status()));
        params.putDouble("bytesDownloaded", (double) state.bytesDownloaded());
        params.putDouble("totalBytesToDownload", (double) state.totalBytesToDownload());
        params.putInt("errorCode", state.errorCode());
        try {
            if (!getReactApplicationContext().hasActiveReactInstance()) return;
            getReactApplicationContext()
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                    .emit(EVENT, params);
        } catch (Exception ex) {
            Log.e(TAG, "Could not emit install progress", ex);
        }
    }

    private static String statusName(int status) {
        switch (status) {
            case SplitInstallSessionStatus.PENDING: return "pending";
            case SplitInstallSessionStatus.DOWNLOADING: return "downloading";
            case SplitInstallSessionStatus.DOWNLOADED: return "downloaded";
            case SplitInstallSessionStatus.INSTALLING: return "installing";
            case SplitInstallSessionStatus.INSTALLED: return "installed";
            case SplitInstallSessionStatus.FAILED: return "failed";
            case SplitInstallSessionStatus.CANCELING: return "canceling";
            case SplitInstallSessionStatus.CANCELED: return "canceled";
            case SplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION: return "requiresUserConfirmation";
            default: return "unknown";
        }
    }

    @ReactMethod
    public void restart() {
        restartProcess();
    }

    /**
     * Full process restart. react-native-restart only recreates the React
     * instance, which is not enough: the framework reads splitSourceDirs when
     * the process starts.
     */
    private void restartProcess() {
        Context context = getReactApplicationContext();
        Intent intent = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
        if (intent == null) {
            Log.e(TAG, "No launch intent; cannot restart");
            return;
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        context.startActivity(intent);
        Runtime.getRuntime().exit(0);
    }

    // Required for NativeEventEmitter.
    @ReactMethod
    public void addListener(String eventName) {}

    @ReactMethod
    public void removeListeners(double count) {}
}
