#import <ReplayKit/ReplayKit.h>
#import "RNZoomUs.h"
#import "RNZoomUsEvents.h"
#import "RNZoomUsCommands.h"
#import <React/RCTViewManager.h>
#import "ProviderDelegate.h"
#import "GlobalData.h"
#import <AVFoundation/AVFoundation.h>
#import "MobileRTC/MobileRTCMeetingService+Audio.h"
@implementation RNZoomUs
{
    BOOL isInitialized;
    BOOL shouldAutoConnectAudio;
    BOOL hasObservers;
    BOOL enableCustomMeeting;
    BOOL disableShowVideoPreviewWhenJoinMeeting;
    BOOL disableMinimizeMeeting;
    BOOL disableClearWebKitCache;
    BOOL meetingShareHidden;
    BOOL meetingVideoHidden;
    BOOL meetingAudioHidden;
    BOOL closeCaptionHidden;
    BOOL disableCloudWhiteboard;
    BOOL meetingMoreHidden;
    BOOL meetingTitleHidden;
    BOOL meetingPasswordHidden;
    BOOL meetingInviteHidden;
    BOOL meetingInviteUrlHidden;
    BOOL meetingChatHidden;
    BOOL disableCopyMeetingUrl;
    BOOL disableDriveMode;
    BOOL autoConnectInternetAudio;
    
    RCTPromiseResolveBlock initializePromiseResolve;
    RCTPromiseRejectBlock initializePromiseReject;
    RCTPromiseResolveBlock meetingPromiseResolve;
    RCTPromiseRejectBlock meetingPromiseReject;
    // If screenShareExtension is set, the Share Content > Screen option will automatically be
    // enabled in the UI
    NSString *screenShareExtension;
    
    NSString *jwtToken;
    ProviderDelegate *providerDelegate;
    CXCallController *callController;
}

- (instancetype)init {
    if (self = [super init]) {
        isInitialized = NO;
        shouldAutoConnectAudio = NO;
        enableCustomMeeting = NO;
        disableShowVideoPreviewWhenJoinMeeting = YES;
        disableMinimizeMeeting = NO;
        disableClearWebKitCache = NO;
        initializePromiseResolve = nil;
        initializePromiseReject = nil;
        meetingPromiseResolve = nil;
        meetingPromiseReject = nil;
        screenShareExtension = nil;
        jwtToken = nil;
        providerDelegate = nil;
        callController = nil;
    }
    
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioRouteChanged:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

# pragma mark - UI Native Component

RCT_EXPORT_MODULE()

// The generic SDK bridge: any Zoom method, by route and selector, with no
// wrapper per call. This is what makes the surface tunable from JavaScript --
// a screen that needs one more SDK call ships as an OTA update instead of a
// native rebuild and a pod republish. The Android side has had this since the
// start (RNZoomUsCommands.java, one reflective invoke); src/commands/index.ts
// already routes both platforms through it and only falls back to rejecting
// when this method is missing.
//
// Runs on the main queue: almost every MobileRTC call has to, and a background
// call is the kind of fault that shows up as a hang or a crash on a user's
// device rather than here.
RCT_EXPORT_METHOD(invoke: (NSString *)route
                  method:(NSString *)method
                    args:(NSArray *)args
                resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        id target = [RNZoomUsCommands resolve:route error:&error];
        if (target == nil) {
            reject(@"ERR_ZOOM_INVOKE",
                   [NSString stringWithFormat:@"%@.%@: %@", route ?: @"", method,
                    error.localizedDescription ?: @"could not resolve the route"],
                   error);
            return;
        }
        id result = [RNZoomUsCommands call:target selector:method args:args error:&error];
        if (error != nil) {
            reject(@"ERR_ZOOM_INVOKE",
                   [NSString stringWithFormat:@"%@.%@: %@", route ?: @"", method,
                    error.localizedDescription ?: @"call failed"],
                   error);
            return;
        }
        resolve(result);
    });
}

RCT_EXPORT_METHOD(isInitialized: (RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject) {
    @try {
        // todo check from ZoomSdk
        resolve(@(isInitialized));
    } @catch (NSError *ex) {
        reject(@"ERR_UNEXPECTED_EXCEPTION", @"Executing isInitialized", ex);
    }
}

RCT_EXPORT_METHOD(
                  initialize: (NSDictionary *)data
                  withSettings: (NSDictionary *)settings
                  withResolve: (RCTPromiseResolveBlock)resolve
                  withReject: (RCTPromiseRejectBlock)reject
                  )
{
    if (isInitialized) {
        resolve(@"Already initialize Zoom SDK successfully.");
        return;
    }
    
    isInitialized = true;
    providerDelegate = [[ProviderDelegate alloc] init];
    callController = [[CXCallController alloc] init];
    
    @try {
        // These used to be hardcoded in setMeetingSettings. They are settings
        // now, and the defaults are exactly what was hardcoded -- an app that
        // passes nothing behaves as it always did.
        meetingTitleHidden = YES;
        meetingPasswordHidden = YES;
        meetingInviteHidden = YES;
        meetingInviteUrlHidden = YES;
        disableCopyMeetingUrl = YES;
        disableDriveMode = YES;
        autoConnectInternetAudio = YES;
        // The one exception: setMeetingChatHidden was commented out, so chat has
        // always been visible. Keeping that, now as something you can change.
        meetingChatHidden = NO;

        initializePromiseResolve = resolve;
        initializePromiseReject = reject;
        
        screenShareExtension = data[@"iosScreenShareExtensionId"];
        jwtToken = data[@"jwtToken"];
        
        MobileRTCSDKInitContext *context = [[MobileRTCSDKInitContext alloc] init];
        context.domain = data[@"domain"];
        context.enableLog = NO;
        context.locale = MobileRTC_ZoomLocale_Default;
        
        //Note: This step is optional, Method is used for iOS Replaykit Screen share integration,if not,just ignore this step.
        context.appGroupId = data[@"iosAppGroupId"];
        
        if (settings[@"enableCustomizedMeetingUI"]) {
            enableCustomMeeting = [[settings objectForKey:@"enableCustomizedMeetingUI"] boolValue];
        }
        context.enableCustomizeMeetingUI = enableCustomMeeting;
        
        if (settings[@"disableShowVideoPreviewWhenJoinMeeting"]) {
            disableShowVideoPreviewWhenJoinMeeting = [[settings objectForKey:@"disableShowVideoPreviewWhenJoinMeeting"] boolValue];
        }
        
        if (settings[@"disableMinimizeMeeting"]) {
            disableMinimizeMeeting = [[settings objectForKey:@"disableMinimizeMeeting"] boolValue];
        }
        
        if (settings[@"disableClearWebKitCache"]) {
            disableClearWebKitCache = [[settings objectForKey:@"disableClearWebKitCache"] boolValue];
        }
        
        if (settings[@"meetingShareHidden"]) {
            meetingShareHidden = [[settings objectForKey:@"meetingShareHidden"] boolValue];
        }
        
        if (settings[@"meetingVideoHidden"]) {
            meetingVideoHidden = [[settings objectForKey:@"meetingVideoHidden"] boolValue];
        }
        
        if (settings[@"meetingAudioHidden"]) {
            meetingAudioHidden = [[settings objectForKey:@"meetingAudioHidden"] boolValue];
        }
        
        if (settings[@"closeCaptionHidden"]) {
            closeCaptionHidden = [[settings objectForKey:@"closeCaptionHidden"] boolValue];
        }
        
        if (settings[@"disableCloudWhiteboard"]) {
            disableCloudWhiteboard = [[settings objectForKey:@"disableCloudWhiteboard"] boolValue];
        }
        
        if (settings[@"meetingMoreHidden"]) {
            meetingMoreHidden = [[settings objectForKey:@"meetingMoreHidden"] boolValue];
        }
        
        if (settings[@"meetingTitleHidden"]) {
            meetingTitleHidden = [[settings objectForKey:@"meetingTitleHidden"] boolValue];
        }
        
        if (settings[@"meetingPasswordHidden"]) {
            meetingPasswordHidden = [[settings objectForKey:@"meetingPasswordHidden"] boolValue];
        }
        
        if (settings[@"meetingInviteHidden"]) {
            meetingInviteHidden = [[settings objectForKey:@"meetingInviteHidden"] boolValue];
        }
        
        if (settings[@"meetingInviteUrlHidden"]) {
            meetingInviteUrlHidden = [[settings objectForKey:@"meetingInviteUrlHidden"] boolValue];
        }
        
        if (settings[@"meetingChatHidden"]) {
            meetingChatHidden = [[settings objectForKey:@"meetingChatHidden"] boolValue];
        }
        
        if (settings[@"disableCopyMeetingUrl"]) {
            disableCopyMeetingUrl = [[settings objectForKey:@"disableCopyMeetingUrl"] boolValue];
        }
        
        if (settings[@"disableDriveMode"]) {
            disableDriveMode = [[settings objectForKey:@"disableDriveMode"] boolValue];
        }
        
        if (settings[@"autoConnectInternetAudio"]) {
            autoConnectInternetAudio = [[settings objectForKey:@"autoConnectInternetAudio"] boolValue];
        }
        
        [[MobileRTC sharedRTC] setLanguage:settings[@"language"]];
        
        BOOL initializeSuc = [[MobileRTC sharedRTC] initialize:context];
        MobileRTCAuthService *authService = [[MobileRTC sharedRTC] getAuthService];
        if (authService)
        {
            authService.delegate = self;
            authService.jwtToken = data[@"jwtToken"];
            
            [authService sdkAuth];
        } else {
            NSLog(@"onZoomSDKInitializeResult, no authService");
        }
    } @catch (NSError *ex) {
        reject(@"ERR_UNEXPECTED_EXCEPTION", @"Executing initialize", ex);
    }
}


RCT_EXPORT_METHOD(
                  cleanup: (RCTPromiseResolveBlock)resolve
                  withReject: (RCTPromiseRejectBlock)reject
                  )
{
    if (!isInitialized) {
        resolve(@"Already initialize Zoom SDK successfully.");
        return;
    }
    
    [[GlobalData sharedInstance] setGlobalIsInMeeting:NO];
    @try {
        isInitialized = NO;
        shouldAutoConnectAudio = NO;
        enableCustomMeeting = NO;
        disableShowVideoPreviewWhenJoinMeeting = YES;
        disableMinimizeMeeting = NO;
        disableClearWebKitCache = NO;
        initializePromiseResolve = nil;
        initializePromiseReject = nil;
        meetingPromiseResolve = nil;
        meetingPromiseReject = nil;
        screenShareExtension = nil;
        jwtToken = nil;
        providerDelegate = nil;
        callController = nil;
        [[MobileRTC sharedRTC] cleanup];
        resolve(@"Already cleanup Zoom SDK successfully.");
    } @catch (NSError *ex) {
        reject(@"ERR_UNEXPECTED_EXCEPTION", @"Executing cleanup", ex);
    }
}

- (void)setMeetingSettings {
    MobileRTCMeetingSettings *zoomSettings = [[MobileRTC sharedRTC] getMeetingSettings];
    if (zoomSettings != nil) {
        // Zoom iOS SDK 7.1.x removed -enableVideoCallPictureInPicture:.
        // PiP is now driven by the SDK itself; only the getter
        // -videoCallPictureInPictureEnabled remains. The old setter was
        // documented as "only works in ZoomUI", so it was already a no-op
        // whenever enableCustomizedMeetingUI is on.
        [zoomSettings setMeetingChatHidden:meetingChatHidden];
        [zoomSettings setAutoConnectInternetAudio:autoConnectInternetAudio];
        [zoomSettings disableDriveMode:disableDriveMode];
        [zoomSettings disableCopyMeetingUrl:disableCopyMeetingUrl];
        
        [zoomSettings disableShowVideoPreviewWhenJoinMeeting:disableShowVideoPreviewWhenJoinMeeting];
        [zoomSettings disableMinimizeMeeting:disableMinimizeMeeting];
        [zoomSettings disableClearWebKitCache:disableClearWebKitCache];
        // custom default UI
        [zoomSettings setMeetingShareHidden:meetingShareHidden];
        [zoomSettings setMeetingVideoHidden:meetingVideoHidden];
        [zoomSettings setMeetingAudioHidden:meetingAudioHidden];
        [zoomSettings setCloseCaptionHidden:closeCaptionHidden];
        // 7.2.1 moved this off MobileRTCMeetingSettings onto the meeting
        // service (MobileRTCMeetingService+Whiteboard). The service is nil
        // before initialize() finishes, so the setting is applied where it can
        // be rather than assumed.
        MobileRTCMeetingService *whiteboardService = [[MobileRTC sharedRTC] getMeetingService];
        if (whiteboardService) {
            [whiteboardService disableCloudWhiteboard:disableCloudWhiteboard];
        }
        [zoomSettings setMeetingMoreHidden:meetingMoreHidden];
        
        [zoomSettings setMeetingInviteUrlHidden:meetingInviteUrlHidden];
        [zoomSettings setMeetingPasswordHidden:meetingPasswordHidden];
        [zoomSettings setMeetingInviteHidden:meetingInviteHidden];
        [zoomSettings setMeetingTitleHidden:meetingTitleHidden];
    }
}

RCT_EXPORT_METHOD(
                  startMeeting: (NSDictionary *)data
                  withResolve: (RCTPromiseResolveBlock)resolve
                  withReject: (RCTPromiseRejectBlock)reject
                  )
{
    @try {
        meetingPromiseResolve = resolve;
        meetingPromiseReject = reject;
        
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (ms) {
            ms.delegate = self;
            
            MobileRTCMeetingStartParam4WithoutLoginUser * params = [[MobileRTCMeetingStartParam4WithoutLoginUser alloc]init];
            params.userName = data[@"userName"];
            params.meetingNumber = data[@"meetingNumber"];
            // data[@"userType"] is an NSNumber; MobileRTCUserType is an
            // NSUInteger enum. Assigning the object directly stored the
            // pointer address as the user type, so the value sent to the SDK
            // was never the one the caller passed.
            params.userType = (MobileRTCUserType)[data[@"userType"] unsignedIntegerValue];
            params.zak = data[@"zoomAccessToken"];
            
            MobileRTCMeetError startMeetingResult = [ms startMeetingWithStartParam:params];
            NSLog(@"startMeeting, startMeetingResult=%lu", startMeetingResult);

            // Settled by onMeetingStateChange / onMeetingError, which is why the
            // blocks are stored above. Only an immediate failure is answered
            // here, because then no delegate callback follows. This is the
            // contract the Android side has always had.
            if (startMeetingResult != MobileRTCMeetError_Success) {
                meetingPromiseResolve = nil;
                meetingPromiseReject = nil;
                reject(@"ERR_ZOOM_START",
                       [NSString stringWithFormat:@"startMeeting, errorCode=%lu", (unsigned long)startMeetingResult],
                       nil);
            }
        } else {
            meetingPromiseResolve = nil;
            meetingPromiseReject = nil;
            reject(@"ERR_ZOOM_START", @"getMeetingService returned nil; is the SDK initialized?", nil);
        }
    } @catch (NSException *ex) {
        meetingPromiseResolve = nil;
        meetingPromiseReject = nil;
        reject(@"ERR_UNEXPECTED_EXCEPTION",
               [NSString stringWithFormat:@"Executing startMeeting: %@", ex.reason ?: ex.name],
               nil);
    }
}

RCT_EXPORT_METHOD(
                  joinMeeting: (NSDictionary *)data
                  withResolve: (RCTPromiseResolveBlock)resolve
                  withReject: (RCTPromiseRejectBlock)reject
                  )
{
    @try {
        [self configureAudioSession];
        shouldAutoConnectAudio = [[data objectForKey:@"autoConnectAudio"] boolValue];
        meetingPromiseResolve = resolve;
        meetingPromiseReject = reject;
        
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        
        if (ms) {
            ms.delegate = self;
            
            MobileRTCMeetingJoinParam * joinParam = [[MobileRTCMeetingJoinParam alloc]init];
            joinParam.userName = data[@"userName"];
            joinParam.meetingNumber = data[@"meetingNumber"];
            joinParam.password =  data[@"password"];
            //            joinParam.participantID = data[@"participantID"]; // todo any new keyword?
            joinParam.zak = data[@"zoomAccessToken"];
            joinParam.webinarToken =  data[@"webinarToken"];
            joinParam.noAudio = data[@"noAudio"];
            joinParam.noVideo = data[@"noVideo"];
            
            MobileRTCMeetError joinMeetingResult = [ms joinMeetingWithJoinParam:joinParam];
            NSLog(@"RNZoomUs onJoinaMeeting ret: %@", joinMeetingResult == MobileRTCMeetError_Success ? @"Success" : @(joinMeetingResult));

            // Settled by onMeetingStateChange / onMeetingError, which is why the
            // blocks are stored above. Only an immediate failure is answered
            // here, because then no delegate callback follows. This is the
            // contract the Android side has always had.
            // Resolving here as well settled the same promise twice on every
            // successful join -- "Tried to resolve a promise more than once",
            // raised the moment the meeting starts rather than when it ends.
            if (joinMeetingResult != MobileRTCMeetError_Success) {
                meetingPromiseResolve = nil;
                meetingPromiseReject = nil;
                reject(@"ERR_ZOOM_JOIN",
                       [NSString stringWithFormat:@"joinMeeting, errorCode=%lu", (unsigned long)joinMeetingResult],
                       nil);
            }
        } else {
            // Nothing would ever settle the promise otherwise: the caller's
            // await would hang for the life of the app.
            meetingPromiseResolve = nil;
            meetingPromiseReject = nil;
            reject(@"ERR_ZOOM_JOIN", @"getMeetingService returned nil; is the SDK initialized?", nil);
        }
    } @catch (NSException *ex) {
        // Was @catch(NSError *), which never matched: Objective-C throws
        // NSException, so anything the SDK threw here escaped uncaught.
        meetingPromiseResolve = nil;
        meetingPromiseReject = nil;
        reject(@"ERR_UNEXPECTED_EXCEPTION",
               [NSString stringWithFormat:@"Executing joinMeeting: %@", ex.reason ?: ex.name],
               nil);
    }
}

- (void)configureAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    // Đặt category phù hợp: playAndRecord để có thể vừa thu vừa phát
    BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                            withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                                  error:&error];
    
    if (!success) {
        NSLog(@"[Audio] Failed to set category: %@", error);
    }
    
    // Kích hoạt session
    success = [session setActive:YES error:&error];
    if (!success) {
        NSLog(@"[Audio] Failed to activate session: %@", error);
    }
}

RCT_EXPORT_METHOD(leaveMeeting: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) return;
        [ms leaveMeetingWithCmd:LeaveMeetingCmd_Leave];
    } @catch (NSError *ex) {
        reject(@"ERR_UNEXPECTED_EXCEPTION", @"Executing leaveMeeting", ex);
    }
}

RCT_EXPORT_METHOD(connectAudio: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        [self connectAudio];
        resolve(nil);
    } @catch (NSError *ex) {
        reject(@"ERR_UNEXPECTED_EXCEPTION", @"Executing connectAudio", ex);
    }
}

- (void)connectAudio {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    MobileRTCMeetingSettings *zoomSettings = [[MobileRTC sharedRTC] getMeetingSettings];
    if (!ms || !isInitialized) return;
    [zoomSettings setAutoConnectInternetAudio:YES];
    [ms resetMeetingAudioSession];
    
    [ms connectMyAudio: YES];
    //    [ms connectMyAudio: YES];
    [ms muteMyAudio: YES];
    [ms muteMyVideo: YES];
    NSLog(@"connectAudio");
}


RCT_EXPORT_METHOD(isMeetingConnected: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        MobileRTCMeetingState state = [ms getMeetingState];
        resolve(@(state == MobileRTCMeetingState_InMeeting));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing isMeetingConnected", ex);
    }
}

RCT_EXPORT_METHOD(isMeetingHost: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        resolve(@([ms isMeetingHost]));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing isMeetingHost", ex);
    }
}

RCT_EXPORT_METHOD(getInMeetingUserIdList: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        NSMutableArray *rnUserList = [[NSMutableArray alloc] init];
        if (ms) {
            NSArray<NSNumber *> *userList = [ms getInMeetingUserList];
            if (userList != nil) {
                [userList enumerateObjectsUsingBlock:^(NSNumber *userId, NSUInteger idx, BOOL *stop) {
                    [rnUserList addObject:[userId stringValue]];
                }];
            }
        }
        resolve(rnUserList);
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing getInMeetingUserIdList", ex);
    }
}

RCT_EXPORT_METHOD(muteMyAudio: (BOOL)muted resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        MobileRTCAudioError error = [ms muteMyAudio: muted];
        if (error == 0) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", [NSString stringWithFormat:@"Mute my video error, status: %lu", error], nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing muteMyAudio", ex);
    }
}

RCT_EXPORT_METHOD(muteMyVideo: (BOOL)muted resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        MobileRTCSDKError error = [ms muteMyVideo:muted];
        if (error == 0) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", [NSString stringWithFormat:@"Mute my video error, status: %lu", error], nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing muteMyVideo", ex);
    }
}

RCT_EXPORT_METHOD(muteAttendee: (NSString *)userId muted:(BOOL)muted resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        // -muteUserAudio:withUID: takes an NSUInteger. Passing the boxed
        // NSNumber handed the SDK the pointer address instead of the user id,
        // so this never muted the requested attendee.
        NSUInteger zoomUserId = (NSUInteger)[userId longLongValue];
        if ([ms muteUserAudio:muted withUID:zoomUserId]) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Fail to mute attendee", nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing muteAttendee", ex);
    }
}

RCT_EXPORT_METHOD(muteAllAttendee: (BOOL)allowUnmuteSelf resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        if ([ms muteAllUserAudio: allowUnmuteSelf]) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Fail to mute all attendee", nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing muteAllAttendee", ex);
    }
}

RCT_EXPORT_METHOD(startShareScreen: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        if ([ms startAppShare]) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Fail to share screen", nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing startShareScreen", ex);
    }
}

RCT_EXPORT_METHOD(stopShareScreen: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (ms) {
            [ms stopAppShare];
        }
        resolve(nil);
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing stopShareScreen", ex);
    }
}

RCT_EXPORT_METHOD(switchCamera: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        MobileRTCCameraError error = [ms switchMyCamera];
        if (error == 0) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", [NSString stringWithFormat:@"Switch camera error, status: %lu", error], nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing switchCamera", ex);
    }
}

RCT_EXPORT_METHOD(raiseMyHand: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        if ([ms raiseMyHand]) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Fail raise hand", nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing raiseMyHand", ex);
    }
}

RCT_EXPORT_METHOD(lowerMyHand: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (!ms) {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Cannot get meeting service.", nil);
            return;
        }
        if ([ms lowerHand:[ms myselfUserID]]) {
            resolve(nil);
        } else {
            reject(@"ERR_ZOOM_MEETING_CONTROL", @"Fail lower hand", nil);
        }
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing lowerMyHand", ex);
    }
}

RCT_EXPORT_METHOD(joinBO: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCBOAttendee *attendee = [[[MobileRTC sharedRTC] getMeetingService] getAttedeeHelper];
        
        if (!attendee) {
            reject(@"BO_UNASSIGNED", @"BO_UNASSIGNED", nil);
            return;
        }
        
        BOOL ret = [attendee joinBO];
        NSLog(@"attendee join BO: %@", ret? @"Success": @"Fail");
        resolve(@(ret));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing joinBO", ex);
    }
}

RCT_EXPORT_METHOD(leaveBO: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCBOAttendee *attendee = [[[MobileRTC sharedRTC] getMeetingService] getAttedeeHelper];
        
        if (!attendee) {
            NSLog(@"no object");
            return;
        }
        
        BOOL ret = [attendee leaveBO];
        NSLog(@"attendee leave BO: %@", ret? @"Success": @"Fail");
        resolve(@(ret));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing leaveBO", ex);
    }
}

RCT_EXPORT_METHOD(requestForHelp: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCBOAttendee *attendee = [[[MobileRTC sharedRTC] getMeetingService] getAttedeeHelper];
        
        if (!attendee) {
            NSLog(@"no object");
            return;
        }
        
        BOOL requestResult = [attendee requestForHelp];
        NSString *resultMsg = requestResult? @"succeed" : @"failed";
        resolve(@(requestResult));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing requestForHelp", ex);
    }
}

RCT_EXPORT_METHOD(isHostInThisBO: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCBOAttendee *attendee = [[[MobileRTC sharedRTC] getMeetingService] getAttedeeHelper];
        
        if (!attendee) {
            NSLog(@"no object");
            return;
        }
        
        BOOL requestResult = [attendee isHostInThisBO];
        NSString *resultMsg = requestResult? @"succeed" : @"failed";
        resolve(@(requestResult));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing requestForHelp", ex);
    }
}

RCT_EXPORT_METHOD(getAllChatMessageID: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (ms) {
            NSMutableArray *dataSource = [[ms getAllChatMessageID] mutableCopy];
            if (dataSource != nil) {
                resolve(dataSource);
            }
        }
        resolve(nil);
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing getAllChatMessageID", ex);
    }
}

RCT_EXPORT_METHOD(sendChatMsg: (NSDictionary *)msgData resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (ms) {
            NSNumber *receiverIdNumber = msgData[@"receiverId"];
            NSInteger receiverId = [receiverIdNumber integerValue];
            NSString *content = msgData[@"content"];
            NSNumber *hostIdNumber = msgData[@"hostId"];
            NSInteger hostId = [hostIdNumber integerValue];
            NSString *messageToHost = msgData[@"messageToHost"];
            NSString *previousChatId = msgData[@"previousChatId"];
            MobileRTCChatMessageType chatMessageType =(MobileRTCChatMessageType)[msgData[@"chatMessageType"] unsignedIntegerValue];
            MobileRTCMeetingChatBuilder *builder = [[MobileRTCMeetingChatBuilder alloc] init];
            MobileRTCMeetingChat *newChat = [[[[builder setContent:content] setReceiver:receiverId] setMessageType:chatMessageType] build];
            bool ret = [ms sendChatMsg:newChat];
            NSLog(@"sendCommentsChatMsg==>%@", @(ret));
            if (messageToHost.length > 0 && hostId != 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    [ms deleteChatMessage:previousChatId];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                        MobileRTCMeetingChat *newReplaceChat = [[[[builder setContent:messageToHost] setReceiver:hostId] setMessageType:MobileRTCChatMessageType_To_Individual] build];
                        [ms sendChatMsg:newReplaceChat];});
                });
            }
        }
        resolve(@(YES));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing sendChatMsg", ex);
    }
}

RCT_EXPORT_METHOD(deleteChatMessage: (NSString * _Nullable)msgId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if (ms) {
            bool isCanDelete =[ms isChatMessageCanBeDeleted:msgId];
            bool ret = [ms deleteChatMessage:msgId];
            NSLog(@"deleteChatMessage==>%@", @(ret));
        }
        resolve(@(YES));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing sendChatMsg", ex);
    }
}
RCT_EXPORT_METHOD(isHostUser: (NSUInteger)userId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService] ;
        
        if (!ms) {
            NSLog(@"no object");
            return;
        }
        
        BOOL requestResult = [ms isHostUser:userId];
        resolve(@(requestResult));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing isHostUser", ex);
    }
}

RCT_EXPORT_METHOD(getMyselfUserID: (RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService] ;
        
        if (!ms) {
            NSLog(@"no object");
            return;
        }
        
        NSUInteger myselfUserID = [ms myselfUserID];
        resolve(@(myselfUserID));
    } @catch (NSError *ex) {
        reject(@"ERR_ZOOM_MEETING_CONTROL", @"Executing isHostUser", ex);
    }
}
/*
 NOTE: this is only required for android
 RCT_EXPORT_METHOD(addListener : (NSString *)eventName) {
 // Keep: Required for RN built in Event Emitter Calls.
 }
 RCT_EXPORT_METHOD(removeListeners : (NSInteger)count) {
 // Keep: Required for RN built in Event Emitter Calls.
 }
 */
- (void)appDidBecomeActive:(NSNotification *)notification {
    [self connectAudio];
}
- (void)audioRouteChanged:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    
    if (reason == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        NSLog(@"RNZoomUs Headphones connected");
    } else if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        NSLog(@"RNZoomUs Headphones disconnected");
    }
    [self updateAudioOutput];
}
- (void)updateAudioOutput {
    BOOL isInmeeting = [[GlobalData sharedInstance] globalIsInMeeting];
    if (!isInmeeting) return;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    MobileRTCAudioOutput audioOutput = [ms myAudioOutputDescription];
    NSLog(@"RNZoomUs MobileRTCAudioOutput: %lu", (unsigned long)audioOutput);
    [audioSession setActive:YES error:&error];
    if (error) {
        NSLog(@"RNZoomUs Error activating audio session: %@", error.localizedDescription);
        [self connectAudio];
        return;
    }
    AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
    BOOL isHeadphonesConnected = NO;
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        NSLog(@"RNZoomUs PortType: %@", output.portType );
        NSArray *headphoneTypes = @[AVAudioSessionPortHeadphones,
                                    AVAudioSessionPortBluetoothHFP,
                                    AVAudioSessionPortBluetoothLE,
                                    AVAudioSessionPortBluetoothA2DP];
        NSArray *receiverTypes = @[AVAudioSessionPortBuiltInReceiver];
        if ([headphoneTypes containsObject:output.portType]) {
            isHeadphonesConnected = YES;
            break;
        }
    }
    
    if (!isHeadphonesConnected) {
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        if (error) {
            NSLog(@"RNZoomUs Error overriding to speaker: %@", error.localizedDescription);
            [self connectAudio];
        }
    }
}
- (void)audioSessionError:(NSNotification *)notification {
    NSLog(@"[AudioSession] Notification: %@", notification.name);
    NSLog(@"UserInfo: %@", notification.userInfo);
}

- (void)onMeetingParameterNotification:(MobileRTCMeetingParameter *_Nullable)meetingParam {
    RNZoomUsEmit(@"onMeetingParameterNotification", @{@"meetingParamPresent": @(meetingParam != nil)});}

- (void)onMobileRTCAuthReturn:(MobileRTCAuthError)returnValue {
    NSLog(@"nZoomSDKInitializeResult, errorCode=%d", returnValue);
    [self sendEventWithName:@"AuthEvent" event:[self authErrorName:returnValue]];
    if(returnValue != MobileRTCAuthError_Success) {
        initializePromiseReject(
                                @"ERR_ZOOM_INITIALIZATION",
                                [NSString stringWithFormat:@"Error: %d", returnValue],
                                [NSError errorWithDomain:@"us.zoom.sdk" code:returnValue userInfo:nil]
                                );
    } else {
        [self setMeetingSettings];
        initializePromiseResolve(@"Initialize Zoom SDK successfully.");
    }
}


- (NSString*)formatStateToString:(MobileRTCMeetingState)state {
    NSString *result = nil;
    
    // naming taken from ios enum (https://marketplacefront.zoom.us/sdk/meeting/ios/_mobile_r_t_c_constants_8h.html#a04b17e9f78d7ddc089b7806c502bee4f)
    // and synced with android enum MeetingStatus (https://zoom.github.io/zoom-sdk-android/us/zoom/sdk/MeetingStatus.html)
    switch(state) {
        case MobileRTCMeetingState_Idle:
            result = @"MEETING_STATUS_IDLE";
            break;
        case MobileRTCMeetingState_Connecting:
            result = @"MEETING_STATUS_CONNECTING";
            break;
        case MobileRTCMeetingState_WaitingForHost:
            result = @"MEETING_STATUS_WAITINGFORHOST";
            break;
        case MobileRTCMeetingState_InMeeting:{
            result = @"MEETING_STATUS_INMEETING";
            //            [self getCurrentActiveId];
            [self connectAudio];
            [[GlobalData sharedInstance] setGlobalIsInMeeting:YES];
            break;
        }
        case MobileRTCMeetingState_Disconnecting:
            result = @"MEETING_STATUS_DISCONNECTING";
            [[GlobalData sharedInstance] setGlobalIsInMeeting:NO];
            break;
        case MobileRTCMeetingState_Reconnecting:
            result = @"MEETING_STATUS_RECONNECTING";
            break;
        case MobileRTCMeetingState_Failed:
            result = @"MEETING_STATUS_FAILED";
            break;
        case MobileRTCMeetingState_Ended: // only iOS (guessed naming)
            result = @"MEETING_STATUS_ENDED";
            break;
        case MobileRTCMeetingState_Locked: // only iOS (guessed naming)
            result = @"MEETING_STATUS_LOCKED";
            break;
        case MobileRTCMeetingState_Unlocked: // only iOS (guessed naming)
            result = @"MEETING_STATUS_UNLOCKED";
            break;
        case MobileRTCMeetingState_InWaitingRoom:
            result = @"MEETING_STATUS_IN_WAITING_ROOM";
            break;
        case MobileRTCMeetingState_WebinarPromote:
            result = @"MEETING_STATUS_WEBINAR_PROMOTE";
            break;
        case MobileRTCMeetingState_WebinarDePromote:
            result = @"MEETING_STATUS_WEBINAR_DEPROMOTE";
            break;
        case MobileRTCMeetingState_JoinBO: // only iOS (guessed naming)
            result = @"MEETING_STATUS_JOIN_BO";
            //            [self connectAudio];
            [[GlobalData sharedInstance] setGlobalIsConnectedDefaultAudioSession:NO];
            break;
        case MobileRTCMeetingState_LeaveBO: // only iOS (guessed naming)
            result = @"MEETING_STATUS_LEAVE_BO";
            //            [self connectAudio];
            [[GlobalData sharedInstance] setGlobalIsConnectedDefaultAudioSession:NO];
            break;
            
        default:
            [NSException raise:NSGenericException format:@"Unexpected state."];
    }
    
    return result;
}

- (void)getCurrentActiveId {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isWebinarMeeting = [ms isWebinarMeeting];
    BOOL isViewingShare = [ms isViewingShare];
    if(isViewingShare) {
        // 7.2.1 removed -activeShareUserID. getViewableSharingUserList returns
        // everyone whose share can be viewed; the first entry is the closest
        // equivalent, and an empty list means nobody is sharing.
        NSArray<NSNumber *> *sharing = [ms getViewableSharingUserList];
        if (sharing.count > 0) {
            [[GlobalData sharedInstance] setGlobalActiveShareID:sharing.firstObject.unsignedIntegerValue];
        }
    } else {
        [[GlobalData sharedInstance] setUserID:[ms activeUserID]];
    }
}
- (void)onMeetingStateChange:(MobileRTCMeetingState)state {
    RNZoomUsEmit(@"onMeetingStateChange", @{@"state": @(state)});
    NSLog(@"onMeetingStatusChanged, meetingState=%@", @(state));
    
    NSString* statusString = [self formatStateToString:state];
    [self sendEventWithName:@"MeetingEvent" event:@"success" status:statusString];
    [self sendEventWithName:@"MeetingStatus" event:statusString];
    
    
    
    if (!enableCustomMeeting && state == MobileRTCMeetingState_Connecting && providerDelegate.callingUUID == nil) {
        NSUUID *callUUID = [NSUUID UUID];
        
        CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Học Viện Minh Trí Thành"]];
        CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
        callUpdate.remoteHandle = startCallAction.handle;
        callUpdate.hasVideo = startCallAction.video;
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
        [callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error requesting start call transaction: %@", error.localizedDescription);
                self->providerDelegate.callingUUID = nil;
            } else {
                NSLog(@"Requested start call transaction succeeded");
                NSLog(@"callUUID 1: %@", callUUID);
                self->providerDelegate.callingUUID = callUUID;
                NSLog(@"callUUID 2: %@", self->providerDelegate.callingUUID);
            }
        }];
    }
    else if (!enableCustomMeeting && state == MobileRTCMeetingState_Ended && providerDelegate.callingUUID != nil) {
        NSLog(@"endCallUUID: %@", providerDelegate.callingUUID);
        CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:providerDelegate.callingUUID];
        CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
        [callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error requesting end call transaction: %@", error.localizedDescription);
            } else {
                NSLog(@"Requested end call transaction succeeded");
                self->providerDelegate.callingUUID = nil;
            }
        }];
    }
    
    // The join promise is settled from the meeting *state*, never from an error
    // callback, and every state that ends the attempt settles it:
    //
    //   resolve  InMeeting, InWaitingRoom, WaitingForHost -- the join worked and
    //            the user has landed somewhere, even if the host has not let
    //            them in yet. Leaving these pending strands the caller's await
    //            for as long as the wait lasts.
    //   reject   Failed, Ended -- the attempt is over and the user is not in a
    //            meeting. Ended matters: a meeting that finishes mid-join, or a
    //            user who backs out of Zoom's own UI, never reaches Failed, and
    //            a promise nothing will ever settle is worse than a wrong
    //            answer because nothing times it out.
    //   ignore   everything else, Idle included. Idle is the state before a
    //            meeting starts as much as after one ends, so rejecting on it
    //            would answer a join that has not begun.
    //
    // The blocks are taken into locals and the ivars cleared first: settling
    // re-enters JavaScript synchronously, and whatever that does can bring the
    // SDK straight back into this handler.
    BOOL joined = state == MobileRTCMeetingState_InMeeting
                || state == MobileRTCMeetingState_InWaitingRoom
                || state == MobileRTCMeetingState_WaitingForHost;
    BOOL over   = state == MobileRTCMeetingState_Failed
                || state == MobileRTCMeetingState_Ended;

    if (joined || over) {
        RCTPromiseResolveBlock resolve = meetingPromiseResolve;
        RCTPromiseRejectBlock reject = meetingPromiseReject;
        if (!resolve) {
            return;
        }
        meetingPromiseResolve = nil;
        meetingPromiseReject = nil;

        if (over) {
            reject(@"ERR_ZOOM_MEETING",
                   [NSString stringWithFormat:@"Meeting state: %@",
                    state == MobileRTCMeetingState_Failed ? @"failed" : @"ended"],
                   nil);
        } else {
            resolve(@"Connected to zoom meeting");
        }
    }
}

- (void)onMeetingError:(MobileRTCMeetError)errorCode message:(NSString *)message {
    RNZoomUsEmit(@"onMeetingError", @{@"errorCode": @(errorCode), @"message": message ?: [NSNull null]});
    NSLog(@"onMeetingError, errorCode=%d, message=%@", errorCode, message);
    [self sendEventWithName:@"MeetingEvent" event:[self meetErrorName:errorCode]];
    
    // Deliberately does not settle the join promise. This is the frame the red
    // box named, and the header documents the callback only as "an error has
    // occurred" -- it says nothing about which codes arrive on a healthy join,
    // so treating every one of them as the answer to joinMeeting() turned
    // whatever the SDK happened to report into a rejected join. The state
    // machine decides instead, in onMeetingStateChange. The event is still
    // emitted, so JavaScript sees every error either way.
}

- (void)onMeetingEndedReason:(MobileRTCMeetingEndReason)reason {
    RNZoomUsEmit(@"onMeetingEndedReason", @{@"reason": @(reason)});
    [self sendEventWithName:@"MeetingEvent" event:[self meetingEndReasonName:reason]];
}

- (void)onChatMessageNotification:(MobileRTCMeetingChat * _Nullable)chatInfo;
{
    if (!isInitialized) {
        return;
    }
    NSLog(@"RNZoomUsVideoView MobileRTCMeetingChat-->%@",chatInfo.content);
    NSDictionary *chatInfoDict = nil;
    if (chatInfo) {
        //            MobileRTCMeetingUserInfo *userInfo = [self getUserInfo:chatInfo.chatId];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
        NSString *dateString = [dateFormatter stringFromDate:chatInfo.date];
        // Every string on MobileRTCMeetingChat is nullable, and a dictionary
        // literal raises when handed nil -- which would take the process down on
        // a chat message with, say, no receiver. NSNull reaches JavaScript as
        // null, which is what the Android side sends for the same fields.
        chatInfoDict = @{
            @"chatId": chatInfo.chatId ?: [NSNull null],
            @"senderId": chatInfo.senderId ?: [NSNull null],
            @"senderName": chatInfo.senderName ?: [NSNull null],
            @"receiverId": chatInfo.receiverId ?: [NSNull null],
            @"receiverName": chatInfo.receiverName ?: [NSNull null],
            @"content": chatInfo.content ?: [NSNull null],
            @"date": dateString ?: [NSNull null],
            @"chatMessageType": @(chatInfo.chatMessageType),
            @"isMyself": @(chatInfo.isMyself),
            @"isPrivate": @(chatInfo.isPrivate),
            @"isChatToAll": @(chatInfo.isChatToAll),
            @"isChatToAllPanelist": @(chatInfo.isChatToAllPanelist),
            @"isChatToWaitingroom": @(chatInfo.isChatToWaitingroom),
            @"isComment": @(chatInfo.isComment),
            @"isThread": @(chatInfo.isThread),
            @"threadID": chatInfo.threadID ?: [NSNull null],
        };
    }
    [self sendEventWithName:@"MeetingEvent" body: @{
        @"event": @"onChatMessageNotification",
        // nil whenever the callback arrived without a message.
        @"chatInfo": chatInfoDict ?: [NSNull null]
    }];
}
#pragma mark - Screen share functionality

- (void)onSinkShareSizeChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkShareSizeChange", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkShareSizeChange==%@",@(userID));
}


- (void)onClickShareScreen:(UIViewController *)parentVC {
    RNZoomUsEmit(@"onClickShareScreen", @{@"parentVCPresent": @(parentVC != nil)});
    if (@available(iOS 12.0, *)) {
        CGRect frame = parentVC.view.bounds;
        RPSystemBroadcastPickerView *pickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:frame];
        pickerView.preferredExtension = screenShareExtension;
        SEL buttonPressed = NSSelectorFromString(@"buttonPressed:");
        if ([pickerView respondsToSelector:buttonPressed]) {
            [pickerView performSelector:buttonPressed withObject:nil];
        }
    }
}

- (void)onSinkSharingStatus:(MobileRTCSSharingSourceInfo*_Nonnull)shareInfo {
    RNZoomUsEmit(@"onSinkSharingStatus", @{@"shareInfoPresent": @(shareInfo != nil)});}

#pragma mark - https://marketplacefront.zoom.us/sdk/meeting/ios/_mobile_r_t_c_meeting_delegate_8h_source.html


#pragma mark - MobileRTCVideoServiceDelegate

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID videoStatus:(MobileRTC_VideoStatus)videoStatus {
    RNZoomUsEmit(@"onSinkMeetingVideoStatusChange", @{@"userID": @(userID), @"videoStatus": @(videoStatus)});
    NSLog(@"RNZoomUs onSinkMeetingVideoStatusChange=%@, videoStatus=%@",@(userID), @(videoStatus));
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    
    if (videoStatus == MobileRTC_VideoStatus_Video_ON) {
        [[GlobalData sharedInstance] setUserID:userID];
    }
    if ([ms isMyself:userID]) {
        [self sendEventWithName:@"MeetingEvent" event:@"myVideoStatusChanged" userInfo:[ms userInfoByID:[ms myselfUserID]]];
    }
}

-  (void)onSinkMeetingVideoRequestUnmuteByHost:(MobileRTCSDKError (^_Nonnull)(BOOL Accept))completion {
    RNZoomUsEmit(@"onSinkMeetingVideoRequestUnmuteByHost", nil);
    [self sendEventWithName:@"MeetingEvent" event:@"askUnMuteVideo"];
    NSLog(@"RNZoomUs onSinkMeetingVideoRequestUnmuteByHost");
    if (completion)
    {
        MobileRTCSDKError err = completion(YES);
        NSLog(@"unmute accept %@", @(err));
    }
}


- (void)onSinkMeetingActiveVideo:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingActiveVideo", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingActiveVideo =>%@", @(userID));
    //    [[GlobalData sharedInstance] setUserID:userID];
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isViewingShare = [ms isViewingShare];
    BOOL isWebinarMeeting = [ms isWebinarMeeting];
    if (isWebinarMeeting) [[GlobalData sharedInstance] setGlobalWebinarFirstActiveVideoID:userID];
    if (isViewingShare) [[GlobalData sharedInstance] setGlobalActiveShareID:userID];
    NSLog(@"RNZoomUs RNZoomUs isViewingShare =>%@", @(isViewingShare));
}

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingVideoStatusChange", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingVideoStatusChange=%@",@(userID));
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isWebinar = [ms isWebinarMeeting];
    BOOL isViewingShare = [ms isViewingShare];
    //    if (isViewingShare) [[GlobalData sharedInstance] setGlobalActiveShareID:userID];
}

- (void)onMyVideoStateChange {
    RNZoomUsEmit(@"onMyVideoStateChange", nil);
    NSLog(@"RNZoomUs onMyVideoStateChange");
}

- (void)onSpotlightVideoChange:(BOOL)on {
    RNZoomUsEmit(@"onSpotlightVideoChange", @{@"on": @(on)});}

- (void)onSinkMeetingPreviewStopped {
    RNZoomUsEmit(@"onSinkMeetingPreviewStopped", nil);
    NSLog(@"RNZoomUs onSinkMeetingPreviewStopped");
}


// MobileRTCVideoQuality, not MobileRTCNetworkQuality: the SDK declares the
// former and the two are numbered differently -- Unknown is 0 in one and -1 in
// the other, so 0 reads as "unknown" or as "very bad" depending on which you
// believe. The value on the wire does not change; what it means does.
// ("qality" keeps the SDK's own spelling, which JavaScript already subscribes to.)
- (void)onSinkMeetingVideoQualityChanged:(MobileRTCVideoQuality)qality userID:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingVideoQualityChanged", @{@"qality": @(qality), @"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingVideoQualityChanged: %zd userID:%zd",qality,userID);
}

- (void)onSinkMeetingShowMinimizeMeetingOrBackZoomUI:(MobileRTCMinimizeMeetingState)state {
    RNZoomUsEmit(@"onSinkMeetingShowMinimizeMeetingOrBackZoomUI", @{@"state": @(state)});
    switch (state) {
        case MobileRTCMinimizeMeeting_ShowMinimizeMeeting:
            [self sendEventWithName:@"MeetingEvent" body:@{@"event": @"showMinimizeMeeting", @"status": @"showMinimizeMeeting"}];
            break;
            
        case MobileRTCMinimizeMeeting_BackFullScreenMeeting:
            [self sendEventWithName:@"MeetingEvent" body:@{@"event": @"backFullScreenMeeting", @"status": @"backFullScreenMeeting"}];
            break;
        default:
            break;
    }
}

- (void)onBOOptionChanged:(MobileRTCBOOption *_Nonnull)newOption {
    RNZoomUsEmit(@"onBOOptionChanged", @{@"newOptionPresent": @(newOption != nil)});}



- (void)onHostVideoOrderUpdated:(NSArray <NSNumber *>* _Nullable)orderArr;
{
    RNZoomUsEmit(@"onHostVideoOrderUpdated", @{@"orderArr": orderArr ?: @[]});
    NSLog(@"[Video Order] callback onHostVideoOrderUpdated: %@", orderArr);
}

- (void)onLocalVideoOrderUpdated:(NSArray <NSNumber *>* _Nullable)localOrderArr
{
    RNZoomUsEmit(@"onLocalVideoOrderUpdated", @{@"localOrderArr": localOrderArr ?: @[]});
    NSLog(@"[Video Order] callback onLocalVideoOrderUpdated: %@", localOrderArr);
}

#pragma mark - MobileRTCAudioServiceDelegate

- (void)onSinkMeetingMyAudioTypeChange {
    RNZoomUsEmit(@"onSinkMeetingMyAudioTypeChange", nil);
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    [self sendEventWithName:@"MeetingEvent" event:@"myAudioTypeChanged" userInfo:[ms userInfoByID:[ms myselfUserID]]];
}

- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID audioStatus:(MobileRTC_AudioStatus)audioStatus {
    RNZoomUsEmit(@"onSinkMeetingAudioStatusChange", @{@"userID": @(userID), @"audioStatus": @(audioStatus)});
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    
    if ([ms isMyself:userID]) {
        [self sendEventWithName:@"MeetingEvent" event:@"myAudioStatusChanged" userInfo:[ms userInfoByID:[ms myselfUserID]]];
    }
}

// This looks like it doesnt get called check
// https://github.com/mieszko4/react-native-zoom-us/pull/144#issuecomment-931189245
- (void)onSinkMeetingAudioRequestUnmuteByHost {
    RNZoomUsEmit(@"onSinkMeetingAudioRequestUnmuteByHost", nil);
    [self sendEventWithName:@"MeetingEvent" event:@"askUnMuteAudio"];
}

- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingAudioStatusChange", @{@"userID": @(userID)});
    NSLog(@"onSinkMeetingAudioStatusChange");
}

- (void)onSinkMeetingAudioTypeChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingAudioTypeChange", @{@"userID": @(userID)});}

- (void)onAudioOutputChange {
    RNZoomUsEmit(@"onAudioOutputChange", nil);}

- (void)onMyAudioStateChange {
    RNZoomUsEmit(@"onMyAudioStateChange", nil);
    NSLog(@"onMyAudioStateChange");
}



#pragma mark - MobileRTCUserServiceDelegate


- (void)onSinkMeetingUserLeft:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserLeft", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingUserLeft==%@", @(userID));
    [self sendEventWithName:@"MeetingEvent" params:@{
        @"event": @"userLeave",
        @"userList": @[@(userID)]
    }];
}
- (void)onSinkMeetingUserJoin:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserJoin", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingUserJoin==%@", @(userID));
    
    [self sendEventWithName:@"MeetingEvent" params:@{
        @"event": @"userJoin",
        @"userList": @[@(userID)]
    }];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(onClickShareScreen:)) {
        return screenShareExtension != nil;
    }
    return [super respondsToSelector:aSelector];
}

#pragma mark - helpers
- (NSString*)getUserRole:(NSInteger)roleCode {
    // TODO: missing USERROLE_PANELIST, USERROLE_BREAKOUTROOM_MODERATOR
    switch (roleCode) {
        case 1: return @"USERROLE_HOST";
        case 2: return @"USERROLE_COHOST";
        case 3: return @"USERROLE_ATTENDEE";
        default: return @"USERROLE_NONE";
    }
}

#pragma mark - React Native event emitters and event handling

- (void)startObserving {
    hasObservers = YES;
    // Callbacks raised while RNZoomUsVideoView holds ms.delegate arrive here.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleSDKCallbackNotification:)
                                                 name:RNZoomUsSDKCallbackNotification
                                               object:nil];
}

- (void)stopObserving {
    hasObservers = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:RNZoomUsSDKCallbackNotification
                                                  object:nil];
}

- (void)handleSDKCallbackNotification:(NSNotification *)notification {
    NSString *event = notification.userInfo[RNZoomUsSDKCallbackEventKey];
    NSDictionary *payload = notification.userInfo[RNZoomUsSDKCallbackPayloadKey];
    if (![event isKindOfClass:[NSString class]]) return;

    // sendEventWithName: must be called on the JS thread's behalf via the
    // bridge; hop to main so callbacks raised on Zoom's own threads are safe.
    if ([NSThread isMainThread]) {
        [self emitZoomEvent:event payload:payload];
    } else {
        __weak __typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf emitZoomEvent:event payload:payload];
        });
    }
}

// Unified event channel. Every SDK delegate callback is forwarded here,
// including ones nothing consumes yet, so adding a feature later never needs a
// native rebuild. The three legacy channels still emit exactly as before.
static NSString *const kZoomEventChannel = @"ZoomUsEvent";

- (NSArray<NSString *> *)supportedEvents {
    return @[@"AuthEvent", @"MeetingEvent", @"MeetingStatus", kZoomEventChannel];
}

- (void)emitZoomEvent:(NSString *)event payload:(nullable NSDictionary *)payload {
    if (!hasObservers) return;
    NSMutableDictionary *body = payload ? [payload mutableCopy] : [NSMutableDictionary dictionary];
    body[@"event"] = event;
    [self sendEventWithName:kZoomEventChannel body:body];
}

- (void)sendEventWithName:(NSString *)name event:(NSString *)event {
    // name and event come from SDK callbacks and enum lookups that can miss.
    // A nil in a dictionary literal raises, and this runs on the SDK's thread
    // where nothing catches it.
    if (name.length == 0) return;
    if (hasObservers) {
        [self sendEventWithName:name body:@{@"event": event ?: [NSNull null]}];
    }
    // Mirror onto the unified channel so subscribers there see every callback,
    // not just the ones without a legacy emitter.
    [self emitZoomEvent:event payload:@{@"channel": name ?: [NSNull null]}];
}
- (void)sendEventWithName:(NSString *)name event:(NSString *)event status:(NSString *)status {
    if (name.length == 0) return;
    if (hasObservers) {
        [self sendEventWithName:name body:@{
            @"event": event ?: [NSNull null],
            @"status": status ?: [NSNull null],
        }];
    }
}
- (void)sendEventWithName:(NSString *)name params:(NSDictionary *)params {
    if (hasObservers) {
        [self sendEventWithName:name body:params];
    }
}
- (void)sendEventWithName:(NSString *)name event:(NSString *)event userInfo:(MobileRTCMeetingUserInfo *)userInfo {
    if (hasObservers) {
        [self sendEventWithName:name body:@{
            @"event": event ?: [NSNull null],
            @"userRole": [self getUserRole:[userInfo userRole]] ?: [NSNull null],
            @"audioType": @([[userInfo audioStatus] audioType]),
            @"isTalking": @([[userInfo audioStatus] isTalking]),
            @"isMutedAudio": @((BOOL)([[userInfo audioStatus] audioType] == 2 ? YES : [[userInfo audioStatus] isMuted])),
            @"isMutedVideo": @((BOOL)![[userInfo videoStatus] isSending]),
        }];
    }
}

- (NSString *)authErrorName:(MobileRTCAuthError)error {
    switch (error) {
        case MobileRTCAuthError_ClientIncompatible: return @"clientIncompatible";
        case MobileRTCAuthError_Success: return @"success";
        case MobileRTCAuthError_AccountNotEnableSDK: return @"accountNotEnableSDK"; // iOS only
        case MobileRTCAuthError_AccountNotSupport: return @"accountNotSupport"; // iOS only
        case MobileRTCAuthError_KeyOrSecretEmpty: return @"keyOrSecretEmpty"; // iOS only
        case MobileRTCAuthError_KeyOrSecretWrong: return @"keyOrSecretWrong"; // iOS only
        case MobileRTCAuthError_NetworkIssue: return @"networkIssue"; // iOS only
        case MobileRTCAuthError_None: return @"none"; // iOS only
        case MobileRTCAuthError_OverTime: return @"overTime"; // iOS only
        case MobileRTCAuthError_ServiceBusy: return @"serviceBusy"; // iOS only
        case MobileRTCAuthError_LimitExceededException : return @"limitExceeded";
        default: return @"unknown";
    }
}

- (NSString *)meetErrorName:(MobileRTCMeetError)error {
    switch (error) {
        case MobileRTCMeetError_InvalidArguments: return @"invalidArguments";
        case MobileRTCMeetError_MeetingClientIncompatible: return @"meetingClientIncompatible";
        case MobileRTCMeetError_MeetingLocked: return @"meetingLocked";
        case MobileRTCMeetError_MeetingNotExist: return @"meetingNotExist";
        case MobileRTCMeetError_MeetingOver: return @"meetingOver";
        case MobileRTCMeetError_MeetingRestricted: return @"meetingRestricted";
        case MobileRTCMeetError_MeetingRestrictedJBH: return @"meetingRestrictedJBH";
        case MobileRTCMeetError_MeetingUserFull: return @"meetingUserFull";
        case MobileRTCMeetError_MMRError: return @"mmrError";
        // Renamed from MobileRTCMeetError_NetworkError in SDK 7.1.x (same value).
        // The JS string is kept as-is so consumers do not have to change.
        case MobileRTCMeetError_ConnectionError: return @"networkError";
        case MobileRTCMeetError_NoMMR: return @"noMMR";
        case MobileRTCMeetError_RegisterWebinarDeniedEmail: return @"registerWebinarDeniedEmail";
        case MobileRTCMeetError_RegisterWebinarEnforceLogin: return @"registerWebinarEnforceLogin";
        case MobileRTCMeetError_RegisterWebinarFull: return @"registerWebinarFull";
        case MobileRTCMeetError_RegisterWebinarHostRegister: return @"registerWebinarHostRegister";
        case MobileRTCMeetError_RegisterWebinarPanelistRegister: return @"registerWebinarPanelistRegister";
        case MobileRTCMeetError_RemovedByHost: return @"removedByHost";
        case MobileRTCMeetError_SessionError: return @"sessionError";
        case MobileRTCMeetError_Success: return @"success";
        case MobileRTCMeetError_AudioAutoStartError: return @"audioAutoStartError"; // iOS only
        case MobileRTCMeetError_CannotEmitWebRequest: return @"cannotEmitWebRequest"; // iOS only
        case MobileRTCMeetError_CannotStartTokenExpire: return @"cannotStartTokenExpire"; // iOS only
        case MobileRTCMeetError_InAnotherMeeting: return @"inAnotherMeeting"; // iOS only
        case MobileRTCMeetError_InvalidUserType: return @"invalidUserType"; // iOS only
        case MobileRTCMeetError_JoinWebinarWithSameEmail: return @"joinWebinarWithSameEmail"; // iOS only
        case MobileRTCMeetError_MeetingNotStart: return @"meetingNotStart"; // iOS only
        case MobileRTCMeetError_PasswordError: return @"passwordError"; // iOS only
        case MobileRTCMeetError_ReconnectError: return @"reconnectError"; // iOS only
        case MobileRTCMeetError_VanityNotExist: return @"vanityNotExist"; // iOS only
        case MobileRTCMeetError_VBMaximumNum: return @"vbMaximumNum"; // iOS only
        case MobileRTCMeetError_VBNoSupport: return @"vbNoSupport"; // iOS only
        case MobileRTCMeetError_VBRemoveNone: return @"vbRemoveNone"; // iOS only
        case MobileRTCMeetError_VBSaveImage: return @"vbSaveImage"; // iOS only
            // _VBSetError has the same value as _VBBase so we are excluding _VBBase
        case MobileRTCMeetError_VBSetError: return @"vbSetError"; // iOS only
        case MobileRTCMeetError_VideoError: return @"videoError"; // iOS only
        case MobileRTCMeetError_WriteConfigFile: return @"writeConfigFile"; // iOS only
        case MobileRTCMeetError_ZCCertificateChanged: return @"zcCertificateChanged"; // iOS only
        case MobileRTCMeetError_UnableToJoinExternalMeeting: return @"unableToJoinExternalMeeting";
        default: return @"unknown";
    }
}

- (NSString *)meetingEndReasonName:(MobileRTCMeetingEndReason)reason {
    switch (reason) {
        case MobileRTCMeetingEndReason_EndByHost: return @"endedByHost";
        case MobileRTCMeetingEndReason_HostEndForAnotherMeeting: return @"endedByHostForAnotherMeeting";
        // Renamed from MobileRTCMeetingEndReason_SelfLeave in 7.1.x; still value 0
        // and still documented as "User leaves meeting".
        case MobileRTCMeetingEndReason_None: return @"endedBySelf";
        // MobileRTCMeetingEndReason_ConnectBroken was removed in 7.1.x. Value 7
        // is now _Undefined, which means "end reason the client does not know
        // about" rather than "connection broken", so it falls through to the
        // default instead of being reported as a dropped connection.
        case MobileRTCMeetingEndReason_DueToAuthorizedUserLeave: return @"endedDueToAuthorizedUserLeave";
        case MobileRTCMeetingEndReason_FreeMeetingTimeout: return @"endedFreeMeetingTimeout";
        case MobileRTCMeetingEndReason_JBHTimeout: return @"endedJBHTimeout";
        case MobileRTCMeetingEndReason_RemovedByHost: return @"endedRemovedByHost";
        default: return @"endedUnknownReason";
    }
}

- (BOOL)onCheckIfMeetingVoIPCallRunning{
    return [providerDelegate isInCall];
}
- (void)onStartBOError:(MobileRTCBOControllerError)errType {
    RNZoomUsEmit(@"onStartBOError", @{@"errType": @(errType)});
    
    [self sendEventWithName:@"onStartBOError" event:[self startBOErrorName:errType]];
}


- (NSString *)startBOErrorName:(MobileRTCBOControllerError)error {
    switch (error) {
        case MobileRTCBOControllerError_NULL_POINTER: return @"NULL_POINTER";
        case MobileRTCBOControllerError_WRONG_CURRENT_STATUS: return @"WRONG_CURRENT_STATUS";
        case MobileRTCBOControllerError_TOKEN_NOT_READY: return @"TOKEN_NOT_READY";
        case MobileRTCBOControllerError_NO_PRIVILEGE: return @"NO_PRIVILEGE";
        case MobileRTCBOControllerError_BO_LIST_IS_UPLOADING: return @"BO_LIST_IS_UPLOADING";
        case MobileRTCBOControllerError_UPLOAD_FAIL: return @"UPLOAD_FAIL";
        case MobileRTCBOControllerError_NO_ONE_HAS_BEEN_ASSIGNED: return @"NO_ONE_HAS_BEEN_ASSIGNED";
        case MobileRTCBOControllerError_UNKNOWN: return @"UNKNOWN";
        default: return @"unknown";
    }
}


// MobileRTCAnnotationServiceDelegate declares onAnnotationToolChanged:
// *before* its @optional marker, so it is a required method and the SDK is
// entitled to call it without checking respondsToSelector: -- which, with no
// implementation, is an unrecognized selector. Native cannot be fixed over the
// air, so it is implemented here even though nothing consumes it yet.
- (void)onAnnotationToolChanged:(MobileRTCAnnoTool)tool {
    RNZoomUsEmit(@"onAnnotationToolChanged", @{@"tool": @(tool)});
    NSLog(@"%s onAnnotationToolChanged: %ld", __func__, (long)tool);
}

// Mirrored from RNZoomUsVideoView: the module was 18 delegate callbacks behind
// the view (auth 0/4, waiting room 0/6, plus host/co-host change and raise-hand),
// so an app on Zoom's default UI -- which talks to the module, not the view --
// simply never heard about any of them. Same payloads, every parameter carried.

- (void)onAnnotationService:(MobileRTCAnnotationService *_Nullable)service supportStatusChanged:(BOOL)support shareSouceID:(NSUInteger)shareSourceID {
    RNZoomUsEmit(@"onAnnotationService", @{@"support": @(support), @"shareSourceID": @(shareSourceID), @"servicePresent": @(service != nil)});
    NSLog(@"RNZoomUs onAnnotationService support=%d shareSourceID=%@", support, @(shareSourceID));
}

- (void)onClaimHostResult:(MobileRTCClaimHostError)error
{
    RNZoomUsEmit(@"onClaimHostResult", @{@"error": @(error)});
    NSLog(@"RNZoomUs onClaimHostResult==%@", @(error));
}

- (void)onCustomWaitingRoomDataUpdated:(MobileRTCCustomWaitingRoomData *)data {
    RNZoomUsEmit(@"onCustomWaitingRoomDataUpdated", @{@"dataPresent": @(data != nil)});
    NSLog(@"RNZoomUs onCustomWaitingRoomDataUpdated");
}

- (void)onFollowHostVideoOrderChanged:(BOOL)follow {
    RNZoomUsEmit(@"onFollowHostVideoOrderChanged", @{@"follow": @(follow)});
    NSLog(@"RNZoomUs onFollowHostVideoOrderChanged");
}

- (void)onMeetingCoHostChange:(NSUInteger)userID isCoHost:(BOOL)isCoHost {
    RNZoomUsEmit(@"onMeetingCoHostChange", @{@"userID": @(userID), @"isCoHost": @(isCoHost)});
    NSLog(@"RNZoomUs onMeetingCoHostChange==%@ isCoHost===%@", @(userID), @(isCoHost));
}

- (void)onMeetingHostChange:(NSUInteger)hostId {
    RNZoomUsEmit(@"onMeetingHostChange", @{@"hostId": @(hostId)});
    NSLog(@"RNZoomUs onMeetingHostChange==%@", @(hostId));
}

- (void)onMobileRTCAuthExpired{
    RNZoomUsEmit(@"onMobileRTCAuthExpired", nil);
    NSLog(@"RNZoomUs onMobileRTCAuthExpired");
}

- (void)onMobileRTCLoginResult:(MobileRTCLoginFailReason)resultValue{
    RNZoomUsEmit(@"onMobileRTCLoginResult", @{@"resultValue": @(resultValue)});
    NSLog(@"RNZoomUs onMobileRTCLoginResult");
}

- (void)onMobileRTCLogoutReturn:(NSInteger)returnValue{
    RNZoomUsEmit(@"onMobileRTCLogoutReturn", @{@"returnValue": @(returnValue)});
    NSLog(@"RNZoomUs onMobileRTCLogoutReturn");
}

- (void)onNotificationServiceStatus:(MobileRTCNotificationServiceStatus)status error:(MobileRTCNotificationServiceError)error{
    RNZoomUsEmit(@"onNotificationServiceStatus", @{@"status": @(status), @"error": @(error)});
    NSLog(@"RNZoomUs onNotificationServiceStatus");
}

- (void)onSinkMeetingUserLowerHand:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserLowerHand", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingUserLowerHand==%@", @(userID));
}

- (void)onSinkMeetingUserRaiseHand:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserRaiseHand", @{@"userID": @(userID)});
    NSLog(@"RNZoomUs onSinkMeetingUserRaiseHand==%@", @(userID));
}

- (void)onSinkUserNameChanged:(NSArray <NSNumber *>* _Nullable)userNameChangedArr
{
    RNZoomUsEmit(@"onSinkUserNameChanged", @{@"userNameChangedArr": userNameChangedArr ?: @[]});
    NSLog(@"onSinkUserNameChanged:%@", userNameChangedArr);
}

- (void)onWaitingRoomPresetAudioStatusChanged:(BOOL)audioCanTurnOn{
    RNZoomUsEmit(@"onWaitingRoomPresetAudioStatusChanged", @{@"audioCanTurnOn": @(audioCanTurnOn)});
    NSLog(@"RNZoomUs onWaitingRoomPresetAudioStatusChanged");
}

- (void)onWaitingRoomPresetVideoStatusChanged:(BOOL)videoCanTurnOn{
    RNZoomUsEmit(@"onWaitingRoomPresetVideoStatusChanged", @{@"videoCanTurnOn": @(videoCanTurnOn)});
    NSLog(@"RNZoomUs onWaitingRoomPresetVideoStatusChanged");
}

- (void)onWaitingRoomUserJoin:(NSUInteger)userId{
    RNZoomUsEmit(@"onWaitingRoomUserJoin", @{@"userId": @(userId)});
    NSLog(@"RNZoomUs onWaitingRoomUserJoin");
}

- (void)onWaitingRoomUserLeft:(NSUInteger)userId{
    RNZoomUsEmit(@"onWaitingRoomUserLeft", @{@"userId": @(userId)});
    NSLog(@"RNZoomUs onWaitingRoomUserLeft");
}

- (void)onWaitingRoomUserNameChanged:(NSInteger)userID userName:(NSString *)userName{
    RNZoomUsEmit(@"onWaitingRoomUserNameChanged", @{@"userID": @(userID), @"userName": userName ?: [NSNull null]});
    NSLog(@"RNZoomUs onWaitingRoomUserNameChanged");
}

// Removed in 7.2.1: MobileRTCMeetingServiceDelegate no longer declares
// onBOCreateSuccess, onInMeetingUserUpdated, onMeetingReturn,
// onMyHandStateChange, onSinkLiveTranscriptionMsgReceived,
// onSinkMeetingActiveShare, onSinkMeetingActiveVideoForDeck or
// onVideoOrderUpdated. Implementing them compiled, but the SDK never called
// them -- so anything subscribed to those events waited forever with nothing to
// show it never would.
@end
