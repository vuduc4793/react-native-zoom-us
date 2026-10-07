package ch.milosz.reactnative;

import static us.zoom.sdk.ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_All;
import static us.zoom.sdk.ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_Individual;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.app.Activity;
import android.content.Intent;
import android.content.Context;
import android.media.projection.MediaProjectionManager;

import androidx.fragment.app.FragmentActivity;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.uimanager.UIManagerModule;
import com.facebook.react.uimanager.NativeViewHierarchyManager;
import com.facebook.react.uimanager.UIBlock;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.lang.Long;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Collections;
import java.util.Locale;

import us.zoom.sdk.BOControllerError;
import us.zoom.sdk.BOOption;
import us.zoom.sdk.BOStatus;
import us.zoom.sdk.CameraControlRequestResult;
import us.zoom.sdk.CameraControlRequestType;
import us.zoom.sdk.ChatMessageBuilder;
import us.zoom.sdk.IBOAdmin;
import us.zoom.sdk.IBOAdminEvent;
import us.zoom.sdk.IBOAssistant;
import us.zoom.sdk.IBOAttendee;
import us.zoom.sdk.IBOAttendeeEvent;
import us.zoom.sdk.IBOCreator;
import us.zoom.sdk.IBOData;
import us.zoom.sdk.ICameraControlRequestHandler;
import us.zoom.sdk.IMeetingArchiveConfirmHandler;
import us.zoom.sdk.IMeetingInputUserInfoHandler;
import us.zoom.sdk.IRecoverMeetingHandle;
import us.zoom.sdk.IShareAction;
import us.zoom.sdk.InMeetingBOController;
import us.zoom.sdk.InMeetingBOControllerListener;
import us.zoom.sdk.MeetingParameter;
import us.zoom.sdk.InMeetingVideoController;
import us.zoom.sdk.InMeetingAudioController;
import us.zoom.sdk.InMeetingChatMessage;
import us.zoom.sdk.InMeetingEventHandler;
import us.zoom.sdk.InMeetingService;
// Added in Zoom Meeting SDK 7.1.x
import us.zoom.sdk.InMeetingPreviewHandler;
import us.zoom.sdk.InMeetingAppSignalPanelHandler;
import us.zoom.sdk.EnumComponentType;
import us.zoom.sdk.MobileRTCNetworkQuality;
import us.zoom.sdk.InMeetingServiceListener;
import us.zoom.sdk.InMeetingShareController;
import us.zoom.sdk.InMeetingUserInfo;
import us.zoom.sdk.MeetingEndReason;
import us.zoom.sdk.MeetingSettingsHelper;
import us.zoom.sdk.MobileRTCShareView;
import us.zoom.sdk.ReturnToMainSessionHandler;
import us.zoom.sdk.ZoomSDK;
import us.zoom.sdk.ZoomError;
import us.zoom.sdk.ZoomSDKChatMessageType;
import us.zoom.sdk.ZoomSDKFileReceiver;
import us.zoom.sdk.ZoomSDKFileSender;
import us.zoom.sdk.ZoomSDKFileTransferInfo;
import us.zoom.sdk.ZoomSDKInitializeListener;
import us.zoom.sdk.ZoomSDKInitParams;
import us.zoom.sdk.FreeMeetingNeedUpgradeType;
import us.zoom.sdk.ShareSettingType;
import us.zoom.sdk.IRequestLocalRecordingPrivilegeHandler;
import us.zoom.sdk.LocalRecordingRequestPrivilegeStatus;

import us.zoom.sdk.SharingStatus;
import us.zoom.sdk.MeetingStatus;
import us.zoom.sdk.MeetingError;
import us.zoom.sdk.MeetingService;
import us.zoom.sdk.InMeetingService;
import us.zoom.sdk.MeetingServiceListener;

import us.zoom.sdk.MobileRTCSDKError;

import us.zoom.sdk.StartMeetingOptions;
import us.zoom.sdk.StartMeetingParamsWithoutLogin;

import us.zoom.sdk.JoinMeetingOptions;
import us.zoom.sdk.MeetingOptions;
import us.zoom.sdk.MeetingViewsOptions;
import us.zoom.sdk.JoinMeetingParam4WithoutLogin;


import us.zoom.sdk.VideoQuality;
import us.zoom.sdk.ChatMessageDeleteType;
import us.zoom.sdk.InMeetingChatController;
import us.zoom.sdk.MobileRTCFocusModeShareType;
import us.zoom.sdk.ZoomSDKSharingSourceInfo;
import us.zoom.sdk.ZoomUIService;

// Please note that SDK initialization and all API call must run in Main Thread.
// See https://marketplace.zoom.us/docs/sdk/native-sdks/android/mastering-zoom-sdk/sdk-initialization/
public class RNZoomUsModule extends ReactContextBaseJavaModule implements ZoomSDKInitializeListener, InMeetingServiceListener, MeetingServiceListener, InMeetingShareController.InMeetingShareListener, LifecycleEventListener, InMeetingBOControllerListener {

    private final static String TAG = "RNZoomUs";
    private final static int SCREEN_SHARE_REQUEST_CODE = 99;
    private final ReactApplicationContext reactContext;

    private Boolean shouldAutoConnectAudio;
    private Promise initializePromise;
    private Promise meetingPromise;
    private InMeetingBOController mInMeetingBOController;

    private Boolean shouldDisablePreview = false;
    private Boolean customizedMeetingUIEnabled = false;
    private Boolean disableClearWebKitCache = false;

    private Boolean meetingShareHidden = false;
    private Boolean meetingVideoHidden = false;
    private Boolean meetingAudioHidden = false;
    private Boolean closeCaptionHidden = false;
    private Boolean disableCloudWhiteboard = false;
    private Boolean meetingMoreHidden = false;

    private static final int MAX_RETRY = 5;
    private int retryCount = 0;
    MobileRTCShareView shareView = new MobileRTCShareView(getReactApplicationContext());

    private List<Integer> videoViews = Collections.synchronizedList(new ArrayList<Integer>());

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, final Intent intent) {
            if (requestCode == SCREEN_SHARE_REQUEST_CODE && resultCode == Activity.RESULT_OK) {
                UiThreadUtil.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            startZoomScreenShare(intent);
                        } catch (Exception ex) {
                            Log.e(TAG, ex.getMessage());
                        }
                    }
                });
            }
        }
    };

    public RNZoomUsModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        reactContext.addLifecycleEventListener(this);
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    @Override
    public String getName() {
        return "RNZoomUs";
    }

    /**
     * Call any Zoom SDK method by name.
     *
     * `path` is the route from ZoomSDK.getInstance() to the object that owns the
     * method, dot separated and generated into src/commands/, e.g.
     * "getInMeetingService.getInMeetingWaitingRoomController". JavaScript sends
     * the route so this side needs no table of its own, and a method the SDK
     * adds later is reachable without touching native code.
     *
     * On the UI thread: most of the SDK asserts it, and the ones that do not do
     * not mind.
     */
    @ReactMethod
    public void invoke(final String path, final String method, final ReadableArray args,
                       final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Object target = RNZoomUsCommands.resolve(path);
                    Object result = RNZoomUsCommands.call(target, method, args);
                    Object marshalled = RNZoomUsCommands.marshal(result, 0);
                    if (marshalled == null) promise.resolve(null);
                    else if (marshalled instanceof Boolean) promise.resolve((Boolean) marshalled);
                    else if (marshalled instanceof Double) promise.resolve((Double) marshalled);
                    else if (marshalled instanceof String) promise.resolve((String) marshalled);
                    else if (marshalled instanceof WritableArray) promise.resolve((WritableArray) marshalled);
                    else if (marshalled instanceof WritableMap) promise.resolve((WritableMap) marshalled);
                    else promise.resolve(String.valueOf(marshalled));
                } catch (java.lang.reflect.InvocationTargetException ex) {
                    // Unwrap, or every SDK failure reads as InvocationTargetException.
                    Throwable cause = ex.getCause() == null ? ex : ex.getCause();
                    promise.reject("ERR_ZOOM_INVOKE",
                            path + "." + method + ": " + cause, cause);
                } catch (Throwable t) {
                    promise.reject("ERR_ZOOM_INVOKE", path + "." + method + ": " + t, t);
                }
            }
        });
    }

    @ReactMethod
    public void isInitialized(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    Boolean isInitialized = zoomSDK.isInitialized();
                    promise.resolve(isInitialized);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void initialize(final ReadableMap params, final ReadableMap settings, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Log.i(TAG, "initialize");

                    if (settings.hasKey("disableShowVideoPreviewWhenJoinMeeting")) {
                        shouldDisablePreview = settings.getBoolean("disableShowVideoPreviewWhenJoinMeeting");
                    }

                    if (settings.hasKey("enableCustomizedMeetingUI")) {
                        customizedMeetingUIEnabled = settings.getBoolean("enableCustomizedMeetingUI");
                    }

                    if (settings.hasKey("disableClearWebKitCache")) {
                        disableClearWebKitCache = settings.getBoolean("disableClearWebKitCache");
                    }

                    if (settings.hasKey("meetingShareHidden")) {
                        meetingShareHidden = settings.getBoolean("meetingShareHidden");
                    }

                    if (settings.hasKey("meetingVideoHidden")) {
                        meetingVideoHidden = settings.getBoolean("meetingVideoHidden");
                    }

                    if (settings.hasKey("meetingAudioHidden")) {
                        meetingAudioHidden = settings.getBoolean("meetingAudioHidden");
                    }

                    if (settings.hasKey("closeCaptionHidden")) {
                        closeCaptionHidden = settings.getBoolean("closeCaptionHidden");
                    }

                    if (settings.hasKey("disableCloudWhiteboard")) {
                        disableCloudWhiteboard = settings.getBoolean("disableCloudWhiteboard");
                    }

                    if (settings.hasKey("meetingMoreHidden")) {
                        meetingMoreHidden = settings.getBoolean("meetingMoreHidden");
                    }

                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (zoomSDK.isInitialized()) {
                        // Apply fresh settings
                        // This setting process wouldn't be working because meetingSettingsHelper is null at this time.
                        final MeetingSettingsHelper meetingSettingsHelper = ZoomSDK.getInstance().getMeetingSettingsHelper();
                        if (meetingSettingsHelper != null) {
                            meetingSettingsHelper.disableShowVideoPreviewWhenJoinMeeting(shouldDisablePreview);
                            meetingSettingsHelper.setCustomizedMeetingUIEnabled(customizedMeetingUIEnabled);
                            meetingSettingsHelper.disableClearWebKitCache(disableClearWebKitCache);
                            meetingSettingsHelper.setHideShareButtonInMeetingToolbar(meetingShareHidden);
                            meetingSettingsHelper.setClosedCaptionHidden(closeCaptionHidden);
                            meetingSettingsHelper.enableCloudWhiteboard(!disableCloudWhiteboard);
                            meetingSettingsHelper.hideCloudWhiteboardHelperCenterButton(disableCloudWhiteboard);
                            meetingSettingsHelper.hideCloudWhiteboardOpenInBrowserButton(disableCloudWhiteboard);
                        }

                        promise.resolve("Already initialize Zoom SDK successfully.");
                        return;
                    }

                    String[] parts = settings.getString("language").split("-");
                    Locale locale = parts.length == 1
                            ? new Locale(parts[0])
                            : new Locale(parts[0], parts[1]);
//                    zoomSDK.setSdkLocale(reactContext, Locale.ROOT);

                    ZoomSDKInitParams initParams = new ZoomSDKInitParams();
                    initParams.jwtToken = params.getString("jwtToken");
                    initParams.domain = params.getString("domain");
                    // initParams.enableLog = true;
                    // initParams.enableGenerateDump =true;
                    // initParams.logSize = 5;

                    // Save promise so that it can be resolved in onZoomSDKInitializeResult
                    // after zoomSDK.initialize is called
                    initializePromise = promise;
                    zoomSDK.initialize(reactContext.getCurrentActivity(), RNZoomUsModule.this, initParams);

                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                    initializePromise = null;
                }
            }
        });
    }

    @ReactMethod
    public void cleanup(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        promise.resolve("Zoom SDK is not initialized");
                        return;
                    }
                    zoomSDK.uninitialize();
                    promise.resolve("Already cleanup Zoom SDK successfully.");
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                    initializePromise = null;
                }
            }
        });
    }

    private final IBOAdminEvent iboAdminEvent = new IBOAdminEvent() {
        @Override
        public void onStartBOResponse(boolean bSuccess) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("bSuccess", bSuccess);
        emitZoomEvent("onStartBOResponse", __p);
    }

        @Override
        public void onStopBOResponse(boolean bSuccess) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("bSuccess", bSuccess);
        emitZoomEvent("onStopBOResponse", __p);
    }

        @Override
        public void onHelpRequestReceived(String strUserID) {
        WritableMap __p = Arguments.createMap();
        __p.putString("strUserID", strUserID);
        emitZoomEvent("onHelpRequestReceived", __p);
    }

        @Override
        public void onStartBOError(BOControllerError error) {
            String errorInfo = getStartBOErrorName(error);
            sendEvent("onStartBOError", errorInfo);
        }

        @Override
        public void onBOEndTimerUpdated(int remaining, boolean isTimesUpNotice) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("remaining", (double) remaining);
        __p.putBoolean("isTimesUpNotice", isTimesUpNotice);
        emitZoomEvent("onBOEndTimerUpdated", __p);
    }

        private String getStartBOErrorName(final BOControllerError errorCode) {
            return switch (errorCode) {
                case BOControllerError_BO_LIST_IS_UPLOADING -> "BO_LIST_IS_UPLOADING";
                case BOControllerError_NO_PRIVILEGE -> "NO_PRIVILEGE";
                case BOControllerError_NO_ONE_HAS_BEEN_ASSIGNED ->
                        "NO_ONE_HAS_BEEN_ASSIGNED"; // Android only
                case BOControllerError_NULL_POINTER -> "NULL_POINTER"; // Android only
                case BOControllerError_UNKNOWN -> "UNKNOWN"; // Android only
                case BOControllerError_TOKEN_NOT_READY -> "TOKEN_NOT_READY"; // Android only
                case BOControllerError_UPLOAD_FAIL -> "UPLOAD_FAIL"; // Android only
                case BOControllerError_WRONG_CURRENT_STATUS ->
                        "WRONG_CURRENT_STATUS"; // Android only
                default -> "UNKNOWN";
            };
        }
    };

    @ReactMethod
    public void addVideoView(final double tagId, final Promise promise) {
        try {
            videoViews.add(Integer.valueOf((int) tagId));
            promise.resolve(null);
        } catch (Exception ex) {
            promise.reject("ERR_ZOOM_VIDEO_VIEW", ex.toString());
        }
    }

    @ReactMethod
    public void removeVideoView(final double tagId, final Promise promise) {
        try {
            videoViews.remove(Integer.valueOf((int) tagId));
            promise.resolve(null);
        } catch (Exception ex) {
            promise.reject("ERR_ZOOM_VIDEO_VIEW", ex.toString());
        }
    }

    @ReactMethod
    public void startMeeting(
            final ReadableMap paramMap,
            final Promise promise
    ) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_START", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final String meetingNo = paramMap.getString("meetingNumber");
                    final MeetingService meetingService = zoomSDK.getMeetingService();
                    if (meetingService.getMeetingStatus() != MeetingStatus.MEETING_STATUS_IDLE) {
                        long lMeetingNo = 0;
                        try {
                            lMeetingNo = Long.parseLong(meetingNo);
                        } catch (NumberFormatException e) {
                            promise.reject("ERR_ZOOM_START", "Invalid meeting number: " + meetingNo);
                            return;
                        }

                        if (meetingService.getCurrentRtcMeetingNumber() == lMeetingNo) {
                            meetingService.returnToMeeting(reactContext.getCurrentActivity());
                            promise.resolve("Already joined zoom meeting");
                            return;
                        }
                    }

                    StartMeetingOptions opts = new StartMeetingOptions();

                    if (paramMap.hasKey("noInvite"))
                        opts.no_invite = paramMap.getBoolean("noInvite");
                    if (paramMap.hasKey("noShare")) opts.no_share = paramMap.getBoolean("noShare");
                    if (paramMap.hasKey("noMeetingErrorMessage"))
                        opts.no_meeting_error_message = paramMap.getBoolean("noMeetingErrorMessage");

                    if (paramMap.hasKey("noButtonLeave") && paramMap.getBoolean("noButtonLeave"))
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_BUTTON_LEAVE;
                    if ((paramMap.hasKey("noButtonMore") && paramMap.getBoolean("noButtonMore")) || meetingMoreHidden)
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_BUTTON_MORE;
                    if (paramMap.hasKey("noButtonParticipants") && paramMap.getBoolean("noButtonParticipants"))
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_BUTTON_PARTICIPANTS;
                    if (paramMap.hasKey("noButtonShare") && paramMap.getBoolean("noButtonShare"))
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_BUTTON_SHARE;
                    if (paramMap.hasKey("noTextMeetingId") && paramMap.getBoolean("noTextMeetingId"))
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_TEXT_MEETING_ID;
                    if (paramMap.hasKey("noTextPassword") && paramMap.getBoolean("noTextPassword"))
                        opts.meeting_views_options = opts.meeting_views_options + MeetingViewsOptions.NO_TEXT_PASSWORD;
                    StartMeetingParamsWithoutLogin params = new StartMeetingParamsWithoutLogin();
                    params.displayName = paramMap.getString("userName");
                    params.meetingNo = paramMap.getString("meetingNumber");
                    params.userType = paramMap.getInt("userType");
                    params.zoomAccessToken = paramMap.getString("zoomAccessToken");

                    // Save promise so that it can be resolved in onMeetingStatusChanged
                    // after zoomSDK.startMeetingWithParams is called
                    meetingPromise = promise;
                    int startMeetingResult = meetingService.startMeetingWithParams(reactContext.getCurrentActivity(), params, opts);
                    Log.i(TAG, "startMeeting, startMeetingResult=" + startMeetingResult);

                    if (startMeetingResult != MeetingError.MEETING_ERROR_SUCCESS) {
                        // We are resolving promise: (1) right away and (2) in onMeetingStatusChanged because in case of no success onMeetingStatusChanged will not be triggered
                        // It is not clear from docs (https://marketplace.zoom.us/docs/sdk/native-sdks/android/mastering-zoom-sdk/start-join-meeting/api-user/start-meeting)
                        meetingPromise.reject("ERR_ZOOM_START", "startMeeting, errorCode=" + startMeetingResult);
                        meetingPromise = null;
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                    meetingPromise = null;
                }
            }
        });
    }

    @ReactMethod
    public void joinMeeting(
            final ReadableMap paramMap,
            final Promise promise
    ) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_JOIN", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final MeetingService meetingService = zoomSDK.getMeetingService();

                    IBOAdmin iboAdmin = ZoomSDK.getInstance().getInMeetingService().getInMeetingBOController().getBOAdminHelper();
                    if (iboAdmin != null)
                        iboAdmin.setEvent(iboAdminEvent);

                    JoinMeetingOptions opts = new JoinMeetingOptions();
                    MeetingViewsOptions view = new MeetingViewsOptions();
                    if (paramMap.hasKey("noAudio")) opts.no_audio = paramMap.getBoolean("noAudio");
                    /**
                     participant_id was removed from android options.
                     There is no propper documentations and it still exists in jave docs...
                     Maybe it was renamed to customer_key or so on. (todo check)
                     Waiting before further changes.
                     */
//          if(paramMap.hasKey("participantID")) opts.participant_id = paramMap.getString("participantID");

                    if (paramMap.hasKey("noVideo")) opts.no_video = paramMap.getBoolean("noVideo");
                    if (paramMap.hasKey("noInvite"))
                        opts.no_invite = paramMap.getBoolean("noInvite");
                    if (paramMap.hasKey("noBottomToolbar"))
                        opts.no_bottom_toolbar = paramMap.getBoolean("noBottomToolbar");
                    if (paramMap.hasKey("noPhoneDialIn"))
                        opts.no_dial_in_via_phone = paramMap.getBoolean("noPhoneDialIn");
                    if (paramMap.hasKey("noPhoneDialOut"))
                        opts.no_dial_out_to_phone = paramMap.getBoolean("noPhoneDialOut");
                    if (paramMap.hasKey("noMeetingEndMessage"))
                        opts.no_meeting_end_message = paramMap.getBoolean("noMeetingEndMessage");
                    if (paramMap.hasKey("noMeetingErrorMessage"))
                        opts.no_meeting_error_message = paramMap.getBoolean("noMeetingErrorMessage");
                    if (paramMap.hasKey("noShare")) opts.no_share = paramMap.getBoolean("noShare");
                    if (paramMap.hasKey("noTitlebar"))
                        opts.no_titlebar = paramMap.getBoolean("noTitlebar");
                    if (paramMap.hasKey("customMeetingId"))
                        opts.custom_meeting_id = paramMap.getString("customMeetingId");
                    if (paramMap.hasKey("noDrivingMode"))
                        opts.no_driving_mode = paramMap.getBoolean("noDrivingMode");
                    if (paramMap.hasKey("noDisconnectAudio"))
                        opts.no_disconnect_audio = paramMap.getBoolean("noDisconnectAudio");
                    if (paramMap.hasKey("noRecord"))
                        opts.no_record = paramMap.getBoolean("noRecord");
                    if (paramMap.hasKey("noUnmuteConfirmDialog"))
                        opts.no_unmute_confirm_dialog = paramMap.getBoolean("noUnmuteConfirmDialog");
                    if (paramMap.hasKey("noWebinarRegisterDialog"))
                        opts.no_webinar_register_dialog = paramMap.getBoolean("noWebinarRegisterDialog");
                    if (paramMap.hasKey("noChatMsgToast"))
                        opts.no_chat_msg_toast = paramMap.getBoolean("noChatMsgToast");
                    if (paramMap.hasKey("noMeetingErrorMessage"))
                        opts.no_meeting_error_message = paramMap.getBoolean("noMeetingErrorMessage");

                    /** TODO: posible extra options:
                     opts.meeting_views_options = meetingOptions.meeting_views_options;
                     opts.invite_options = meetingOptions.invite_options;
                     opts.customer_key = meetingOptions.customer_key;
                     */

                    if (paramMap.hasKey("noButtonLeave") && paramMap.getBoolean("noButtonLeave"))
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_LEAVE;
                    if ((paramMap.hasKey("noButtonMore") && paramMap.getBoolean("noButtonMore")) || meetingMoreHidden)
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_MORE;
                    if (paramMap.hasKey("noButtonParticipants") && paramMap.getBoolean("noButtonParticipants"))
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_PARTICIPANTS;
                    if (paramMap.hasKey("noButtonShare") && paramMap.getBoolean("noButtonShare"))
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_SHARE;
                    if (paramMap.hasKey("noTextMeetingId") && paramMap.getBoolean("noTextMeetingId"))
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_TEXT_MEETING_ID;
                    if (paramMap.hasKey("noTextPassword") && paramMap.getBoolean("noTextPassword"))
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_TEXT_PASSWORD;
                    if (meetingVideoHidden)
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_VIDEO;
                    if (meetingAudioHidden)
                        opts.meeting_views_options = opts.meeting_views_options + view.NO_BUTTON_AUDIO;

                    JoinMeetingParam4WithoutLogin params = new JoinMeetingParam4WithoutLogin();
                    params.displayName = paramMap.getString("userName");
                    params.meetingNo = paramMap.getString("meetingNumber");
                    if (paramMap.hasKey("password"))
                        params.password = paramMap.getString("password");
                    if (paramMap.hasKey("webinarToken"))
                        params.webinarToken = paramMap.getString("webinarToken");
                    if (paramMap.hasKey("zoomAccessToken"))
                        params.zoomAccessToken = paramMap.getString("zoomAccessToken");

                    // Save promise and shouldAutoConnectAudio so that it can be resolved in onMeetingStatusChanged
                    // after zoomSDK.joinMeetingWithParams is called
                    meetingPromise = promise;
                    shouldAutoConnectAudio = paramMap.getBoolean("autoConnectAudio");
                    int joinMeetingResult = meetingService.joinMeetingWithParams(reactContext.getCurrentActivity(), params, opts);
                    Log.i(TAG, "joinMeeting, joinMeetingResult=" + joinMeetingResult);

                    if (joinMeetingResult != MeetingError.MEETING_ERROR_SUCCESS) {
                        // We are resolving promise: (1) right away and (2) in onMeetingStatusChanged because in case of no success onMeetingStatusChanged will not be triggered
                        // It is not clear from docs (https://marketplace.zoom.us/docs/sdk/native-sdks/android/mastering-zoom-sdk/start-join-meeting/join-meeting)
                        meetingPromise.reject("ERR_ZOOM_JOIN", "joinMeeting, errorCode=" + joinMeetingResult);
                        meetingPromise = null;
                        shouldAutoConnectAudio = null;
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                    meetingPromise = null;
                    shouldAutoConnectAudio = null;
                }
            }
        });
    }

    @ReactMethod
    public void leaveMeeting(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(null);
                        return;
                    }

                    zoomSDK.getMeetingService().leaveCurrentMeeting(false);
                    promise.resolve(null);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void connectAudio(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    connectAudioWithVoIP();
                    promise.resolve(null);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void isMeetingConnected(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(false);
                        return;
                    }

                    promise.resolve(zoomSDK.getInMeetingService().isMeetingConnected());
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void isMeetingHost(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    promise.resolve(zoomSDK.getInMeetingService().isMeetingHost());
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void getInMeetingUserIdList(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final WritableArray rnUserList = Arguments.createArray();
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(rnUserList);
                        return;
                    }


                    List<?> userListRaw = zoomSDK.getInMeetingService().getInMeetingUserList();
                    if (userListRaw != null) {
                        for (Object userIdObj : userListRaw) {
                            if (userIdObj instanceof Long) {
                                rnUserList.pushString(String.valueOf(userIdObj));
                            } else {
                                rnUserList.pushString(userIdObj.toString());
                            }
                        }
                    }

                    promise.resolve(rnUserList);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION getInMeetingUserIdList", ex);
                }
            }
        });
    }

    @ReactMethod
    public void muteMyVideo(final boolean muted, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingVideoController videoController = zoomSDK.getInMeetingService().getInMeetingVideoController();

                    MobileRTCSDKError result = videoController.muteMyVideo(muted);

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Mute my video error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void rotateMyVideo(final double rotation, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingVideoController videoController = zoomSDK.getInMeetingService().getInMeetingVideoController();

                    if (videoController.rotateMyVideo((int) rotation)) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Error: Rotate video failed");
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void muteMyAudio(final boolean muted, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingAudioController audioController = zoomSDK.getInMeetingService().getInMeetingAudioController();

                    MobileRTCSDKError result = audioController.muteMyAudio(muted);

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Mute my audio error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void muteAttendee(final String userId, final boolean muted, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingAudioController audioController = zoomSDK.getInMeetingService().getInMeetingAudioController();

                    MobileRTCSDKError result = audioController.muteAttendeeAudio(muted, Long.parseLong(userId));

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Mute attendee audio error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void muteAllAttendee(final boolean allowUnmuteSelf, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingAudioController audioController = zoomSDK.getInMeetingService().getInMeetingAudioController();

                    MobileRTCSDKError result = audioController.muteAllAttendeeAudio(allowUnmuteSelf);

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Mute all error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void startShareScreen(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    if (customizedMeetingUIEnabled) {
                        final MediaProjectionManager manager =
                                (MediaProjectionManager) reactContext.getCurrentActivity().getSystemService(Context.MEDIA_PROJECTION_SERVICE);

                        if (manager != null) {
                            Intent intent = manager.createScreenCaptureIntent();

                            reactContext.getCurrentActivity().startActivityForResult(intent, SCREEN_SHARE_REQUEST_CODE);
                        }

                        promise.resolve(null);
                    } else {
                        final InMeetingShareController shareController = zoomSDK.getInMeetingService().getInMeetingShareController();

                        MobileRTCSDKError result = shareController.startShareViewContent(shareView);

                        if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                            promise.resolve(null);
                        } else {
                            promise.reject("ERR_ZOOM_MEETING_CONTROL", "Start share screen error, status: " + result.name());
                        }
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    private void startZoomScreenShare(final Intent intent) {
        final ZoomSDK zoomSDK = ZoomSDK.getInstance();
        final InMeetingShareController shareController = zoomSDK.getInMeetingService().getInMeetingShareController();

        MobileRTCSDKError result = shareController.startShareScreen(intent);

        if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
            sendEvent("MeetingEvent", "screenShareSuccess");
        } else {
            sendEvent("MeetingEvent", "screenShareError", result);
        }
    }

    @ReactMethod
    public void stopShareScreen(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingShareController shareController = zoomSDK.getInMeetingService().getInMeetingShareController();

                    MobileRTCSDKError result = shareController.stopShareScreen();

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Stop share screen error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void switchCamera(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingVideoController videoController = zoomSDK.getInMeetingService().getInMeetingVideoController();

                    if (!videoController.isMyVideoMuted()) {
                        if (videoController.switchToNextCamera()) {
                            updateVideoView();
                            promise.resolve(null);
                        } else {
                            promise.reject("ERR_ZOOM_MEETING_CONTROL", "Switch camera failed");
                        }
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "The camera is muted");
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void raiseMyHand(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    MobileRTCSDKError result = zoomSDK.getInMeetingService().raiseMyHand();

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Raise hand error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void lowerMyHand(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "ZoomSDK has not been initialized successfully");
                        return;
                    }

                    final InMeetingService inMeetingService = zoomSDK.getInMeetingService();

                    MobileRTCSDKError result = inMeetingService.lowerHand(inMeetingService.getMyUserID());

                    if (result == MobileRTCSDKError.SDKERR_SUCCESS) {
                        promise.resolve(null);
                    } else {
                        promise.reject("ERR_ZOOM_MEETING_CONTROL", "Lower hand error, status: " + result.name());
                    }
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void addListener(String eventName) {
        // Keep: Required for RN built in Event Emitter Calls.
    }

    @ReactMethod
    public void removeListeners(double count) {
        // Keep: Required for RN built in Event Emitter Calls.
    }

    @ReactMethod
    public void sendChatMsg(final ReadableMap msgData, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        return;
                    }
                    InMeetingChatController inMeetingChatController = zoomSDK.getInMeetingService().getInMeetingChatController();
                    if (inMeetingChatController != null) {
                        ChatMessageBuilder chatMessageBuilder = new ChatMessageBuilder();

                        Handler handler = new Handler(Looper.getMainLooper());

                        String content;
                        int receiverId;
                        int chatTypeValue;
                        int hostId = 0;
                        String messageToHost = "";
                        String previousChatId = "";

                        content = msgData.getString("content");
                        receiverId = msgData.getInt("receiverId");
                        chatTypeValue = msgData.getInt("chatMessageType");
                        if (msgData.hasKey("hostId")) {
                            hostId = msgData.getType("hostId").name().equals("String") ? Integer.parseInt(msgData.getString("hostId")) : msgData.getInt("hostId");
                        }
                        if (msgData.hasKey("messageToHost")) {
                            messageToHost = msgData.getString("messageToHost");
                        }
                        if (msgData.hasKey("previousChatId")) {
                            previousChatId = msgData.getString("previousChatId");
                        }
                        ZoomSDKChatMessageType chatMessageType;
                        switch (chatTypeValue) {
                            case 0:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_None;
                                break;
                            case 1:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_All;
                                break;
                            case 2:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_All_Panelist;
                                break;
                            case 3:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_Individual_Panelist;
                                break;
                            case 4:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_Individual;
                                break;
                            case 5:
                                chatMessageType = ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_WaitingRoomUsers;
                                break;
                            default:
                                promise.reject("ERR_INVALID_CHAT_TYPE", "Invalid chat message type: " + chatTypeValue);
                                return;
                        }
                        chatMessageBuilder.setContent(content);
                        chatMessageBuilder.setReceiver(receiverId);
                        chatMessageBuilder.setMessageType(chatMessageType);
                        InMeetingChatMessage inMeetingChatMessage = chatMessageBuilder.build();
                        inMeetingChatController.sendChatMsgTo(inMeetingChatMessage);
                        if (!messageToHost.isEmpty() && hostId != 0 && !previousChatId.isEmpty()) {
                            inMeetingChatController.deleteChatMessage(previousChatId);
                            Thread.sleep(2000);
                            chatMessageBuilder.setContent(messageToHost);
                            chatMessageBuilder.setReceiver(hostId);
                            chatMessageBuilder.setMessageType(ZoomSDKChatMessageType.ZoomSDKChatMessageType_To_Individual);
                            Thread.sleep(2000);
                            inMeetingChatController.sendChatMsgTo(inMeetingChatMessage);
                        }
                    }
                    promise.resolve(true);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void deleteChatMessage(final String msgId, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(false);
                        return;
                    }
                    InMeetingChatController inMeetingChatController = zoomSDK.getInMeetingService().getInMeetingChatController();
                    if (inMeetingChatController != null) {
                        inMeetingChatController.deleteChatMessage(msgId);
                    }
                    promise.resolve(true);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void isHostUser(final double userId, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    InMeetingService inMeetingService = ZoomSDK.getInstance().getInMeetingService();
                    if (inMeetingService != null) {
                        promise.resolve(inMeetingService.isHostUser((long) userId));
                        return;
                    }
                    promise.resolve(false);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void getMyselfUserID(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    InMeetingService inMeetingService = ZoomSDK.getInstance().getInMeetingService();
                    if (inMeetingService != null) {
                        long userIdLong = inMeetingService.getMyUserID();
                        if (userIdLong >= Integer.MIN_VALUE && userIdLong <= Integer.MAX_VALUE) {
                            int userIdInt = (int) userIdLong;
                            promise.resolve(userIdInt);
                        } else {
                            promise.reject("ERR_USER_ID_OVERFLOW", "User ID is too large to convert to int.");
                        }
                    }
                    promise.resolve(null);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    // Internal user list update trigger
    private void updateVideoView() {
        runUpdateVideoView(false);
    }

    private void runUpdateVideoView(boolean isRetry) {
        synchronized (videoViews) {
            // Nothing is showing video, so there is nothing to refresh. Worth
            // checking first: this runs on every meeting status change, and the
            // lookup below is expensive to get wrong.
            if (videoViews.isEmpty()) return;
        }

        // The New Architecture has no UIManagerModule. Asking for it there does
        // not just return null, it reports a ReactNoCrashBridgeNotAllowedSoftException
        // every time, and retrying cannot help because it will never appear.
        if (reactContext.isBridgeless()) {
            UiThreadUtil.runOnUiThread(RNZoomUsVideoView::updateAll);
            return;
        }

        final UIManagerModule uiManager = reactContext.getNativeModule(UIManagerModule.class);

        if (uiManager == null) {
            if (retryCount < MAX_RETRY) {
                retryCount++;
                Log.w(TAG, "UIManagerModule is null, retry " + retryCount);
                new android.os.Handler(Looper.getMainLooper())
                        .postDelayed(() -> runUpdateVideoView(true), 300); // retry sau 300ms
            } else {
                Log.e(TAG, "UIManagerModule is still null after " + MAX_RETRY + " retries");
            }
            return;
        }

        retryCount = 0; // reset nếu thành công

        uiManager.addUIBlock(nativeViewHierarchyManager -> {
            synchronized (videoViews) {
                Log.i(TAG, "updateVideoView");
                Iterator<Integer> iterator = videoViews.iterator();
                while (iterator.hasNext()) {
                    final int tagId = iterator.next();
                    try {
                        final RNZoomUsVideoView view =
                                (RNZoomUsVideoView) nativeViewHierarchyManager.resolveView(tagId);
                        if (view != null) view.update();
                    } catch (Exception ex) {
                        Log.e(TAG, "Error updating video view", ex);
                    }
                }
            }
        });
    }

    @Override
    public void onZoomSDKInitializeResult(int errorCode, int internalErrorCode) {
        Log.i(TAG, "onZoomSDKInitializeResult, errorCode=" + errorCode + ", internalErrorCode=" + internalErrorCode);
        String errorInfo = getAuthErrorName(errorCode);
        sendEvent("AuthEvent", errorInfo);
        if (errorCode != ZoomError.ZOOM_ERROR_SUCCESS) {
            String errorFormatted = String.format("Error= %d (%s)", errorCode, errorInfo);
            initializePromise.reject(
                    "ERR_ZOOM_INITIALIZATION",
                    errorFormatted + ", internalErrorCode=" + internalErrorCode
            );
            initializePromise = null;
        } else {
            registerListener();
            initializePromise.resolve("Initialize Zoom SDK successfully.");
            initializePromise = null;
            // This might be the right spot for setMeetingSettings process
            final MeetingSettingsHelper meetingSettingsHelper = ZoomSDK.getInstance().getMeetingSettingsHelper();
            final ZoomUIService zoomUIServiceHelper = ZoomSDK.getInstance().getZoomUIService();
//      final MeetingViewsOptions
            if (meetingSettingsHelper != null) {
                meetingSettingsHelper.disableShowVideoPreviewWhenJoinMeeting(shouldDisablePreview);
                meetingSettingsHelper.setCustomizedMeetingUIEnabled(customizedMeetingUIEnabled);
                meetingSettingsHelper.disableClearWebKitCache(disableClearWebKitCache);
                meetingSettingsHelper.disableCopyMeetingUrl(true);
                meetingSettingsHelper.enable720p(true);
                meetingSettingsHelper.enableCloudWhiteboard(!disableCloudWhiteboard);
            }
            if (zoomUIServiceHelper != null) {
                zoomUIServiceHelper.hideMeetingInviteUrl(true);
            }
        }
    }

    @Override
    public void onZoomAuthIdentityExpired() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onZoomAuthIdentityExpired", __p);
    }

    // MeetingServiceListener
    @Override
    public void onMeetingStatusChanged(MeetingStatus meetingStatus, int errorCode, int internalErrorCode) {
        Log.i(TAG, "onMeetingStatusChanged, meetingStatus=" + meetingStatus + ", errorCode=" + errorCode + ", internalErrorCode=" + internalErrorCode);

        updateVideoView();

        sendEvent("MeetingEvent", getMeetErrorName(errorCode), meetingStatus);
        sendEvent("MeetingStatus", nameOf(meetingStatus));

        if (meetingPromise == null) {
            Log.i(TAG, "onMeetingStatusChanged, does not have meetingPromise");
            return;
        }

        if (meetingStatus == MeetingStatus.MEETING_STATUS_FAILED) {
            meetingPromise.reject(
                    "ERR_ZOOM_MEETING",
                    "Error: " + errorCode + ", internalErrorCode=" + internalErrorCode
            );
            meetingPromise = null;

            shouldAutoConnectAudio = null;
        } else if (meetingStatus == MeetingStatus.MEETING_STATUS_INMEETING) {
            meetingPromise.resolve("Connected to zoom meeting");
            meetingPromise = null;

            if (shouldAutoConnectAudio != null && shouldAutoConnectAudio == true) {
                connectAudioWithVoIP();
            }
            shouldAutoConnectAudio = null;
        }
    }

    private void connectAudioWithVoIP() {
        final ZoomSDK zoomSDK = ZoomSDK.getInstance();

        if (!zoomSDK.isInitialized()) {
            return;
        }

        final InMeetingAudioController audioController = zoomSDK.getInMeetingService().getInMeetingAudioController();
        audioController.connectAudioWithVoIP();
    }

    private void registerListener() {
        Log.i(TAG, "registerListener");
        ZoomSDK zoomSDK = ZoomSDK.getInstance();
        MeetingService meetingService = zoomSDK.getMeetingService();
        if (meetingService != null) {
            Log.i(TAG, "registerListener, added listener for meetingService");
            meetingService.addListener(this);
        }
        InMeetingService inMeetingService = zoomSDK.getInMeetingService();
        if (inMeetingService != null) {
            Log.i(TAG, "registerListener, added listener for inMeetingService");
            inMeetingService.addListener(this);
            InMeetingShareController inMeetingShareController = inMeetingService.getInMeetingShareController();
            InMeetingBOController inMeetingBOController = inMeetingService.getInMeetingBOController();
            if (inMeetingShareController != null) {
                Log.i(TAG, "registerListener, added listener for getInMeetingShareController");
                inMeetingShareController.addListener(this);
            }
            if (inMeetingBOController != null) {
                Log.i(TAG, "registerListener, added listener for getInMeetingBOController");
                inMeetingBOController.addListener(this);
                mInMeetingBOController = inMeetingBOController;
            }
        }
    }

    private void unregisterListener() {
        Log.i(TAG, "unregisterListener");
        ZoomSDK zoomSDK = ZoomSDK.getInstance();
        if (zoomSDK.isInitialized()) {
            final MeetingService meetingService = zoomSDK.getMeetingService();
            if (meetingService != null) {
                Log.i(TAG, "unregisterListener, removed listener from meetingService");
                meetingService.removeListener(this);
            }
            final InMeetingService inMeetingService = zoomSDK.getInMeetingService();
            if (inMeetingService != null) {
                Log.i(TAG, "unregisterListener, removed listener from inMeetingService");
                inMeetingService.removeListener(this);
                final InMeetingShareController inMeetingShareController = inMeetingService.getInMeetingShareController();
                if (inMeetingShareController != null) {
                    Log.i(TAG, "unregisterListener, removed listener from inMeetingShareController");
                    inMeetingShareController.removeListener(this);
                }
            }
        }
    }

    public int getInMeetingUserCount() {
        final ZoomSDK zoomSDK = ZoomSDK.getInstance();

        if (!zoomSDK.isInitialized()) {
            return 0;
        }

        final int inMeetingUserCount = zoomSDK.getInMeetingService().getInMeetingUserCount();
        sendEvent("MeetingEvent", "inMeetingUserCount", inMeetingUserCount);
        return inMeetingUserCount;
    }

    // InMeetingServiceListener required listeners
    @Override
    public void onMeetingLeaveComplete(long ret) {
        updateVideoView();
        sendEvent("MeetingEvent", getMeetingEndReasonName((int) ret));
    }

    @Override
    public void onMeetingUserJoin(List<Long> userIdList) {
        updateVideoView();
        sendEvent("MeetingEvent", "userJoin", userIdList);
        getInMeetingUserCount();
    }

    @Override
    public void onMeetingUserLeave(List<Long> userIdList) {
        updateVideoView();
        sendEvent("MeetingEvent", "userLeave", userIdList);
        getInMeetingUserCount();
    }

    @Override
    public void onHostAskUnMute(long userId) {
        sendEvent("MeetingEvent", "askUnMuteAudio");
    }

    @Override
    public void onHostAskStartVideo(long userId) {
        sendEvent("MeetingEvent", "askUnMuteVideo");
    }

    @Override
    public void onMeetingHostChanged(long userId) {
        sendEvent("MeetingEvent", "hostChanged", userId);
    }

    @Deprecated
    public void onMeetingCoHostChanged(long userId) {
    }

    @Override
    public void onMeetingCoHostChange(long userId, boolean isCoHost) {
        sendEvent("MeetingEvent", "coHostChanged", userId);
    }

    @Override
    public void onMyAudioSourceTypeChanged(int type) {
        ZoomSDK zoomSDK = ZoomSDK.getInstance();
        if (!zoomSDK.isInitialized()) {
            return;
        }
        final InMeetingUserInfo userInfo = ZoomSDK.getInstance().getInMeetingService().getMyUserInfo();

        sendEvent("MeetingEvent", "myAudioSourceTypeChanged", userInfo);
    }

    @Override
    public void onUserAudioStatusChanged(long userId, AudioStatus audioStatus) {
        ZoomSDK zoomSDK = ZoomSDK.getInstance();
        if (!zoomSDK.isInitialized()) {
            return;
        }
        InMeetingService inMeetingService = ZoomSDK.getInstance().getInMeetingService();

        if (userId == inMeetingService.getMyUserID()) {
            final InMeetingUserInfo userInfo = inMeetingService.getMyUserInfo();

            sendEvent("MeetingEvent", "myAudioStatusChanged", userInfo);
        }
    }

    @Override
    public void onUserVideoStatusChanged(long userId, VideoStatus videoStatus) {
        ZoomSDK zoomSDK = ZoomSDK.getInstance();
        if (!zoomSDK.isInitialized()) {
            return;
        }
        InMeetingService inMeetingService = ZoomSDK.getInstance().getInMeetingService();

        if (userId == inMeetingService.getMyUserID()) {
            final InMeetingUserInfo userInfo = inMeetingService.getMyUserInfo();

            sendEvent("MeetingEvent", "myVideoStatusChanged", userInfo);
        }
    }

    // InMeetingServiceListener required listeners but unused for now
    @Override
    public void onAllowParticipantsRequestCloudRecording(boolean bAllow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("bAllow", bAllow);
        emitZoomEvent("onAllowParticipantsRequestCloudRecording", __p);
    }

    // Added in Zoom Meeting SDK 7.1.x
    @Override
    public void onMeetingNeedConfirmPreview(InMeetingPreviewHandler inMeetingPreviewHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("inMeetingPreviewHandlerPresent", inMeetingPreviewHandler != null);
        emitZoomEvent("onMeetingNeedConfirmPreview", __p);
    }

    @Override
    public void onUserNetworkStatusChanged(EnumComponentType componentType, MobileRTCNetworkQuality quality, long userId, boolean isMyself) {
        WritableMap __p = Arguments.createMap();
        __p.putString("componentType", componentType == null ? null : componentType.name());
        __p.putString("quality", quality == null ? null : quality.name());
        __p.putDouble("userId", (double) userId);
        __p.putBoolean("isMyself", isMyself);
        emitZoomEvent("onUserNetworkStatusChanged", __p);
    }

    @Override
    public void onAppSignalPanelUpdated(InMeetingAppSignalPanelHandler inMeetingAppSignalPanelHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("inMeetingAppSignalPanelHandlerPresent", inMeetingAppSignalPanelHandler != null);
        emitZoomEvent("onAppSignalPanelUpdated", __p);
    }

    @Override
    public void onSinkJoin3rdPartyTelephonyAudio(String s) {
        WritableMap __p = Arguments.createMap();
        __p.putString("s", s);
        emitZoomEvent("onSinkJoin3rdPartyTelephonyAudio", __p);
    }

    @Override
    public void onUserConfirmToStartArchive(IMeetingArchiveConfirmHandler iMeetingArchiveConfirmHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("iMeetingArchiveConfirmHandlerPresent", iMeetingArchiveConfirmHandler != null);
        emitZoomEvent("onUserConfirmToStartArchive", __p);
    }

    @Override
    public void onCameraControlRequestReceived(long l, CameraControlRequestType cameraControlRequestType, ICameraControlRequestHandler iCameraControlRequestHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        __p.putString("cameraControlRequestType", cameraControlRequestType == null ? null : cameraControlRequestType.name());
        __p.putBoolean("iCameraControlRequestHandlerPresent", iCameraControlRequestHandler != null);
        emitZoomEvent("onCameraControlRequestReceived", __p);
    }

    @Override
    public void onCameraControlRequestResult(long l, CameraControlRequestResult cameraControlRequestResult) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        __p.putString("cameraControlRequestResult", cameraControlRequestResult == null ? null : cameraControlRequestResult.name());
        emitZoomEvent("onCameraControlRequestResult", __p);
    }

    @Override
    public void onFileSendStart(ZoomSDKFileSender zoomSDKFileSender) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("zoomSDKFileSenderPresent", zoomSDKFileSender != null);
        emitZoomEvent("onFileSendStart", __p);
    }

    @Override
    public void onFileReceived(ZoomSDKFileReceiver zoomSDKFileReceiver) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("zoomSDKFileReceiverPresent", zoomSDKFileReceiver != null);
        emitZoomEvent("onFileReceived", __p);
    }

    @Override
    public void onFileTransferProgress(ZoomSDKFileTransferInfo zoomSDKFileTransferInfo) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("zoomSDKFileTransferInfoPresent", zoomSDKFileTransferInfo != null);
        emitZoomEvent("onFileTransferProgress", __p);
    }

    @Override
    public void onMuteOnEntryStatusChange(boolean b) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("b", b);
        emitZoomEvent("onMuteOnEntryStatusChange", __p);
    }

    @Override
    public void onMeetingTopicChanged(String s) {
        WritableMap __p = Arguments.createMap();
        __p.putString("s", s);
        emitZoomEvent("onMeetingTopicChanged", __p);
    }

    @Override
    public void onMeetingFullToWatchLiveStream(String s) {
        WritableMap __p = Arguments.createMap();
        __p.putString("s", s);
        emitZoomEvent("onMeetingFullToWatchLiveStream", __p);
    }

    @Override
    public void onBotAuthorizerRelationChanged(long l) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        emitZoomEvent("onBotAuthorizerRelationChanged", __p);
    }

    @Override
    public void onVirtualNameTagStatusChanged(boolean b, long l) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("b", b);
        __p.putDouble("l", (double) l);
        emitZoomEvent("onVirtualNameTagStatusChanged", __p);
    }

    @Override
    public void onVirtualNameTagRosterInfoUpdated(long l) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        emitZoomEvent("onVirtualNameTagRosterInfoUpdated", __p);
    }

    @Override
    public void onCreateCompanionRelation(long l, long l1) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        __p.putDouble("l1", (double) l1);
        emitZoomEvent("onCreateCompanionRelation", __p);
    }

    @Override
    public void onRemoveCompanionRelation(long l) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        emitZoomEvent("onRemoveCompanionRelation", __p);
    }

    @Override
    public void onUserConfirmRecoverMeeting(IRecoverMeetingHandle iRecoverMeetingHandle) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("iRecoverMeetingHandlePresent", iRecoverMeetingHandle != null);
        emitZoomEvent("onUserConfirmRecoverMeeting", __p);
    }

    @Override
    public void onUVCCameraStatusChange(String cameraId, UVCCameraStatus status) {
        WritableMap __p = Arguments.createMap();
        __p.putString("cameraId", cameraId);
        __p.putString("status", status == null ? null : status.name());
        emitZoomEvent("onUVCCameraStatusChange", __p);
    }

    @Override
    public void onVideoAlphaChannelStatusChanged(boolean isAlphaModeOn) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("isAlphaModeOn", isAlphaModeOn);
        emitZoomEvent("onVideoAlphaChannelStatusChanged", __p);
    }

    @Override
    public void onFocusModeStateChanged(boolean on) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("on", on);
        emitZoomEvent("onFocusModeStateChanged", __p);
    }

    @Override
    public void onFocusModeShareTypeChanged(MobileRTCFocusModeShareType shareType) {
        WritableMap __p = Arguments.createMap();
        __p.putString("shareType", shareType == null ? null : shareType.name());
        emitZoomEvent("onFocusModeShareTypeChanged", __p);
    }

    @Override
    public void onAICompanionActiveChangeNotice(boolean b) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("b", b);
        emitZoomEvent("onAICompanionActiveChangeNotice", __p);
    }

    @Override
    public void onParticipantProfilePictureStatusChange(boolean b) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("b", b);
        emitZoomEvent("onParticipantProfilePictureStatusChange", __p);
    }

    @Override
    public void onCloudRecordingStorageFull(long l) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        emitZoomEvent("onCloudRecordingStorageFull", __p);
    }

    @Override
    public void onInMeetingUserAvatarPathUpdated(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onInMeetingUserAvatarPathUpdated", __p);
    }

    @Override
    public void onSuspendParticipantsActivities() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onSuspendParticipantsActivities", __p);
    }

    @Override
    public void onAllowParticipantsStartVideoNotification(boolean allow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("allow", allow);
        emitZoomEvent("onAllowParticipantsStartVideoNotification", __p);
    }

    @Override
    public void onAllowParticipantsRenameNotification(boolean allow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("allow", allow);
        emitZoomEvent("onAllowParticipantsRenameNotification", __p);
    }

    @Override
    public void onAllowParticipantsUnmuteSelfNotification(boolean allow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("allow", allow);
        emitZoomEvent("onAllowParticipantsUnmuteSelfNotification", __p);
    }

    @Override
    public void onAllowParticipantsShareWhiteBoardNotification(boolean allow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("allow", allow);
        emitZoomEvent("onAllowParticipantsShareWhiteBoardNotification", __p);
    }

    @Override
    public void onMeetingLockStatus(boolean isLock) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("isLock", isLock);
        emitZoomEvent("onMeetingLockStatus", __p);
    }

    @Override
    public void onFollowHostVideoOrderChanged(boolean bFollow) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("bFollow", bFollow);
        emitZoomEvent("onFollowHostVideoOrderChanged", __p);
    }

    @Override
    public void onMeetingParameterNotification(MeetingParameter meetingParameter) {
        WritableMap __p = Arguments.createMap();
        __p.putMap("meetingParameter", toMeetingParameter(meetingParameter));
        emitZoomEvent("onMeetingParameterNotification", __p);
    }

    @Override
    public void onHostVideoOrderUpdated(List<Long> orderList) {
        WritableMap __p = Arguments.createMap();
        __p.putArray("orderList", toLongArray(orderList));
        emitZoomEvent("onHostVideoOrderUpdated", __p);
    }

    @Override
    public void onMeetingNeedPasswordOrDisplayName(boolean needPassword, boolean needDisplayName, InMeetingEventHandler handler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("needPassword", needPassword);
        __p.putBoolean("needDisplayName", needDisplayName);
        __p.putBoolean("handlerPresent", handler != null);
        emitZoomEvent("onMeetingNeedPasswordOrDisplayName", __p);
    }

    @Override
    public void onWebinarNeedRegister(String registerUrl) {
        WritableMap __p = Arguments.createMap();
        __p.putString("registerUrl", registerUrl);
        emitZoomEvent("onWebinarNeedRegister", __p);
    }

    @Override
    public void onJoinMeetingNeedUserInfo(IMeetingInputUserInfoHandler iMeetingInputUserInfoHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("iMeetingInputUserInfoHandlerPresent", iMeetingInputUserInfoHandler != null);
        emitZoomEvent("onJoinMeetingNeedUserInfo", __p);
    }

    @Override
    public void onJoinWebinarNeedUserNameAndEmail(InMeetingEventHandler handler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("handlerPresent", handler != null);
        emitZoomEvent("onJoinWebinarNeedUserNameAndEmail", __p);
    }

    @Override
    public void onWebinarNeedInputScreenName(InMeetingEventHandler inMeetingEventHandler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("inMeetingEventHandlerPresent", inMeetingEventHandler != null);
        emitZoomEvent("onWebinarNeedInputScreenName", __p);
    }

    @Override
    public void onMeetingNeedCloseOtherMeeting(InMeetingEventHandler handler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("handlerPresent", handler != null);
        emitZoomEvent("onMeetingNeedCloseOtherMeeting", __p);
    }

    @Override
    public void onMeetingFail(int errorCode, int internalErrorCode) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("errorCode", (double) errorCode);
        __p.putDouble("internalErrorCode", (double) internalErrorCode);
        emitZoomEvent("onMeetingFail", __p);
    }


    @Override
    public void onActiveVideoUserChanged(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onActiveVideoUserChanged", __p);
    }

    @Override
    public void onActiveSpeakerVideoUserChanged(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onActiveSpeakerVideoUserChanged", __p);
    }

    @Deprecated
    public void onSpotlightVideoChanged(boolean on) {
    }

    @Override
    public void onSpotlightVideoChanged(List<Long> userList) {
        WritableMap __p = Arguments.createMap();
        __p.putArray("userList", toLongArray(userList));
        emitZoomEvent("onSpotlightVideoChanged", __p);
    }

    @Override
    public void onSinkPanelistChatPrivilegeChanged(InMeetingChatController.MobileRTCWebinarPanelistChatPrivilege privilege) {
        WritableMap __p = Arguments.createMap();
        __p.putString("privilege", privilege == null ? null : privilege.name());
        emitZoomEvent("onSinkPanelistChatPrivilegeChanged", __p);
    }

    @Deprecated
    public void onUserNetworkQualityChanged(long userId) {
    }

    ;


    @Override
    public void onMicrophoneStatusError(InMeetingAudioController.MobileRTCMicrophoneError error) {
        WritableMap __p = Arguments.createMap();
        __p.putString("error", error == null ? null : error.name());
        emitZoomEvent("onMicrophoneStatusError", __p);
    }

    @Override
    public void onUserAudioTypeChanged(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onUserAudioTypeChanged", __p);
    }

    @Override
    public void onLowOrRaiseHandStatusChanged(long userId, boolean isRaisedHand) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        __p.putBoolean("isRaisedHand", isRaisedHand);
        emitZoomEvent("onLowOrRaiseHandStatusChanged", __p);
    }

    @Override
    public void onChatMessageReceived(InMeetingChatMessage inMeetingChatMessage) {
        sendEventChatInfo("MeetingEvent", "onChatMessageNotification", inMeetingChatMessage);
    }

    @Override
    public void onChatMsgDeleteNotification(String msgID, ChatMessageDeleteType deleteBy) {
        if (msgID != null) {
            WritableMap params = Arguments.createMap();
            params.putString("deleteBy", nameOf(deleteBy));
            params.putString("msgID", msgID);

            WritableMap rootParams = Arguments.createMap();
            rootParams.putString("event", "onChatMsgDeleteNotification");
            rootParams.putMap("msgDelete", params);
            emitLegacy("MeetingEvent", rootParams);
        }
    }

    @Override
    public void onChatMessageEditNotification(InMeetingChatMessage inMeetingChatMessage) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("inMeetingChatMessagePresent", inMeetingChatMessage != null);
        emitZoomEvent("onChatMessageEditNotification", __p);
    }

    @Override
    public void onSilentModeChanged(boolean inSilentMode) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("inSilentMode", inSilentMode);
        emitZoomEvent("onSilentModeChanged", __p);
    }

    @Override
    public void onMeetingActiveVideo(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onMeetingActiveVideo", __p);
    }

    @Override
    public void onSinkAttendeeChatPrivilegeChanged(int i) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("i", (double) i);
        emitZoomEvent("onSinkAttendeeChatPrivilegeChanged", __p);
    }

    @Override
    public void onSinkAllowAttendeeChatNotification(int privilege) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("privilege", (double) privilege);
        emitZoomEvent("onSinkAllowAttendeeChatNotification", __p);
    }

    @Deprecated
    public void onUserNameChanged(long userId, String name) {
    }

    @Override
    public void onUserNamesChanged(List<Long> userList) {
        WritableMap __p = Arguments.createMap();
        __p.putArray("userList", toLongArray(userList));
        emitZoomEvent("onUserNamesChanged", __p);
    }

    @Override
    public void onInvalidReclaimHostkey() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onInvalidReclaimHostkey", __p);
    }

    @Override
    public void onRecordingStatus(RecordingStatus status) {
        WritableMap __p = Arguments.createMap();
        __p.putString("status", status == null ? null : status.name());
        emitZoomEvent("onRecordingStatus", __p);
    }

    @Override
    public void onLocalRecordingStatus(long userId, RecordingStatus recordingStatus) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        __p.putString("recordingStatus", recordingStatus == null ? null : recordingStatus.name());
        emitZoomEvent("onLocalRecordingStatus", __p);
    }

    @Override
    public void onClosedCaptionReceived(String message, long senderId) {
        WritableMap __p = Arguments.createMap();
        __p.putString("message", message);
        __p.putDouble("senderId", (double) senderId);
        emitZoomEvent("onClosedCaptionReceived", __p);
    }

    @Override
    public void onFreeMeetingReminder(boolean isHost, boolean canUpgrade, boolean isFirstGift) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("isHost", isHost);
        __p.putBoolean("canUpgrade", canUpgrade);
        __p.putBoolean("isFirstGift", isFirstGift);
        emitZoomEvent("onFreeMeetingReminder", __p);
    }

    @Override
    public void onFreeMeetingUpgradeToProMeeting() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onFreeMeetingUpgradeToProMeeting", __p);
    }

    @Override
    public void onFreeMeetingUpgradeToGiftFreeTrialStop() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onFreeMeetingUpgradeToGiftFreeTrialStop", __p);
    }

    @Override
    public void onFreeMeetingUpgradeToGiftFreeTrialStart() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onFreeMeetingUpgradeToGiftFreeTrialStart", __p);
    }

    @Override
    public void onFreeMeetingNeedToUpgrade(FreeMeetingNeedUpgradeType type, String gifUrl) {
        WritableMap __p = Arguments.createMap();
        __p.putString("type", type == null ? null : type.name());
        __p.putString("gifUrl", gifUrl);
        emitZoomEvent("onFreeMeetingNeedToUpgrade", __p);
    }

    @Override
    public void onLocalVideoOrderUpdated(List<Long> localOrderList) {
        WritableMap __p = Arguments.createMap();
        __p.putArray("localOrderList", toLongArray(localOrderList));
        emitZoomEvent("onLocalVideoOrderUpdated", __p);
    }

    @Override
    public void onAllHandsLowered() {
        WritableMap __p = Arguments.createMap();
        emitZoomEvent("onAllHandsLowered", __p);
    }

    @Override
    public void onPermissionRequested(String[] permissions) {
        WritableMap __p = Arguments.createMap();
        __p.putArray("permissions", toStringArray(permissions));
        emitZoomEvent("onPermissionRequested", __p);
    }

    @Override
    public void onShareMeetingChatStatusChanged(boolean start) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("start", start);
        emitZoomEvent("onShareMeetingChatStatusChanged", __p);
    }

    @Override
    public void onLocalRecordingPrivilegeRequested(IRequestLocalRecordingPrivilegeHandler handler) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("handlerPresent", handler != null);
        emitZoomEvent("onLocalRecordingPrivilegeRequested", __p);
    }

    @Override
    public void onRequestLocalRecordingPrivilegeChanged(LocalRecordingRequestPrivilegeStatus status) {
        WritableMap __p = Arguments.createMap();
        __p.putString("status", status == null ? null : status.name());
        emitZoomEvent("onRequestLocalRecordingPrivilegeChanged", __p);
    }

    // InMeetingShareListener event listeners
    // DEPRECATED: onShareActiveUser is just kept for now for backwards compatibility of events

    @Override
    public void onShareSettingTypeChanged(ShareSettingType type) {
        WritableMap __p = Arguments.createMap();
        __p.putString("type", type == null ? null : type.name());
        emitZoomEvent("onShareSettingTypeChanged", __p);
    }

    @Override
    public void onShareContentChanged(ZoomSDKSharingSourceInfo zoomSDKSharingSourceInfo) {
        final ZoomSDK zoomSDK = ZoomSDK.getInstance();
        if (!zoomSDK.isInitialized()) {
            return;
        }
        final InMeetingService inMeetingService = zoomSDK.getInMeetingService();
        if (inMeetingService == null) return;
        long userId = -1;

        if (zoomSDKSharingSourceInfo != null) {
            userId = zoomSDKSharingSourceInfo.getUserID();
        }
        if (inMeetingService.isMyself(userId)) {
            sendEvent("MeetingEvent", "screenShareStarted");
        } else if (userId == 0) {
            sendEvent("MeetingEvent", "screenShareStopped");
        }
    }

    @Override
    public void onSharingStatus(ZoomSDKSharingSourceInfo zoomSDKSharingSourceInfo) {
        updateVideoView();
        SharingStatus status = SharingStatus.Sharing_Status_None;
        long userId = -1;

        if (zoomSDKSharingSourceInfo != null) {
            if (zoomSDKSharingSourceInfo.getStatus() != null) {
                status = zoomSDKSharingSourceInfo.getStatus();
            }
            userId = zoomSDKSharingSourceInfo.getUserID();
        }

        sendEvent("MeetingEvent", getSharingStatusEventName(status), userId);

        if (status.equals(SharingStatus.Sharing_Self_Send_Begin)) {
            final InMeetingService inMeetingService = ZoomSDK.getInstance().getInMeetingService();
            final InMeetingShareController shareController = inMeetingService.getInMeetingShareController();

            if (shareController.isSharingOut()) {
                if (shareController.isSharingScreen()) {
                    shareController.startShareViewContent(shareView);
                }
            }
        }
    }

    @Override
    public void onShareUserReceivingStatus(long userId) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("userId", (double) userId);
        emitZoomEvent("onShareUserReceivingStatus", __p);
    }

    @Override
    public void onGrantCoOwnerPrivilegeChanged(boolean canGrantOther) {
        WritableMap __p = Arguments.createMap();
        __p.putBoolean("canGrantOther", canGrantOther);
        emitZoomEvent("onGrantCoOwnerPrivilegeChanged", __p);
    }

    // React LifeCycle
    @Override
    public void onHostDestroy() {
        Log.i(TAG, "onHostDestroy");
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (zoomSDK.isInitialized()) {
                        zoomSDK.getMeetingService().leaveCurrentMeeting(false);
                    }

                    unregisterListener();
                } catch (Exception ex) {
                    Log.e(TAG, ex.getMessage());
                }
            }
        });
    }

    @Override
    public void onHostPause() {
        Log.i(TAG, "onHostPause");
    }

    @Override
    public void onHostResume() {
        Log.i(TAG, "onHostResume");

        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        return;
                    }

                    final MeetingService meetingService = zoomSDK.getMeetingService();
                    List<MeetingStatus> staleMeetingStatuses = new ArrayList<>(Arrays.asList(MeetingStatus.MEETING_STATUS_IDLE, MeetingStatus.MEETING_STATUS_DISCONNECTING));
                    if (!staleMeetingStatuses.contains(meetingService.getMeetingStatus())) {
                        Log.i(TAG, "onHostResume, returning to meeting");
                        meetingService.returnToMeeting(reactContext.getCurrentActivity());
                    }

                    registerListener();
                } catch (Exception ex) {
                    Log.e(TAG, ex.getMessage());
                }
            }
        });
    }

    @Override
    public void invalidate() {
        Log.i(TAG, "onCatalystInstanceDestroy");
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (zoomSDK.isInitialized()) {
                        zoomSDK.getMeetingService().leaveCurrentMeeting(false);
                    }

                    unregisterListener();
                } catch (Exception ex) {
                    Log.e(TAG, ex.getMessage());
                }
            }
        });
    }

    // React Native event emitters and event handling
    private void sendEvent(String name, String event) {
        WritableMap params = Arguments.createMap();
        params.putString("event", event);

        emitLegacy(name, params);

        // Mirror onto the unified channel so subscribers there see every
        // callback, not just the ones without a legacy emitter.
        WritableMap mirrored = Arguments.createMap();
        mirrored.putString("channel", name);
        emitZoomEvent(event, mirrored);
    }

    private void sendEvent(String name, String event, InMeetingUserInfo userInfo) {
        if (userInfo != null) {
            WritableMap params = Arguments.createMap();
            params.putString("event", event);
            params.putString("userRole", nameOf(userInfo.getInMeetingUserRole()));

            // getAudioStatus()/getVideoStatus() are null for a participant the
            // SDK has not finished describing yet, which happens during join.
            InMeetingUserInfo.AudioStatus audio = userInfo.getAudioStatus();
            InMeetingUserInfo.VideoStatus video = userInfo.getVideoStatus();
            if (audio != null) {
                params.putDouble("audioType", audio.getAudioType());
                params.putBoolean("isTalking", audio.isTalking());
                params.putBoolean("isMutedAudio", audio.isMuted());
            }
            if (video != null) {
                params.putBoolean("isMutedVideo", !video.isSending());
            }

            emitLegacy(name, params);
        }
    }

    private void sendEventChatInfo(String name, String event, InMeetingChatMessage msg) {

        if (msg != null) {
            WritableMap params = Arguments.createMap();
            params.putString("chatId", msg.getMsgId());
            params.putString("senderId", String.valueOf(msg.getSenderUserId()));
            params.putString("senderName", msg.getSenderDisplayName());
            params.putString("receiverId", String.valueOf(msg.getReceiverUserId()));
            params.putString("receiverName", msg.getReceiverDisplayName());
            params.putString("content", msg.getContent());
            SimpleDateFormat sdf = new SimpleDateFormat("dd-MM-yyyy HH:mm:ss");
            String formattedDate = sdf.format(new Date(msg.getTime()));
            params.putString("date", formattedDate);
            if (msg.getChatMessageType() != null) {
                params.putInt("chatMessageType", msg.getChatMessageType().hashCode());
            }
            params.putBoolean("isChatToAll", msg.isChatToAll());
            params.putBoolean("isChatToWaitingroom", msg.isChatToWaitingroom());
            params.putBoolean("isChatToAllPanelist", msg.isChatToAllPanelist());
            params.putBoolean("isComment", msg.isComment());
            params.putBoolean("isThread", msg.isThread());
            params.putString("threadId", msg.getThreadId());

            WritableMap rootParams = Arguments.createMap();
            rootParams.putString("event", event);
            rootParams.putMap("chatInfo", params);

            emitLegacy(name, rootParams);
        }
    }

    private void sendEvent(String name, String event, MeetingStatus status) {
        WritableMap params = Arguments.createMap();
        params.putString("event", event);
        params.putString("status", nameOf(status));

        emitLegacy(name, params);
    }

    private void sendEvent(String name, String event, String status) {
        WritableMap params = Arguments.createMap();
        params.putString("event", event);
        params.putString("status", status);

        emitLegacy(name, params);
    }

    private void sendEvent(String name, String event, long userId) {
        WritableMap params = Arguments.createMap();
        params.putString("event", event);
        params.putDouble("userId", userId);

        emitLegacy(name, params);
    }

    private void sendEvent(String name, String event, List<Long> userList) {
        WritableMap params = Arguments.createMap();
        WritableArray users = Arguments.createArray();

        if (userList != null) {
            for (final Long userId : userList) {
                if (userId != null) users.pushString(userId.toString());
            }
        }

        params.putString("event", event);
        params.putArray("userList", users);

        emitLegacy(name, params);
    }

    private void sendEvent(String name, String event, MobileRTCSDKError error) {
        WritableMap params = Arguments.createMap();
        params.putString("event", event);
        params.putString("error", nameOf(error));

        emitLegacy(name, params);
    }

    private String getSharingStatusEventName(final SharingStatus status) {
        switch (status) {
            case Sharing_Self_Send_Begin:
                return "screenShareStartedBySelf";
            case Sharing_Self_Send_End:
                return "screenShareStoppedBySelf";
            case Sharing_Other_Share_Begin:
                return "screenShareStartedByUser";
            case Sharing_Other_Share_End:
                return "screenShareStoppedByUser";
            case Sharing_View_Other_Sharing:
                return "screenShareOtherSharing";
            case Sharing_Pause:
                return "screenSharePause";
            case Sharing_Resume:
                return "screenShareResume";
            default:
                return "screenShareStoppedByUser";
        }
    }

    private String getAuthErrorName(final int errorCode) {
        switch (errorCode) {
            case ZoomError.ZOOM_ERROR_AUTHRET_CLIENT_INCOMPATIBLE:
                return "clientIncompatible";
            case ZoomError.ZOOM_ERROR_SUCCESS:
                return "success";
            case ZoomError.ZOOM_ERROR_DEVICE_NOT_SUPPORTED:
                return "deviceNotSupported"; // Android only
            case ZoomError.ZOOM_ERROR_ILLEGAL_APP_KEY_OR_SECRET:
                return "illegalAppKeyOrSecret"; // Android only
            case ZoomError.ZOOM_ERROR_INVALID_ARGUMENTS:
                return "invalidArguments"; // Android only
            case ZoomError.ZOOM_ERROR_NETWORK_UNAVAILABLE:
                return "networkUnavailable"; // Android only
            default:
                return "unknown";
        }
    }

    private String getMeetErrorName(final int errorCode) {
        switch (errorCode) {
            case MeetingError.MEETING_ERROR_INVALID_ARGUMENTS:
                return "invalidArguments";
            case MeetingError.MEETING_ERROR_CLIENT_INCOMPATIBLE:
                return "meetingClientIncompatible";
            case MeetingError.MEETING_ERROR_LOCKED:
                return "meetingLocked";
            case MeetingError.MEETING_ERROR_MEETING_NOT_EXIST:
                return "meetingNotExist";
            case MeetingError.MEETING_ERROR_MEETING_OVER:
                return "meetingOver";
            case MeetingError.MEETING_ERROR_RESTRICTED:
                return "meetingRestricted";
            case MeetingError.MEETING_ERROR_RESTRICTED_JBH:
                return "meetingRestrictedJBH";
            case MeetingError.MEETING_ERROR_USER_FULL:
                return "meetingUserFull";
            case MeetingError.MEETING_ERROR_MMR_ERROR:
                return "mmrError";
            case MeetingError.MEETING_ERROR_NO_MMR:
                return "noMMR";
            case MeetingError.MEETING_ERROR_HOST_DENY_EMAIL_REGISTER_WEBINAR:
                return "registerWebinarDeniedEmail";
            case MeetingError.MEETING_ERROR_WEBINAR_ENFORCE_LOGIN:
                return "registerWebinarEnforceLogin";
            case MeetingError.MEETING_ERROR_REGISTER_WEBINAR_FULL:
                return "registerWebinarFull";
            case MeetingError.MEETING_ERROR_DISALLOW_HOST_REGISTER_WEBINAR:
                return "registerWebinarHostRegister";
            case MeetingError.MEETING_ERROR_DISALLOW_PANELIST_REGISTER_WEBINAR:
                return "registerWebinarPanelistRegister";
            case MeetingError.MEETING_ERROR_REMOVED_BY_HOST:
                return "removedByHost";
            case MeetingError.MEETING_ERROR_SESSION_ERROR:
                return "sessionError";
            case MeetingError.MEETING_ERROR_SUCCESS:
                return "success";
            case MeetingError.MEETING_ERROR_EXIT_WHEN_WAITING_HOST_START:
                return "exitWhenWaitingHostStart"; // Android only
            case MeetingError.MEETING_ERROR_INCORRECT_MEETING_NUMBER:
                return "incorrectMeetingNumber"; // Android only
            case MeetingError.MEETING_ERROR_INVALID_STATUS:
                return "invalidStatus"; // Android only
            case MeetingError.MEETING_ERROR_NETWORK_UNAVAILABLE:
                return "networkUnavailable"; // Android only
            case MeetingError.MEETING_ERROR_TIMEOUT:
                return "timeout"; // Android only
            case MeetingError.MEETING_ERROR_WEB_SERVICE_FAILED:
                return "webServiceFailed"; // Android only
            default:
                return "unknown";
        }
    }

    private String getMeetingEndReasonName(final int reason) {
        switch (reason) {
            case MeetingEndReason.END_BY_SELF:
                return "endedBySelf";
            case MeetingEndReason.KICK_BY_HOST:
                return "endedRemovedByHost";
            case MeetingEndReason.END_BY_HOST:
                return "endedByHost";
            case MeetingEndReason.END_FOR_JBH_TIMEOUT:
                return "endedJBHTimeout";
            case MeetingEndReason.END_FOR_FREEMEET_TIMEOUT:
                return "endedFreeMeetingTimeout";
            case MeetingEndReason.END_FOR_NO_ATEENDEE:
                return "endedNoAttendee"; // Android only
            case MeetingEndReason.END_BY_HOST_START_ANOTHERMEETING:
                return "endedByHostForAnotherMeeting";
            case MeetingEndReason.END_UNDEFINED:
                return "endedConnectBroken";
            default:
                return "endedUnknownReason";
        }
    }

    @Override
    public void onHasCreatorRightsNotification(IBOCreator iboCreator) {
        Log.i(TAG, "onHasCreatorRightsNotification");
    }

    @Override
    public void onHasAdminRightsNotification(IBOAdmin iboAdmin) {
        Log.i(TAG, "onHasAdminRightsNotification");
    }

    @Override
    public void onHasAssistantRightsNotification(IBOAssistant iboAssistant) {
        Log.i(TAG, "onHasAssistantRightsNotification");
    }

    @Override
    public void onHasAttendeeRightsNotification(IBOAttendee iboAttendee) {
        Log.i(TAG, "onHasAttendeeRightsNotification");
        String boName = iboAttendee.getBoName();
        if (boName != null && !boName.isEmpty()) {
            sendEvent("MeetingEvent", "onHasAttendeeRightsNotification", boName);
        } else {
            sendEvent("MeetingEvent", "onHasAttendeeRightsNotification", "");
        }
        iboAttendee.setEvent(new IBOAttendeeEvent() {

            public void onShareAction(SharingStatus status, IShareAction shareAction) {

            }

            @Override
            public void onHelpRequestHandleResultReceived(ATTENDEE_REQUEST_FOR_HELP_RESULT eResult) {
                Log.i(TAG, "onHelpRequestHandleResultReceived:" + eResult);
            }

            @Override
            public void onHostJoinedThisBOMeeting() {
                Log.i(TAG, "onHostJoinedThisBOMeeting:");
            }

            @Override
            public void onHostLeaveThisBOMeeting() {
                Log.i(TAG, "onHostLeaveThisBOMeeting:");
            }
        });
    }

    @Override
    public void onHasDataHelperRightsNotification(IBOData iboData) {
        Log.i(TAG, "onHasDataHelperRightsNotification");
    }

    @Override
    public void onLostCreatorRightsNotification() {
        Log.i(TAG, "onLostCreatorRightsNotification");
    }

    @Override
    public void onLostAdminRightsNotification() {
        Log.i(TAG, "onLostAdminRightsNotification");
    }

    @Override
    public void onLostAssistantRightsNotification() {
        Log.i(TAG, "onLostAssistantRightsNotification");
    }

    @Override
    public void onLostAttendeeRightsNotification() {
        Log.i(TAG, "onLostAttendeeRightsNotification");
    }

    @Override
    public void onLostDataHelperRightsNotification() {
        Log.i(TAG, "onLostDataHelperRightsNotification");
    }

    @Override
    public void onNewBroadcastMessageReceived(String message, long senderId, String senderName) {
        Log.i(TAG, "onNewBroadcastMessageReceived:" + message + " senderId:" + senderId + " senderName:" + senderName);

    }

    @Override
    public void onBOStopCountDown(int seconds) {
        Log.i(TAG, "onBOStopCountDown seconds: " + seconds);
    }

    @Override
    public void onHostInviteReturnToMainSession(String name, ReturnToMainSessionHandler returnToMainSessionHandler) {
        Log.i(TAG, "onHostInviteReturnToMainSession name: " + name);
    }

    @Override
    public void onBOStatusChanged(BOStatus boStatus) {
        Log.i(TAG, "onBOStatusChanged status: " + boStatus);
        sendEvent("MeetingEvent", "onBOStatusChanged", boStatus == BOStatus.STARTED ? "MobileRTCBOStatus_Started" : nameOf(boStatus));

    }

    @Override
    public void onBOSwitchRequestReceived(String strNewBOName, String strNewBOID) {
        Log.i(TAG, "onBOSwitchRequestReceived: boName: " + strNewBOName + ", boID: " + strNewBOID);
    }

    @Override
    public void onBroadcastBOVoiceStatus(boolean start) {
        Log.i(TAG, "onBroadcastBOVoiceStatus " + start);
    }

    @Override
    public void onBOOptionChanged(BOOption boOption) {
        Log.i(TAG, "onBOOptionChanged " + boOption);
    }

    @Override
    public void onShareFromMainSession(long l, SharingStatus sharingStatus, IShareAction iShareAction) {
        WritableMap __p = Arguments.createMap();
        __p.putDouble("l", (double) l);
        __p.putString("sharingStatus", sharingStatus == null ? null : sharingStatus.name());
        __p.putBoolean("iShareActionPresent", iShareAction != null);
        emitZoomEvent("onShareFromMainSession", __p);
    }

    @ReactMethod
    public void joinBO(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();
                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(null);
                        return;
                    }
                    InMeetingService inMeetingService = zoomSDK.getInMeetingService();
                    InMeetingBOController boController = inMeetingService.getInMeetingBOController();
                    IBOAttendee boAttendee = boController.getBOAttendeeHelper();
                    if (boAttendee == null) {
                        promise.reject("BO_UNASSIGNED", "");
                        return;
                    }
                    boolean ret = boAttendee.joinBo();
                    promise.resolve(ret);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void leaveBO(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(null);
                        return;
                    }
                    InMeetingService inMeetingService = zoomSDK.getInMeetingService();
                    InMeetingBOController boController = inMeetingService.getInMeetingBOController();
                    IBOAttendee boAttendee = boController.getBOAttendeeHelper();
                    if (boAttendee == null) {
                        return;
                    }
                    boolean ret = boAttendee.leaveBo();
                    promise.resolve(ret);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void isHostInThisBO(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(null);
                        return;
                    }
                    InMeetingService inMeetingService = zoomSDK.getInMeetingService();
                    InMeetingBOController boController = inMeetingService.getInMeetingBOController();
                    IBOAttendee boAttendee = boController.getBOAttendeeHelper();
                    if (boAttendee == null) {
                        return;
                    }
                    boolean ret = boAttendee.isHostInThisBO();
                    promise.resolve(ret);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }

    @ReactMethod
    public void requestForHelp(final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    final ZoomSDK zoomSDK = ZoomSDK.getInstance();

                    if (!zoomSDK.isInitialized()) {
                        promise.resolve(null);
                        return;
                    }
                    InMeetingService inMeetingService = zoomSDK.getInMeetingService();
                    InMeetingBOController boController = inMeetingService.getInMeetingBOController();
                    IBOAttendee boAttendee = boController.getBOAttendeeHelper();
                    if (boAttendee == null) {
                        return;
                    }
                    boolean ret = boAttendee.requestForHelp();
                    promise.resolve(ret);
                } catch (Exception ex) {
                    promise.reject("ERR_UNEXPECTED_EXCEPTION", ex);
                }
            }
        });
    }


    // ------------------------------------------------------------------
    // Unified event channel
    //
    // Every SDK listener callback is forwarded here, including ones nothing
    // consumes yet, so adding a feature later never requires a native rebuild
    // and a new library release.
    //
    // The legacy "MeetingEvent" / "MeetingStatus" / "AuthEvent" channels still
    // emit exactly as before; this is an additional stream, not a replacement.
    // ------------------------------------------------------------------
    static final String ZOOM_EVENT_CHANNEL = "ZoomUsEvent";

    /**
     * Enum name, or null when the SDK hands us nothing.
     *
     * These run inside SDK listener callbacks, on the SDK's own thread. An
     * exception there does not reach any of our try/catch -- it takes the
     * process down, and native cannot be hot-fixed the way the JS bundle can.
     * Every nullable value the SDK passes is treated as nullable.
     */
    private static String nameOf(Enum<?> value) {
        return value == null ? null : value.name();
    }

    /**
     * Emit on one of the legacy named channels. Never throws.
     *
     * getJSModule() fails once the React instance is gone -- a reload, a
     * backgrounded app being torn down -- and these are called from SDK threads
     * that keep running after it.
     */
    private void emitLegacy(String name, WritableMap params) {
        try {
            if (!reactContext.hasActiveReactInstance()) return;
            emitLegacy(name, params);
        } catch (Exception ex) {
            Log.e(TAG, "emit(" + name + ") failed", ex);
        }
    }

    private void emitZoomEvent(String event, WritableMap payload) {
        try {
            WritableMap params = payload == null ? Arguments.createMap() : payload;
            params.putString("event", event);
            if (!reactContext.hasActiveReactInstance()) return;
            reactContext
                    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                    .emit(ZOOM_EVENT_CHANNEL, params);
        } catch (Exception ex) {
            Log.e(TAG, "emitZoomEvent(" + event + ") failed", ex);
        }
    }

    private static WritableArray toLongArray(List<Long> values) {
        WritableArray array = Arguments.createArray();
        if (values != null) {
            for (Long value : values) {
                if (value != null) array.pushDouble(value.doubleValue());
            }
        }
        return array;
    }

    private static WritableArray toStringArray(String[] values) {
        WritableArray array = Arguments.createArray();
        if (values != null) {
            for (String value : values) array.pushString(value);
        }
        return array;
    }

    private static WritableMap toMeetingParameter(MeetingParameter parameter) {
        if (parameter == null) return null;
        WritableMap map = Arguments.createMap();
        map.putString("meetingType", parameter.meeting_type == null ? null : parameter.meeting_type.name());
        map.putBoolean("isViewOnly", parameter.isViewOnly);
        map.putBoolean("isAutoRecordingLocal", parameter.is_auto_recording_local);
        map.putBoolean("isAutoRecordingCloud", parameter.is_auto_recording_cloud);
        map.putDouble("meetingNumber", (double) parameter.meeting_number);
        map.putString("meetingTopic", parameter.meeting_topic);
        map.putString("meetingHost", parameter.meeting_host);
        return map;
    }


    // Removed in 7.2.1: InMeetingServiceListener no longer declares
    // onMeetingUserUpdated(long), onSinkMeetingVideoQualityChanged(VideoQuality, long),
    // or the boolean form of onCameraControlRequestResult -- that one widened to
    // an enum, which Approve / Decline / Revoke could not be told apart under.
    // All three already have cover here: onMeetingUserJoin and onMeetingUserLeave,
    // onUserVideoStatusChanged with onUserNetworkStatusChanged, and the generated
    // enum overload of onCameraControlRequestResult.

}
