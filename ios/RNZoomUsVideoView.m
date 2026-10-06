//
//  RNZoomUsVideoView.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/11.
//
//

#import "RNZoomUsVideoView.h"
#import "RNZoomUsEvents.h"
#import "RNZoomUs.h"
#import "RCTEventEmitter.h"
#import "GlobalData.h"
@implementation RNZoomUsVideoView
BOOL hasObservers;
ProviderDelegate *providerDelegate;
CXCallController *callController;

- (instancetype)init
{
    self = [super init];
    //    providerDelegate = nil;
    //    callController = nil;
    providerDelegate = [[ProviderDelegate alloc] init];
    callController = [[CXCallController alloc] init];
    self.lastVideoStatusByUserID = [NSMutableDictionary dictionary];
    _rnZoomUsVideoViewController = [[CustomMeetingViewController alloc] init];
    // The controller's view is attached in -didMoveToWindow, once there is a
    // real parent view controller to attach it to. Adding it here would give it
    // self.bounds, which is CGRectZero before React Native assigns a frame.
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioRouteChanged:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)reactSetFrame:(CGRect)frame {
    [super reactSetFrame:frame];
}

- (void)dealloc
{
    NSLog(@"RNZoomUsVideoView onAICompanionFeatureCanNotBeTurnedOff");
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionRouteChangeNotification
                                                  object:nil];
    NSLog(@"Cleaned up RNZoomUsVideoView");
}
- (void)audioRouteChanged:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    AVAudioSessionRouteChangeReason reason = [userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    
    if (reason == AVAudioSessionRouteChangeReasonNewDeviceAvailable) {
        NSLog(@"RNZoomUsVideoView Headphones connected");
    } else if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        NSLog(@"RNZoomUsVideoView Headphones disconnected");
    }
    [self updateAudioOutput];
}
- (void)updateAudioOutput {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    [audioSession setActive:YES error:&error];
    if (error) {
        NSLog(@"RNZoomUsVideoView Error activating audio session: %@", error.localizedDescription);
        return;
    }
    
    AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
    BOOL isHeadphonesConnected = NO;
    for (AVAudioSessionPortDescription *output in currentRoute.outputs) {
        NSLog(@"RNZoomUsVideoView PortType: %@", output.portType );
        NSArray *headphoneTypes = @[AVAudioSessionPortHeadphones,
                                    AVAudioSessionPortBluetoothHFP,
                                    AVAudioSessionPortBluetoothLE,
                                    AVAudioSessionPortBluetoothA2DP];
        
        if ([headphoneTypes containsObject:output.portType]) {
            isHeadphonesConnected = YES;
            break;
        }
    }
    
    if (!isHeadphonesConnected) {
        [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        if (error) {
            BOOL isInmeeting = [[GlobalData sharedInstance] globalIsInMeeting];
//            if (isInmeeting) {
//                [self connectAudio];
//            }
            NSLog(@"RNZoomUsVideoView Error overriding to speaker: %@", error.localizedDescription);
        }
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];

    if (self.window == nil || _rnZoomUsVideoViewController == nil) return;

    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    if (ms) ms.delegate = self;

    [self addViewControllerAsSubView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    // Unconditionally track our bounds. The old code only resized the child
    // while a meeting service existed, so before joining -- and any time this
    // view was nested rather than full-screen -- the controller's view stayed
    // at CGRectZero and nothing was drawn.
    if (_rnZoomUsVideoViewController != nil) {
        _rnZoomUsVideoViewController.view.frame = self.bounds;
    }
}

- (void)removeFromSuperview {
    if (_rnZoomUsVideoViewController != nil) {
        [_rnZoomUsVideoViewController willMoveToParentViewController:nil];
        [_rnZoomUsVideoViewController.view removeFromSuperview];
        [_rnZoomUsVideoViewController removeFromParentViewController];
        _rnZoomUsVideoViewController = nil;
    }
    // Must run even when the controller was already torn down; the old code
    // kept this inside the branch, so a second removal left the view attached.
    [super removeFromSuperview];
}

// Proper UIViewController containment. Previously this method was empty and
// the controller's view was simply added as a subview in -init, so the
// controller never received viewWillAppear/viewDidAppear, rotation callbacks or
// safe-area insets. Zoom's meeting UI depends on that lifecycle, which is why
// the view only behaved when it happened to be the full-screen root.
-(void)addViewControllerAsSubView
{
    UIViewController *parent = [self reactViewController];
    if (parent == nil) return;
    if (_rnZoomUsVideoViewController.parentViewController == parent) return;

    if (_rnZoomUsVideoViewController.parentViewController != nil) {
        [_rnZoomUsVideoViewController willMoveToParentViewController:nil];
        [_rnZoomUsVideoViewController.view removeFromSuperview];
        [_rnZoomUsVideoViewController removeFromParentViewController];
    }

    [parent addChildViewController:_rnZoomUsVideoViewController];
    _rnZoomUsVideoViewController.view.frame = self.bounds;
    _rnZoomUsVideoViewController.view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_rnZoomUsVideoViewController.view];
    [_rnZoomUsVideoViewController didMoveToParentViewController:parent];
}

- (void)connectAudio {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    MobileRTCMeetingSettings *zoomSettings = [[MobileRTC sharedRTC] getMeetingSettings];
    
    if (!ms) return;
    [ms connectMyAudio: YES];
//    [ms resetMeetingAudioSession];
    //    [ms muteMyAudio: YES];
    //    [ms muteMyVideo: YES];
    NSLog(@"connectAudio");
}

- (void)resetAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    
    // Remove any audio port override
    [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    if (error) {
        NSLog(@"Error removing audio port override: %@", error.localizedDescription);
    }
    
    // Optionally reset the category and mode (can be customized based on your app needs)
    [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:&error];
    if (error) {
        NSLog(@"Error setting default category: %@", error.localizedDescription);
    }
    
    [audioSession setMode:AVAudioSessionModeDefault error:&error];
    if (error) {
        NSLog(@"Error setting default mode: %@", error.localizedDescription);
    }
    
    // Deactivate the audio session
    [audioSession setActive:NO error:&error];
    if (error) {
        NSLog(@"Error deactivating audio session: %@", error.localizedDescription);
    }
}


#pragma mark - Meeting Service Delegate
- (void)onMeetingStateChange:(MobileRTCMeetingState)state{
    RNZoomUsEmit(@"onMeetingStateChange", @{@"state": @(state)});
    NSLog(@"RNZoomUsVideoView onMeetingStateChange =>%@", @(state));
    NSString* result;
    switch(state) {
        case MobileRTCMeetingState_Idle:
            result = @"MEETING_STATUS_IDLE";
            break;
        case MobileRTCMeetingState_Connecting:
            result = @"MEETING_STATUS_CONNECTING";
//            if (providerDelegate.callingUUID == nil) {
//                NSUUID *callUUID = [NSUUID UUID];
//                
//                CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Học Viện Minh Trí Thành"]];
//                CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
//                callUpdate.remoteHandle = startCallAction.handle;
//                callUpdate.hasVideo = startCallAction.video;
//                CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
//                [callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
//                    if (error) {
//                        NSLog(@"Error requesting start call transaction: %@", error.localizedDescription);
//                        providerDelegate.callingUUID = nil;
//                    } else {
//                        NSLog(@"Requested start call transaction succeeded");
//                        NSLog(@"callUUID 1: %@", callUUID);
//                        providerDelegate.callingUUID = callUUID;
//                        NSLog(@"callUUID 2: %@", providerDelegate.callingUUID);
//                    }
//                }];
//            }
            break;
        case MobileRTCMeetingState_WaitingForHost:
            result = @"MEETING_STATUS_WAITINGFORHOST";
            break;
        case MobileRTCMeetingState_InMeeting:
            result = @"MEETING_STATUS_INMEETING";
            [self connectAudio];
            break;
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
            if (providerDelegate.callingUUID != nil) {
                NSLog(@"endCallUUID: %@", providerDelegate.callingUUID);
                CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:providerDelegate.callingUUID];
                CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
                [callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error requesting end call transaction: %@", error.localizedDescription);
                    } else {
                        NSLog(@"Requested end call transaction succeeded");
                        providerDelegate.callingUUID = nil;
                    }
                }];
            }
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
            break;
        case MobileRTCMeetingState_LeaveBO: // only iOS (guessed naming)
            result = @"MEETING_STATUS_LEAVE_BO";
            break;
            
        default:
            [NSException raise:NSGenericException format:@"Unexpected state."];
    }
    
    NSLog(@"RNZoomUsVideoView onMeetingStateChange =>%@", result);
    
    
    if (self.onMeetingStateChange) {
        self.onMeetingStateChange(@{
            @"event": @"success",
            @"status": result ?: [NSNull null]
        });
    }
}

- (void)onSinkMeetingActiveVideo:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingActiveVideo", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingActiveVideo =>>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}

- (void)onMyVideoStateChange {
    RNZoomUsEmit(@"onMyVideoStateChange", nil);
    NSLog(@"RNZoomUsVideoView onMyVideoStateChange");
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onMyVideoStateChange)])
    {
        [_rnZoomUsVideoViewController onMyVideoStateChange];
    }
}

- (void)onSpotlightVideoChange:(BOOL)on {
    RNZoomUsEmit(@"onSpotlightVideoChange", @{@"on": @(on)});}

- (void)onSinkMeetingPreviewStopped {
    RNZoomUsEmit(@"onSinkMeetingPreviewStopped", nil);
    NSLog(@"RNZoomUsVideoView onSinkMeetingPreviewStopped");
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingPreviewStopped)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingPreviewStopped];
    }
    if (self.onMeetingPreviewStopped) {
        self.onMeetingPreviewStopped(@{
            @"event": @"onMeetingPreviewStopped",
            @"status": @(NO)
        });
    }
}

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID videoStatus:(MobileRTC_VideoStatus)videoStatus{
    RNZoomUsEmit(@"onSinkMeetingVideoStatusChange", @{@"userID": @(userID), @"videoStatus": @(videoStatus)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingVideoStatusChange=%@, videoStatus=%@",@(userID), @(videoStatus));
    
    NSNumber *lastStatus = self.lastVideoStatusByUserID[@(userID)];
    if (lastStatus && [lastStatus integerValue] == videoStatus) {
        return;
    }
    self.lastVideoStatusByUserID[@(userID)] = @(videoStatus);
    
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isHostUser = [ms isHostUser:userID];
    BOOL isWebinarMeeting = [ms isWebinarMeeting];
    if (videoStatus == MobileRTC_VideoStatus_Video_ON) {
        
        //        [[GlobalData sharedInstance] setUserID:userID];
        if (isWebinarMeeting && !isHostUser) {
            return;
        }
        if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingVideoStatusChange:)])
        {
            [_rnZoomUsVideoViewController onSinkMeetingVideoStatusChange:userID];
        }
    }
    if (videoStatus == MobileRTC_VideoStatus_Video_OFF) {
        //        if (isWebinarMeeting) {
        //            NSUInteger globalWebinarFirstActiveVideoID = [[GlobalData sharedInstance] globalWebinarFirstActiveVideoID];
        //            if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingVideoStatusChange:)])
        //            {
        //                [_rnZoomUsVideoViewController onSinkMeetingVideoStatusChange:globalWebinarFirstActiveVideoID];
        //            }
        //        }
    }
    if (self.onSinkMeetingVideoStatusChange) {
        self.onSinkMeetingVideoStatusChange(@{
            @"event": @"onSinkMeetingVideoStatusChange",
            @"videoStatus": @(videoStatus)
        });
    }
}

- (void)onSinkMeetingActiveVideoForDeck:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingActiveVideoForDeck", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingActiveVideoForDeck =>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}

- (void)onSinkMeetingUserLeft:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserLeft", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingUserLeft==%@", @(userID));
    if (self.onSinkMeetingUserLeft) {
        self.onSinkMeetingUserLeft(@{
            @"event": @"userLeave",
            @"userList": @[@(userID)]
        });
    }
    [self countInMeetingUser];
}
- (void)onSinkMeetingUserJoin:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserJoin", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingUserJoin==%@", @(userID));
    if (self.onSinkMeetingUserJoin) {
        self.onSinkMeetingUserJoin(@{
            @"event": @"userJoin",
            @"userList": @[@(userID)]
        });
    }
    [self countInMeetingUser];
}

- (void)onSinkMeetingAudioRequestUnmuteByHost {
    RNZoomUsEmit(@"onSinkMeetingAudioRequestUnmuteByHost", nil);
    if (self.onMeetingAudioRequestUnmuteByHost) {
        self.onMeetingAudioRequestUnmuteByHost(@{
            @"event": @"REQUEST_AUDIO",
            @"status": @(YES)
        });
    }
}

- (void)onSinkMeetingVideoRequestUnmuteByHost:(MobileRTCSDKError (^)(BOOL))completion {
    RNZoomUsEmit(@"onSinkMeetingVideoRequestUnmuteByHost", nil);
    if (self.onMeetingVideoRequestUnmuteByHost) {
        self.onMeetingVideoRequestUnmuteByHost(@{
            @"event": @"REQUEST_VIDEO",
            @"status": @(YES)
        });
    }
}
- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingAudioStatusChange", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingAudioStatusChange=%@",@(userID));
}
- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID audioStatus:(MobileRTC_AudioStatus)audioStatus {
    RNZoomUsEmit(@"onSinkMeetingAudioStatusChange", @{@"userID": @(userID), @"audioStatus": @(audioStatus)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingAudioStatusChange=%@, audioStatus=%@",@(userID), @(audioStatus));
    
    if (self.onSinkMeetingAudioStatusChange) {
        self.onSinkMeetingAudioStatusChange(@{
            @"event": @"onSinkMeetingAudioStatusChange",
            @"audioStatus": @(audioStatus)
        });
    }
}

#pragma mark - In meeting users' state updated
- (void)onInMeetingUserUpdated
{
    RNZoomUsEmit(@"onInMeetingUserUpdated", nil);
    //    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    //    NSArray *users = [ms getInMeetingUserList];
    //    NSLog(@"RNZoomUsVideoView onInMeetingUserUpdated:%@", users);
    [self countInMeetingUser];
}

- (void)getCurrentActiveId {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isWebinarMeeting = [ms isWebinarMeeting];
    BOOL isViewingShare = [ms isViewingShare];
    if(isViewingShare) {
        [[GlobalData sharedInstance] setGlobalActiveShareID:[ms activeShareUserID]];
    } else {
        [[GlobalData sharedInstance] setUserID:[ms activeUserID]];
    }
}

- (void)onInMeetingUserAvatarPathUpdated:(NSInteger)userID {
    RNZoomUsEmit(@"onInMeetingUserAvatarPathUpdated", @{@"userID": @(userID)});
    [self getUserInfo:userID];
}

-(MobileRTCMeetingUserInfo* _Nullable)getUserInfo:(NSInteger)userID {
    NSLog(@"onInMeetingUserAvatarPathUpdated --- %s %ld",__FUNCTION__,userID);
    MobileRTCMeetingUserInfo *userInfo = [[[MobileRTC sharedRTC] getMeetingService] userInfoByID:userID];
    NSLog(@"onInMeetingUserAvatarPathUpdated --- userInfo avatarPath:%@",userInfo.avatarPath);
    return userInfo;
}

- (void)onChatMessageNotification:(MobileRTCMeetingChat * _Nullable)chatInfo;
{
    NSLog(@"RNZoomUsVideoView MobileRTCMeetingChat-->%@",chatInfo.content);
    if (self.onChatMessageNotification) {
        NSDictionary *chatInfoDict = nil;
        if (chatInfo) {
            //            MobileRTCMeetingUserInfo *userInfo = [self getUserInfo:chatInfo.chatId];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
            NSString *dateString = [dateFormatter stringFromDate:chatInfo.date];
            // Same nullable strings as RNZoomUs.m: a dictionary literal raises
            // when handed nil, and this runs inside an SDK callback.
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
        self.onChatMessageNotification(@{
            @"event": @"onChatMessageNotification",
            @"chatInfo": chatInfoDict ?: [NSNull null]
        });
    }
}

- (void)onChatMsgDeleteNotification:(NSString *_Nonnull)msgID deleteBy:(MobileRTCChatMessageDeleteType)deleteBy
{
    RNZoomUsEmit(@"onChatMsgDeleteNotification", @{@"msgID": msgID ?: [NSNull null], @"deleteBy": @(deleteBy)});
    NSLog(@"RNZoomUsVideoView onChatMsgDeleteNotification-->%@ deleteBy-->%@",msgID,@(deleteBy));
    
    if (self.onChatMsgDeleteNotification) {
        NSDictionary *chatInfoDict = nil;
        chatInfoDict = @{
            @"deleteBy": @(deleteBy),
            @"msgID": msgID ?: [NSNull null],
        };
        self.onChatMsgDeleteNotification(@{
            @"event": @"onChatMsgDeleteNotification",
            @"msgDelete": chatInfoDict ?: [NSNull null]
        });
    }
}

- (void)onSinkUserNameChanged:(NSArray <NSNumber *>* _Nullable)userNameChangedArr
{
    RNZoomUsEmit(@"onSinkUserNameChanged", @{@"userNameChangedArr": userNameChangedArr ?: @[]});
    NSLog(@"onSinkUserNameChanged:%@", userNameChangedArr);
}

- (void)onSinkMeetingUserRaiseHand:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserRaiseHand", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingUserRaiseHand==%@", @(userID));
}

- (void)onSinkMeetingUserLowerHand:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkMeetingUserLowerHand", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingUserLowerHand==%@", @(userID));
}

- (void)onMeetingHostChange:(NSUInteger)hostId {
    RNZoomUsEmit(@"onMeetingHostChange", @{@"hostId": @(hostId)});
    NSLog(@"RNZoomUsVideoView onMeetingHostChange==%@", @(hostId));
}

- (void)onMeetingCoHostChange:(NSUInteger)userID isCoHost:(BOOL)isCoHost {
    RNZoomUsEmit(@"onMeetingCoHostChange", @{@"userID": @(userID), @"isCoHost": @(isCoHost)});
    NSLog(@"RNZoomUsVideoView onMeetingCoHostChange==%@ isCoHost===%@", @(userID), @(isCoHost));
}

- (void)onClaimHostResult:(MobileRTCClaimHostError)error
{
    RNZoomUsEmit(@"onClaimHostResult", @{@"error": @(error)});
    NSLog(@"RNZoomUsVideoView onClaimHostResult==%@", @(error));
}

#pragma mark - BO MEETING

- (void)onHasCreatorRightsNotification:(MobileRTCBOCreator *_Nonnull)creator
{
    RNZoomUsEmit(@"onHasCreatorRightsNotification", @{@"creatorPresent": @(creator != nil)});
    NSLog(@"RNZoomUsVideoView Own Creator");
}

- (void)onHasAdminRightsNotification:(MobileRTCBOAdmin * _Nonnull)admin
{
    RNZoomUsEmit(@"onHasAdminRightsNotification", @{@"adminPresent": @(admin != nil)});
    NSLog(@"RNZoomUsVideoView Own Admin");
}

- (void)onHasAssistantRightsNotification:(MobileRTCBOAssistant * _Nonnull)assistant
{
    RNZoomUsEmit(@"onHasAssistantRightsNotification", @{@"assistantPresent": @(assistant != nil)});
    NSLog(@"RNZoomUsVideoView Own Assistant");
}

- (void)onHasAttendeeRightsNotification:(MobileRTCBOAttendee * _Nonnull)attendee
{
    RNZoomUsEmit(@"onHasAttendeeRightsNotification", @{@"attendeePresent": @(attendee != nil)});
    NSString *boName = [attendee getBOName];
    
    if (self.onHasAttendeeRightsNotification) {
        self.onHasAttendeeRightsNotification(@{
            @"event": @"onHasAttendeeRightsNotification",
            @"boName": boName ?: [NSNull null]
        });
    }
    NSLog(@"RNZoomUsVideoView Own Attendee");
}

- (void)onHasDataHelperRightsNotification:(MobileRTCBOData * _Nonnull)dataHelper
{
    RNZoomUsEmit(@"onHasDataHelperRightsNotification", @{@"dataHelperPresent": @(dataHelper != nil)});
    NSLog(@"RNZoomUsVideoView Own Data Helper");
}

- (void)onLostCreatorRightsNotification
{
    RNZoomUsEmit(@"onLostCreatorRightsNotification", nil);
    NSLog(@"RNZoomUsVideoView Lost Creator");
}

- (void)onLostAdminRightsNotification;
{
    NSLog(@"RNZoomUsVideoView Lost Admin");
}

- (void)onLostAssistantRightsNotification
{
    RNZoomUsEmit(@"onLostAssistantRightsNotification", nil);
    NSLog(@"RNZoomUsVideoView Lost Assistant");
}

- (void)onLostAttendeeRightsNotification
{
    RNZoomUsEmit(@"onLostAttendeeRightsNotification", nil);
    NSLog(@"RNZoomUsVideoView Lost Attendee");
}

- (void)onNewBroadcastMessageReceived:(NSString *_Nullable)broadcastMsg senderID:(NSUInteger)senderID {
    NSLog(@"RNZoomUsVideoView Broadcast Message Received:%@ senderID:%@", broadcastMsg, @(senderID));
}

- (void)onBOStopCountDown:(NSUInteger)seconds
{
    RNZoomUsEmit(@"onBOStopCountDown", @{@"seconds": @(seconds)});
    NSLog(@"RNZoomUsVideoView onBOStopCountDown:%@", @(seconds));
}

- (void)onHostInviteReturnToMainSession:(NSString *_Nullable)hostName replyHandler:(MobileRTCReturnToMainSessionHandler *_Nullable)replyHandler
{
    RNZoomUsEmit(@"onHostInviteReturnToMainSession", @{@"hostName": hostName ?: [NSNull null], @"replyHandlerPresent": @(replyHandler != nil)});
    NSLog(@"RNZoomUsVideoView onHostInviteReturnToMainSession hostName=:%@, replyHandler=:%p", hostName, replyHandler);
}

- (void)onBOStatusChanged:(MobileRTCBOStatus)status
{
    RNZoomUsEmit(@"onBOStatusChanged", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onBOStatusChanged status=:%@", @(status));
    NSString* result;
    switch(status) {
        case MobileRTCBOStatus_Invalid:
            result = @"MobileRTCBOStatus_Invalid";
            break;
        case MobileRTCBOStatus_Edit:
            result = @"MobileRTCBOStatus_Edit";
            break;
        case MobileRTCBOStatus_Started:
            result = @"MobileRTCBOStatus_Started";
            break;
        case MobileRTCBOStatus_Stopping:
            result = @"MobileRTCBOStatus_Stopping";
            break;
        case MobileRTCBOStatus_Ended:
            result = @"MobileRTCBOStatus_Ended";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected state."];
    }
    if (self.onBOStatusChanged) {
        self.onBOStatusChanged(@{
            @"event": @"success",
            @"status": result ?: [NSNull null]
        });
    }
}

- (void)onBOSwitchRequestReceived:(NSString*)newBOName newBOID:(NSString*)newBOID {
    RNZoomUsEmit(@"onBOSwitchRequestReceived", @{@"newBOName": newBOName ?: [NSNull null], @"newBOID": newBOID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onBOSwitchRequestReceived newBOName=:%@ newBOID=:%@", newBOName, newBOID);
}

- (void)onLostDataHelperRightsNotification
{
    RNZoomUsEmit(@"onLostDataHelperRightsNotification", nil);
    NSLog(@"RNZoomUsVideoView Lost DataHelper");
}

- (void)onHelpRequestReceived:(NSString *_Nullable)strUserID {
    RNZoomUsEmit(@"onHelpRequestReceived", @{@"strUserID": strUserID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView help request received from %@", strUserID);
}

- (void)onHelpRequestHandleResultReceived:(MobileRTCBOHelpReply)eResult {
    RNZoomUsEmit(@"onHelpRequestHandleResultReceived", @{@"eResult": @(eResult)});
    NSString *replyStatus = @"";
    switch (eResult) {
        case MobileRTCBOHelpReply_Idle: {
            replyStatus = @"Idle";
        } break;
        case MobileRTCBOHelpReply_Busy: {
            replyStatus = @"Busy";
        } break;
        case MobileRTCBOHelpReply_Ignore: {
            replyStatus = @"Ignore";
        } break;
        case MobileRTCBOHelpReply_alreadyInBO: {
            replyStatus = @"alreadyInBO";
        } break;
        default: break;
    }
    NSLog(@"RNZoomUsVideoView help request replied: %@", replyStatus);
}

- (void)onHostJoinedThisBOMeeting {
    RNZoomUsEmit(@"onHostJoinedThisBOMeeting", nil);
    NSLog(@"RNZoomUsVideoView Host has joined this BO");
}

- (void)onHostLeaveThisBOMeeting {
    RNZoomUsEmit(@"onHostLeaveThisBOMeeting", nil);
    NSLog(@"RNZoomUsVideoView Host has left this BO");
}

- (void)onBOInfoUpdated:(NSString *_Nullable)boId;
{
    NSLog(@"RNZoomUsVideoView BO info updated");
}

- (void)onUnAssignedUserUpdated
{
    RNZoomUsEmit(@"onUnAssignedUserUpdated", nil);
    NSLog(@"RNZoomUsVideoView un-assigned user updated");
}

- (void)onBOListInfoUpdated
{
    RNZoomUsEmit(@"onBOListInfoUpdated", nil);
    NSLog(@"RNZoomUsVideoView onBOListInfoUpdated");
}

- (void)onStartBOError:(MobileRTCBOControllerError)errType {
    RNZoomUsEmit(@"onStartBOError", @{@"errType": @(errType)});
    NSLog(@"RNZoomUsVideoView admin start bo error: %@", @(errType));
}

- (void)onBOEndTimerUpdated:(NSUInteger)remaining isTimesUpNotice:(BOOL)isTimesUpNotice {
    RNZoomUsEmit(@"onBOEndTimerUpdated", @{@"remaining": @(remaining), @"isTimesUpNotice": @(isTimesUpNotice)});
    NSLog(@"RNZoomUsVideoView admin bo %lu seconds left, isTimesUpNotice: %@", remaining, isTimesUpNotice ? @"Y" : @"N");
}

- (void)onBOCreateSuccess:(NSString *_Nullable)BOID {
    RNZoomUsEmit(@"onBOCreateSuccess", @{@"BOID": BOID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView creator create success ret bo_id: %@", BOID);
}

- (void)onWebPreAssignBODataDownloadStatusChanged:(MobileRTCBOPreAssignBODataStatus)status {
    RNZoomUsEmit(@"onWebPreAssignBODataDownloadStatusChanged", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onWebPreAssignBODataDownloadStatusChanged: %@", @(status));
}

#pragma mark - SHARING

- (void)onSharingContentStartReceiving {
    NSLog(@"RNZoomUsVideoView onSharingContentStartReceiving");
}

- (void)onSinkSharingStatus:(MobileRTCSSharingSourceInfo*_Nonnull)shareInfo
{
    RNZoomUsEmit(@"onSinkSharingStatus", @{@"shareInfoPresent": @(shareInfo != nil)});
    MobileRTCSharingStatus status = [shareInfo getStatus];
    NSInteger userID = [shareInfo getUserID];
    NSInteger shareSourceID = [shareInfo getShareSourceID];
    NSLog(@"--- %s status:%@",__FUNCTION__,shareInfo.description);
    NSLog(@"RNZoomUsVideoView onSinkSharingStatus==%@ userID==%@", @(status),@(userID));
    
    
    switch (status) {
        case MobileRTCSharingStatus_Other_Share_Begin:
            [[GlobalData sharedInstance] setGlobalActiveShareID:userID];
            break;
            
        default:
            break;
    }
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkSharingStatus:userID:)])
    {
        [_rnZoomUsVideoViewController onSinkSharingStatus:shareInfo];
    }
}

- (void)onSinkShareSizeChange:(NSUInteger)userID {
    RNZoomUsEmit(@"onSinkShareSizeChange", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkShareSizeChange==%@",@(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkShareSizeChange:)])
    {
        [_rnZoomUsVideoViewController onSinkShareSizeChange: userID];
    }
}

- (void)onAppShareSplash{
    RNZoomUsEmit(@"onAppShareSplash", nil);
    NSLog(@"RNZoomUsVideoView onAppShareSplash");
}

- (void)onAudioOutputChange {
    RNZoomUsEmit(@"onAudioOutputChange", nil);
    NSLog(@"RNZoomUsVideoView onAudioOutputChange");
}

- (void)onActionBeforeDestroyed:(NSUInteger)sharingID {
    NSLog(@"RNZoomUsVideoView onActionBeforeDestroyed==%@",@(sharingID));
}

- (void)onAllowAskQuestionStatus:(BOOL)bEnabled {
    RNZoomUsEmit(@"onAllowAskQuestionStatus", @{@"bEnabled": @(bEnabled)});
    NSLog(@"RNZoomUsVideoView onAllowAskQuestionStatus==%@",@(bEnabled));
}

- (void)onAskToEndOtherMeeting:(void (^)(BOOL))completion {
    RNZoomUsEmit(@"onAskToEndOtherMeeting", nil);
    NSLog(@"RNZoomUsVideoView onAskToEndOtherMeeting");
}

- (void)onAvailableLanguageListUpdated:(NSArray<MobileRTCInterpretationLanguage *> *)availableLanguageList {
    RNZoomUsEmit(@"onAvailableLanguageListUpdated", @{@"availableLanguageListPresent": @(availableLanguageList != nil)});
    NSLog(@"RNZoomUsVideoView onAvailableLanguageListUpdated");
}

- (void)onAllowParticipantsRenameNotification:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsRenameNotification", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsRenameNotification==%@",@(allow));
}
- (void)onAICompanionActiveChangeNotice:(BOOL)isActive {
    RNZoomUsEmit(@"onAICompanionActiveChangeNotice", @{@"isActive": @(isActive)});
    NSLog(@"RNZoomUsVideoView onAICompanionActiveChangeNotice==%@",@(isActive));
}

- (void)onAvailableSignLanguageListUpdated:(NSArray<MobileRTCSignInterpreterLanguage *> *)availableSignLanguageList {
    RNZoomUsEmit(@"onAvailableSignLanguageListUpdated", @{@"availableSignLanguageListPresent": @(availableSignLanguageList != nil)});
    NSLog(@"RNZoomUsVideoView onAvailableSignLanguageListUpdated");
}
- (void)onAICompanionFeatureSwitchRequested:(MobileRTCAICompanionSwitchHandler *)handler {
    RNZoomUsEmit(@"onAICompanionFeatureSwitchRequested", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onAICompanionFeatureSwitchRequested");
}

- (void)onAllowWebinarReactionStatusChanged:(BOOL)canReaction {
    RNZoomUsEmit(@"onAllowWebinarReactionStatusChanged", @{@"canReaction": @(canReaction)});
    NSLog(@"RNZoomUsVideoView onAllowWebinarReactionStatusChanged");
}

- (void)onAllowParticipantsRequestCloudRecording:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsRequestCloudRecording", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsRequestCloudRecording");
}

- (void)onAllowParticipantsStartVideoNotification:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsStartVideoNotification", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsStartVideoNotification");
}

- (void)onAllowParticipantsUnmuteSelfNotification:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsUnmuteSelfNotification", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsUnmuteSelfNotification");
}

- (void)onAllowParticipantsShareStatusNotification:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsShareStatusNotification", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsShareStatusNotification");
}

- (void)onAllowAttendeeRaiseHandStatusChanged:(BOOL)canRaiseHand {
    RNZoomUsEmit(@"onAllowAttendeeRaiseHandStatusChanged", @{@"canRaiseHand": @(canRaiseHand)});
    NSLog(@"RNZoomUsVideoView onAllowAttendeeRaiseHandStatusChanged");
}

- (void)onAnnotationService:(MobileRTCAnnotationService *)service supportStatusChanged:(BOOL)support {
    NSLog(@"RNZoomUsVideoView onAnnotationService");
}

- (void)onAllowParticipantsShareWhiteBoardNotification:(BOOL)allow {
    RNZoomUsEmit(@"onAllowParticipantsShareWhiteBoardNotification", @{@"allow": @(allow)});
    NSLog(@"RNZoomUsVideoView onAllowParticipantsShareWhiteBoardNotification");
}

- (void)onAICompanionFeatureTurnOffByParticipant:(MobileRTCAICompanionTurnOnAgainHandler *)handler {
    RNZoomUsEmit(@"onAICompanionFeatureTurnOffByParticipant", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onAICompanionFeatureTurnOffByParticipant");
}

- (void)onAICompanionFeatureCanNotBeTurnedOff:(NSArray<NSNumber *> *)featuresArr {
    RNZoomUsEmit(@"onAICompanionFeatureCanNotBeTurnedOff", @{@"featuresArr": featuresArr ?: @[]});
    NSLog(@"RNZoomUsVideoView onAICompanionFeatureCanNotBeTurnedOff");
}

- (void)onAllowAttendeeViewTheParticipantCountStatusChanged:(BOOL)canViewParticipantCount {
    RNZoomUsEmit(@"onAllowAttendeeViewTheParticipantCountStatusChanged", @{@"canViewParticipantCount": @(canViewParticipantCount)});
    NSLog(@"RNZoomUsVideoView onAllowAttendeeViewTheParticipantCountStatusChanged");
}
- (void)onAICompanionFeatureSwitchRequestResponse:(BOOL)timeout agree:(BOOL)agree turn:(BOOL)turnOn {
    RNZoomUsEmit(@"onAICompanionFeatureSwitchRequestResponse", @{@"timeout": @(timeout), @"agree": @(agree), @"turnOn": @(turnOn)});
    NSLog(@"RNZoomUsVideoView onAICompanionFeatureSwitchRequestResponse");
    
}
- (void)onBOOptionChanged:(MobileRTCBOOption *)newOption {
    RNZoomUsEmit(@"onBOOptionChanged", @{@"newOptionPresent": @(newOption != nil)});
    NSLog(@"RNZoomUsVideoView onBOOptionChanged");
}
- (void)onBroadcastBOVoiceStatus:(BOOL)bStart {
    RNZoomUsEmit(@"onBroadcastBOVoiceStatus", @{@"bStart": @(bStart)});
    NSLog(@"RNZoomUsVideoView onBroadcastBOVoiceStatus");
}
- (void)onCameraNoPrivilege {
    RNZoomUsEmit(@"onCameraNoPrivilege", nil);
    NSLog(@"RNZoomUsVideoView onCameraNoPrivilege");
}
- (void)onClickShareScreen:(UIViewController *)parentVC {
    RNZoomUsEmit(@"onClickShareScreen", @{@"parentVCPresent": @(parentVC != nil)});
    NSLog(@"RNZoomUsVideoView onClickShareScreen");
}
- (void)onCheckCMRPrivilege:(MobileRTCCMRError)result {
    RNZoomUsEmit(@"onCheckCMRPrivilege", @{@"result": @(result)});
    NSLog(@"RNZoomUsVideoView onCheckCMRPrivilege");
}
- (void)onCaptionStatusChanged:(BOOL)enable {
    RNZoomUsEmit(@"onCaptionStatusChanged", @{@"enable": @(enable)});
    NSLog(@"RNZoomUsVideoView onCaptionStatusChanged");
}

- (void)onCloudRecordingStorageFull:(long)gracePeriodDate {
    RNZoomUsEmit(@"onCloudRecordingStorageFull", @{@"gracePeriodDate": @(gracePeriodDate)});
    NSLog(@"RNZoomUsVideoView onCloudRecordingStorageFull");
}

- (void)onCallRoomDeviceStateChanged:(H323CallOutStatus)state {
    RNZoomUsEmit(@"onCallRoomDeviceStateChanged", @{@"state": @(state)});
    NSLog(@"RNZoomUsVideoView onCallRoomDeviceStateChanged");
}
- (void)onCustomWaitingRoomDataUpdated:(MobileRTCCustomWaitingRoomData *)data {
    NSLog(@"RNZoomUsVideoView onCustomWaitingRoomDataUpdated");
}

- (void)onClickedDialOut:(UIViewController *)parentVC isCallMe:(BOOL)me {
    RNZoomUsEmit(@"onClickedDialOut", @{@"parentVCPresent": @(parentVC != nil), @"me": @(me)});
    NSLog(@"RNZoomUsVideoView onClickedDialOut");
}

- (void)onClosedCaptionReceived:(NSString *)message speakerId:(NSUInteger)speakerID msgTime:(NSDate *)msgTime {
    RNZoomUsEmit(@"onClosedCaptionReceived", @{@"message": message ?: [NSNull null], @"speakerID": @(speakerID), @"msgTimePresent": @(msgTime != nil)});
    NSLog(@"RNZoomUsVideoView onClosedCaptionReceived");
}
- (void)onDialOutStatusChanged:(DialOutStatus)status {
    RNZoomUsEmit(@"onDialOutStatusChanged", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onDialOutStatusChanged");
}
- (void)onEmojiFeedbackCanceled:(NSUInteger)userId {
    RNZoomUsEmit(@"onEmojiFeedbackCanceled", @{@"userId": @(userId)});
    NSLog(@"RNZoomUsVideoView onEmojiFeedbackCanceled");
}
- (void)onE2EEMeetingSecurityCodeChanged {
    RNZoomUsEmit(@"onE2EEMeetingSecurityCodeChanged", nil);
    NSLog(@"RNZoomUsVideoView onE2EEMeetingSecurityCodeChanged");
}
- (void)onEmojiReactionReceivedInWebinar:(MobileRTCEmojiReactionType)type{
    RNZoomUsEmit(@"onEmojiReactionReceivedInWebinar", @{@"type": @(type)});
    NSLog(@"RNZoomUsVideoView onEmojiReactionReceivedInWebinar");
}
- (void)onEmojiFeedbackReceived:(NSUInteger)userId feedbackType:(MobileRTCEmojiFeedbackType)type {
    RNZoomUsEmit(@"onEmojiFeedbackReceived", @{@"userId": @(userId), @"type": @(type)});
    NSLog(@"RNZoomUsVideoView onEmojiFeedbackReceived");
}

- (void)onEmojiReactionReceived:(NSUInteger)userId reactionType:(MobileRTCEmojiReactionType)type reactionSkinTone:(MobileRTCEmojiReactionSkinTone)skinTone {
    RNZoomUsEmit(@"onEmojiReactionReceived", @{@"userId": @(userId), @"type": @(type), @"skinTone": @(skinTone)});
    NSLog(@"RNZoomUsVideoView onEmojiReactionReceived");
}

- (void)onFileReceived:(MobileRTCFileReceiver *)receiver{
    RNZoomUsEmit(@"onFileReceived", @{@"receiverPresent": @(receiver != nil)});
    NSLog(@"RNZoomUsVideoView onFileReceived");
}
- (void)onFileSendStart:(MobileRTCFileSender *)sender{
    RNZoomUsEmit(@"onFileSendStart", @{@"senderPresent": @(sender != nil)});
    NSLog(@"RNZoomUsVideoView onFileSendStart");
}
- (void)onFileTransferProgress:(MobileRTCFileTransferInfo *)info{
    RNZoomUsEmit(@"onFileTransferProgress", @{@"infoPresent": @(info != nil)});
    NSLog(@"RNZoomUsVideoView onFileTransferProgress");
}
- (void)onFocusModeStateChanged:(BOOL)on{
    RNZoomUsEmit(@"onFocusModeStateChanged", @{@"on": @(on)});
    NSLog(@"RNZoomUsVideoView onFocusModeStateChanged");
}
- (void)onFocusModeShareTypeChanged:(MobileRTCFocusModeShareType)shareType{
    RNZoomUsEmit(@"onFocusModeShareTypeChanged", @{@"shareType": @(shareType)});
    NSLog(@"RNZoomUsVideoView onFocusModeShareTypeChanged");
}
- (void)onFollowHostVideoOrderChanged:(BOOL)follow {
    RNZoomUsEmit(@"onFollowHostVideoOrderChanged", @{@"follow": @(follow)});
    NSLog(@"RNZoomUsVideoView onFollowHostVideoOrderChanged");
}
- (void)onFreeMeetingUpgradedToProMeeting {
    RNZoomUsEmit(@"onFreeMeetingUpgradedToProMeeting", nil);
    NSLog(@"RNZoomUsVideoView onFreeMeetingUpgradedToProMeeting");
}
- (void)onFreeMeetingUpgradeToGiftFreeTrialStop {
    RNZoomUsEmit(@"onFreeMeetingUpgradeToGiftFreeTrialStop", nil);
    NSLog(@"RNZoomUsVideoView onFreeMeetingUpgradeToGiftFreeTrialStop");
}
- (void)onFreeMeetingUpgradeToGiftFreeTrialStart {
    RNZoomUsEmit(@"onFreeMeetingUpgradeToGiftFreeTrialStart", nil);
    NSLog(@"RNZoomUsVideoView onFreeMeetingUpgradeToGiftFreeTrialStart");
}
- (void)onFreeMeetingNeedToUpgrade:(FreeMeetingNeedUpgradeType)type giftUpgradeURL:(NSString *)giftURL {
    RNZoomUsEmit(@"onFreeMeetingNeedToUpgrade", @{@"type": @(type), @"giftURL": giftURL ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onFreeMeetingNeedToUpgrade");
}
- (void)onGetRightAnswerListPrivilege:(BOOL)bCan {
    RNZoomUsEmit(@"onGetRightAnswerListPrivilege", @{@"bCan": @(bCan)});
    NSLog(@"RNZoomUsVideoView onGetRightAnswerListPrivilege");
}
- (void)onHostVideoOrderUpdated:(NSArray<NSNumber *> *)orderArr {
    RNZoomUsEmit(@"onHostVideoOrderUpdated", @{@"orderArr": orderArr ?: @[]});
    NSLog(@"RNZoomUsVideoView onHostVideoOrderUpdated");
}
- (void)onInterpretationStop{
    RNZoomUsEmit(@"onInterpretationStop", nil);
    NSLog(@"RNZoomUsVideoView onInterpretationStop");
}
- (void)onInterpretationStart{
    RNZoomUsEmit(@"onInterpretationStart", nil);
    NSLog(@"RNZoomUsVideoView onInterpretationStart");
}
- (void)onInterpreterListChanged{
    RNZoomUsEmit(@"onInterpreterListChanged", nil);
    NSLog(@"RNZoomUsVideoView onInterpreterListChanged");
}
- (void)onInterpreterLanguagesUpdated:(NSArray<MobileRTCInterpretationLanguage *> *)availableLanguages{
    RNZoomUsEmit(@"onInterpreterLanguagesUpdated", @{@"availableLanguagesPresent": @(availableLanguages != nil)});
    NSLog(@"RNZoomUsVideoView onInterpreterLanguagesUpdated");
}
- (void)onInterpreterRoleChanged:(NSUInteger)userID isInterpreter:(BOOL)isInterpreter{
    RNZoomUsEmit(@"onInterpreterRoleChanged", @{@"userID": @(userID), @"isInterpreter": @(isInterpreter)});
    NSLog(@"RNZoomUsVideoView onInterpreterRoleChanged");
}
- (void)onInterpreterLanguageChanged:(NSInteger)lanID1 andLanguage2:(NSInteger)lanID2{
    RNZoomUsEmit(@"onInterpreterLanguageChanged", @{@"lanID1": @(lanID1), @"lanID2": @(lanID2)});
    NSLog(@"RNZoomUsVideoView onInterpreterLanguageChanged");
}
- (void)onInterpreterActiveLanguageChanged:(NSInteger)userID activeLanguageId:(NSInteger)activeLanID{
    RNZoomUsEmit(@"onInterpreterActiveLanguageChanged", @{@"userID": @(userID), @"activeLanID": @(activeLanID)});
    NSLog(@"RNZoomUsVideoView onInterpreterActiveLanguageChanged");
}
- (void)onJoinMeetingConfirmed{
    RNZoomUsEmit(@"onJoinMeetingConfirmed", nil);
    NSLog(@"RNZoomUsVideoView onJoinMeetingConfirmed");
}
- (void)onJBHWaitingWithCmd:(JBHCmd)cmd{
    RNZoomUsEmit(@"onJBHWaitingWithCmd", @{@"cmd": @(cmd)});
    NSLog(@"RNZoomUsVideoView onJBHWaitingWithCmd");
}
- (void)onJoinMeetingNeedUserInfo:(MobileRTCInputUserInfoHandler *)handler{
    RNZoomUsEmit(@"onJoinMeetingNeedUserInfo", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onJoinMeetingNeedUserInfo");
}
- (void)onJoinMeetingInfo:(MobileRTCJoinMeetingInfo)info completion:(void (^)(NSString * _Nonnull, NSString * _Nonnull, BOOL))completion{
    RNZoomUsEmit(@"onJoinMeetingInfo", nil);
    NSLog(@"RNZoomUsVideoView onJoinMeetingInfo");
}
- (void)onLiveStreamStatusChange:(MobileRTCLiveStreamStatus)liveStreamStatus{
    RNZoomUsEmit(@"onLiveStreamStatusChange", @{@"liveStreamStatus": @(liveStreamStatus)});
    NSLog(@"RNZoomUsVideoView onLiveStreamStatusChange");
}
- (void)onLocalVideoOrderUpdated:(NSArray<NSNumber *> *)localOrderArr{
    RNZoomUsEmit(@"onLocalVideoOrderUpdated", @{@"localOrderArr": localOrderArr ?: @[]});
    NSLog(@"RNZoomUsVideoView onLocalVideoOrderUpdated");
}
- (void)onLocalRecordingStatus:(NSInteger)userId status:(MobileRTCRecordingStatus)status{
    RNZoomUsEmit(@"onLocalRecordingStatus", @{@"userId": @(userId), @"status": @(status)});
    NSLog(@"RNZoomUsVideoView onLocalRecordingStatus");
}
- (void)onLiveTranscriptionMsgInfoReceived:(MobileRTCLiveTranscriptionMessageInfo *)messageInfo{
    RNZoomUsEmit(@"onLiveTranscriptionMsgInfoReceived", @{@"messageInfoPresent": @(messageInfo != nil)});
    NSLog(@"RNZoomUsVideoView onLiveTranscriptionMsgInfoReceived");
}
- (void)onLiveTranscriptionMsgError:(MobileRTCLiveTranscriptionLanguage *)speakLanguage transcriptLanguage:(MobileRTCLiveTranscriptionLanguage *)transcriptLanguage{
    RNZoomUsEmit(@"onLiveTranscriptionMsgError", @{@"speakLanguagePresent": @(speakLanguage != nil), @"transcriptLanguagePresent": @(transcriptLanguage != nil)});
    NSLog(@"RNZoomUsVideoView onLiveTranscriptionMsgError");
}
- (void)onMeetingReady{
    RNZoomUsEmit(@"onMeetingReady", nil);
    NSLog(@"RNZoomUsVideoView onMeetingReady");
}
- (void)onMicrophoneNoPrivilege{
    RNZoomUsEmit(@"onMicrophoneNoPrivilege", nil);
    NSLog(@"RNZoomUsVideoView onMicrophoneNoPrivilege");
}
- (void)onMyHandStateChange{
    RNZoomUsEmit(@"onMyHandStateChange", nil);
    NSLog(@"RNZoomUsVideoView onMyHandStateChange");
}
- (void)onMeetingLockStatus:(BOOL)isLock {
    RNZoomUsEmit(@"onMeetingLockStatus", @{@"isLock": @(isLock)});
    NSLog(@"RNZoomUsVideoView onMeetingLockStatus");
}

- (void)onMyAudioStateChange {
    RNZoomUsEmit(@"onMyAudioStateChange", nil);
    NSLog(@"RNZoomUsVideoView onMyAudioStateChange");
}
- (void)onMeetingEndedReason:(MobileRTCMeetingEndReason)reason{
    RNZoomUsEmit(@"onMeetingEndedReason", @{@"reason": @(reason)});
    NSLog(@"RNZoomUsVideoView onMeetingEndedReason");
}
- (void)onMobileRTCAuthExpired{
    NSLog(@"RNZoomUsVideoView onMobileRTCAuthExpired");
}
- (void)onMicrophoneStatusError:(MobileRTCMicrophoneError)error{
    RNZoomUsEmit(@"onMicrophoneStatusError", @{@"error": @(error)});
    NSLog(@"RNZoomUsVideoView onMicrophoneStatusError");
}
- (void)onMobileRTCAuthReturn:(MobileRTCAuthError)returnValue{
    NSLog(@"RNZoomUsVideoView onMobileRTCAuthReturn");
}
- (void)onMeetingParameterNotification:(MobileRTCMeetingParameter *)meetingParam{
    RNZoomUsEmit(@"onMeetingParameterNotification", @{@"meetingParamPresent": @(meetingParam != nil)});
    NSLog(@"RNZoomUsVideoView onMeetingParameterNotification");
}
//- (void)onMeetingError:(MobileRTCMeetError)error message:(NSString *)message{
//    NSLog(@"RNZoomUsVideoView onMeetingError");
//}
- (void)onMobileRTCLoginResult:(MobileRTCLoginFailReason)resultValue{
    NSLog(@"RNZoomUsVideoView onMobileRTCLoginResult");
}
- (void)onMobileRTCLogoutReturn:(NSInteger)returnValue{
    NSLog(@"RNZoomUsVideoView onMobileRTCLogoutReturn");
}
- (void)onMeetingQAStatusChanged:(BOOL)isMeetingQAFeatureOn{
    RNZoomUsEmit(@"onMeetingQAStatusChanged", @{@"isMeetingQAFeatureOn": @(isMeetingQAFeatureOn)});
    NSLog(@"RNZoomUsVideoView onMeetingQAStatusChanged");
}
- (void)onNoHostMeetingWillTerminate:(NSUInteger)minutes{
    RNZoomUsEmit(@"onNoHostMeetingWillTerminate", @{@"minutes": @(minutes)});
    NSLog(@"RNZoomUsVideoView onNoHostMeetingWillTerminate");
}
- (void)onNotificationServiceStatus:(MobileRTCNotificationServiceStatus)status error:(MobileRTCNotificationServiceError)error{
    NSLog(@"RNZoomUsVideoView onNotificationServiceStatus");
}
- (void)onNewBroadcastMessageReceived:(NSString *)broadcastMsg senderID:(NSUInteger)senderID senderName:(NSString *)senderName {
    RNZoomUsEmit(@"onNewBroadcastMessageReceived", @{@"broadcastMsg": broadcastMsg ?: [NSNull null], @"senderID": @(senderID), @"senderName": senderName ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onNewBroadcastMessageReceived");
}
- (void)onOngoingShareStopped {
    RNZoomUsEmit(@"onOngoingShareStopped", nil);
    NSLog(@"RNZoomUsVideoView onOngoingShareStopped");
}
- (void)onOriginalLanguageMsgReceived:(MobileRTCLiveTranscriptionMessageInfo *)messageInfo {
    RNZoomUsEmit(@"onOriginalLanguageMsgReceived", @{@"messageInfoPresent": @(messageInfo != nil)});
    NSLog(@"RNZoomUsVideoView onOriginalLanguageMsgReceived");
}
- (void)onPollingInactive {
    RNZoomUsEmit(@"onPollingInactive", nil);
    NSLog(@"RNZoomUsVideoView onPollingInactive");
}

- (void)onPollingListUpdated {
    RNZoomUsEmit(@"onPollingListUpdated", nil);
    NSLog(@"RNZoomUsVideoView onPollingListUpdated");
}
- (void)onPollingResultUpdated:(NSString *)pollingID{
    RNZoomUsEmit(@"onPollingResultUpdated", @{@"pollingID": pollingID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onPollingResultUpdated");
}
- (void)onPollingStatusChanged:(NSString *)pollingID status:(MobileRTCPollingStatus)status {
    RNZoomUsEmit(@"onPollingStatusChanged", @{@"pollingID": pollingID ?: [NSNull null], @"status": @(status)});
    NSLog(@"RNZoomUsVideoView onPollingStatusChanged");
}
- (void)onProxyAuth:(NSString *)host port:(NSUInteger)port completion:(void (^)(NSString * _Nonnull, NSUInteger, NSString * _Nonnull, NSString * _Nonnull, BOOL))completion {
    RNZoomUsEmit(@"onProxyAuth", nil);
    NSLog(@"RNZoomUsVideoView onProxyAuth");
}
- (void)onParticipantProfilePictureStatusChange:(BOOL)hidden {
    RNZoomUsEmit(@"onParticipantProfilePictureStatusChange", @{@"hidden": @(hidden)});
    NSLog(@"RNZoomUsVideoView onParticipantProfilePictureStatusChange");
}
- (void)onPollingElapsedTime:(NSString *)pollingID uElapsedtime:(int)uElapsedtime {
    RNZoomUsEmit(@"onPollingElapsedTime", @{@"pollingID": pollingID ?: [NSNull null], @"uElapsedtime": @(uElapsedtime)});
    NSLog(@"RNZoomUsVideoView onPollingElapsedTime");
}
- (void)onPollingQuestionImageDownloaded:(NSString *)questionID path:(NSString *)path {
    RNZoomUsEmit(@"onPollingQuestionImageDownloaded", @{@"questionID": questionID ?: [NSNull null], @"path": path ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onPollingQuestionImageDownloaded");
}
- (void)onPollingActionResult:(MobileRTCPollingActionType)actionType pollingID:(NSString *)pollingID bSuccess:(BOOL)bSuccess errorMsg:(NSString *)errorMsg {
    RNZoomUsEmit(@"onPollingActionResult", @{@"actionType": @(actionType), @"pollingID": pollingID ?: [NSNull null], @"bSuccess": @(bSuccess), @"errorMsg": errorMsg ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onPollingActionResult");
}
- (void)onRecordingStatus:(MobileRTCRecordingStatus)status {
    RNZoomUsEmit(@"onRecordingStatus", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onRecordingStatus");
}
- (void)onRequestSignInterpreterToTalk {
    RNZoomUsEmit(@"onRequestSignInterpreterToTalk", nil);
    NSLog(@"RNZoomUsVideoView onRequestSignInterpreterToTalk");
}
- (void)onRequestCloudRecordingResponse:(MobileRTCRequestStartCloudRecordingStatus)status {
    RNZoomUsEmit(@"onRequestCloudRecordingResponse", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onRequestCloudRecordingResponse");
}
- (void)onRawLiveStreamPrivilegeChanged:(BOOL)hasPrivilege {
    RNZoomUsEmit(@"onRawLiveStreamPrivilegeChanged", @{@"hasPrivilege": @(hasPrivilege)});
    NSLog(@"RNZoomUsVideoView onRawLiveStreamPrivilegeChanged");
}
- (void)onRawLiveStreamPrivilegeRequested:(MobileRTCRequestRawLiveStreamPrivilegeHandler *)handler {
    RNZoomUsEmit(@"onRawLiveStreamPrivilegeRequested", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onRawLiveStreamPrivilegeRequested");
}
- (void)onRawLiveStreamPrivilegeRequestTimeout {
    RNZoomUsEmit(@"onRawLiveStreamPrivilegeRequestTimeout", nil);
    NSLog(@"RNZoomUsVideoView onRawLiveStreamPrivilegeRequestTimeout");
}
- (void)onRequestLocalRecordingPrivilegeChanged:(MobileRTCLocalRecordingRequestPrivilegeStatus)status {
    RNZoomUsEmit(@"onRequestLocalRecordingPrivilegeChanged", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onRequestLocalRecordingPrivilegeChanged");
}
- (void)onRequestLocalRecordingPrivilegeReceived:(MobileRTCRequestLocalRecordingPrivilegeHandler *)handler {
    RNZoomUsEmit(@"onRequestLocalRecordingPrivilegeReceived", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onRequestLocalRecordingPrivilegeReceived");
}
- (void)onSinkQAConnected:(BOOL)connected{
    RNZoomUsEmit(@"onSinkQAConnected", @{@"connected": @(connected)});
    NSLog(@"RNZoomUsVideoView onSinkQAConnected");
}
- (void)onSinkDeleteAnswer:(NSArray<NSString *> *)answerIDArray{
    RNZoomUsEmit(@"onSinkDeleteAnswer", @{@"answerIDArray": answerIDArray ?: @[]});
    NSLog(@"RNZoomUsVideoView onSinkDeleteAnswer");
}
- (void)onSinkLowerAllHands{
    RNZoomUsEmit(@"onSinkLowerAllHands", nil);
    NSLog(@"RNZoomUsVideoView onSinkLowerAllHands");
}
- (void)onSuspendParticipantsActivities{
    RNZoomUsEmit(@"onSuspendParticipantsActivities", nil);
    NSLog(@"RNZoomUsVideoView onSuspendParticipantsActivities");
}
- (void)onSinkReceiveAnswer:(NSString *)answerID{
    RNZoomUsEmit(@"onSinkReceiveAnswer", @{@"answerID": answerID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkReceiveAnswer");
}
- (void)onSinkDeleteQuestion:(NSArray<NSString *> *)questionIDArray{
    RNZoomUsEmit(@"onSinkDeleteQuestion", @{@"questionIDArray": questionIDArray ?: @[]});
    NSLog(@"RNZoomUsVideoView onSinkDeleteQuestion");
}
- (void)onSinkReopenQuestion:(NSString *)questionID{
    RNZoomUsEmit(@"onSinkReopenQuestion", @{@"questionID": questionID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkReopenQuestion");
}
- (void)onSinkQAConnectStarted{
    RNZoomUsEmit(@"onSinkQAConnectStarted", nil);
    NSLog(@"RNZoomUsVideoView onSinkQAConnectStarted");
}
- (void)onSinkReceiveQuestion:(NSString *)questionID {
    RNZoomUsEmit(@"onSinkReceiveQuestion", @{@"questionID": questionID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkReceiveQuestion");
}
- (void)onSinkUserEndLiving:(NSString *)questionID {
    RNZoomUsEmit(@"onSinkUserEndLiving", @{@"questionID": questionID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkUserEndLiving");
}
- (void)onSignInterpreterListChanged {
    RNZoomUsEmit(@"onSignInterpreterListChanged", nil);
    NSLog(@"RNZoomUsVideoView onSignInterpreterListChanged");
}
- (void)onSignInterpreterRoleChanged {
    RNZoomUsEmit(@"onSignInterpreterRoleChanged", nil);
    NSLog(@"RNZoomUsVideoView onSignInterpreterRoleChanged");
}
- (void)onSinkPanelistCapacityExceed {
    RNZoomUsEmit(@"onSinkPanelistCapacityExceed", nil);
    NSLog(@"RNZoomUsVideoView onSinkPanelistCapacityExceed");
}
- (void)onSinkUserLivingReply:(NSString *)questionID {
    RNZoomUsEmit(@"onSinkUserLivingReply", @{@"questionID": questionID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkUserLivingReply");
}
- (void)onSignInterpreterLanguageChanged {
    RNZoomUsEmit(@"onSignInterpreterLanguageChanged", nil);
    NSLog(@"RNZoomUsVideoView onSignInterpreterLanguageChanged");
}
- (void)onSinkWebinarNeedRegister:(NSString *)registerURL{
    RNZoomUsEmit(@"onSinkWebinarNeedRegister", @{@"registerURL": registerURL ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkWebinarNeedRegister");
}
- (void)onSmartSummaryStatusChange:(BOOL)isStarted {
    RNZoomUsEmit(@"onSmartSummaryStatusChange", @{@"isStarted": @(isStarted)});
    NSLog(@"RNZoomUsVideoView onSmartSummaryStatusChange");
}
- (void)onSpotlightVideoUserChange:(NSArray<NSNumber *> *)spotlightedUserList{
    RNZoomUsEmit(@"onSpotlightVideoUserChange", @{@"spotlightedUserList": spotlightedUserList ?: @[]});
    NSLog(@"RNZoomUsVideoView onSpotlightVideoUserChange");
}
- (void)onSinkLiveTranscriptionStatus:(MobileRTCLiveTranscriptionStatus)status{
    RNZoomUsEmit(@"onSinkLiveTranscriptionStatus", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onSinkLiveTranscriptionStatus");
}
- (void)onSinkSelfAllowTalkNotification{
    RNZoomUsEmit(@"onSinkSelfAllowTalkNotification", nil);
    NSLog(@"RNZoomUsVideoView onSinkSelfAllowTalkNotification");
}
- (void)onStartCloudRecordingRequested:(MobileRTCRequestStartCloudRecordingPrivilegeHandler *)handler{
    RNZoomUsEmit(@"onStartCloudRecordingRequested", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onStartCloudRecordingRequested");
}
- (void)onSignInterpretationStatusChange:(MobileRTCSignInterpretationStatus)status{
    RNZoomUsEmit(@"onSignInterpretationStatusChange", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onSignInterpretationStatusChange");
}
- (void)onSinkSelfDisallowTalkNotification{
    RNZoomUsEmit(@"onSinkSelfDisallowTalkNotification", nil);
    NSLog(@"RNZoomUsVideoView onSinkSelfDisallowTalkNotification");
}
- (void)onSinkQAOpenQuestionChanged:(NSInteger)count{
    RNZoomUsEmit(@"onSinkQAOpenQuestionChanged", @{@"count": @(count)});
    NSLog(@"RNZoomUsVideoView onSinkQAOpenQuestionChanged");
}
- (void)onSinkMeetingAudioTypeChange:(NSUInteger)userID{
    RNZoomUsEmit(@"onSinkMeetingAudioTypeChange", @{@"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingAudioTypeChange");
}
- (void)onSinkMeetingMyAudioTypeChange{
    RNZoomUsEmit(@"onSinkMeetingMyAudioTypeChange", nil);
    NSLog(@"RNZoomUsVideoView onSinkMeetingMyAudioTypeChange");
}
- (void)onSinkShareSettingTypeChanged:(MobileRTCShareSettingType)shareSettingType{
    RNZoomUsEmit(@"onSinkShareSettingTypeChanged", @{@"shareSettingType": @(shareSettingType)});
    NSLog(@"RNZoomUsVideoView onSinkShareSettingTypeChanged");
}
- (void)onSinkQuestionMarkedAsDismissed:(NSString *)questionID{
    RNZoomUsEmit(@"onSinkQuestionMarkedAsDismissed", @{@"questionID": questionID ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkQuestionMarkedAsDismissed");
}
- (void)onSinkQAAddAnswer:(NSString *)answerID success:(BOOL)success{
    RNZoomUsEmit(@"onSinkQAAddAnswer", @{@"answerID": answerID ?: [NSNull null], @"success": @(success)});
    NSLog(@"RNZoomUsVideoView onSinkQAAddAnswer");
}
- (void)onSinkJoin3rdPartyTelephonyAudio:(NSString *)audioInfo{
    RNZoomUsEmit(@"onSinkJoin3rdPartyTelephonyAudio", @{@"audioInfo": audioInfo ?: [NSNull null]});
    NSLog(@"RNZoomUsVideoView onSinkJoin3rdPartyTelephonyAudio");
}

- (void)onSinkPanelistChatPrivilegeChanged:(MobileRTCPanelistChatPrivilegeType)privilege{
    RNZoomUsEmit(@"onSinkPanelistChatPrivilegeChanged", @{@"privilege": @(privilege)});
    NSLog(@"RNZoomUsVideoView onSinkPanelistChatPrivilegeChanged");
}
- (void)onSinkQAAddQuestion:(NSString *)questionID success:(BOOL)success{
    RNZoomUsEmit(@"onSinkQAAddQuestion", @{@"questionID": questionID ?: [NSNull null], @"success": @(success)});
    NSLog(@"RNZoomUsVideoView onSinkQAAddQuestion");
}
- (void)onSinkAllowAttendeeChatNotification:(MobileRTCChatAllowAttendeeChat)currentPrivilege{
    RNZoomUsEmit(@"onSinkAllowAttendeeChatNotification", @{@"currentPrivilege": @(currentPrivilege)});
    NSLog(@"RNZoomUsVideoView onSinkAllowAttendeeChatNotification");
}
- (void)onSinkAttendeeChatPriviledgeChanged:(MobileRTCMeetingChatPriviledgeType)currentPrivilege{
    RNZoomUsEmit(@"onSinkAttendeeChatPriviledgeChanged", @{@"currentPrivilege": @(currentPrivilege)});
    NSLog(@"RNZoomUsVideoView onSinkAttendeeChatPriviledgeChanged");
}
- (void)onSinkPromptAttendee2PanelistResult:(MobileRTCWebinarPromoteorDepromoteError)errorCode{
    RNZoomUsEmit(@"onSinkPromptAttendee2PanelistResult", @{@"errorCode": @(errorCode)});
    NSLog(@"RNZoomUsVideoView onSinkPromptAttendee2PanelistResult");
}
- (void)onSinkVoteupQuestion:(NSString *)questionID orderChanged:(BOOL)orderChanged{
    RNZoomUsEmit(@"onSinkVoteupQuestion", @{@"questionID": questionID ?: [NSNull null], @"orderChanged": @(orderChanged)});
    NSLog(@"RNZoomUsVideoView onSinkVoteupQuestion");
}
- (void)onSinkDePromptPanelist2AttendeeResult:(MobileRTCWebinarPromoteorDepromoteError)errorCode{
    RNZoomUsEmit(@"onSinkDePromptPanelist2AttendeeResult", @{@"errorCode": @(errorCode)});
    NSLog(@"RNZoomUsVideoView onSinkDePromptPanelist2AttendeeResult");
}
- (void)onSmartSummaryPrivilegeRequested:(NSInteger)userId handler:(MobileRTCSmartSummaryPrivilegeHandler *)handler{
    RNZoomUsEmit(@"onSmartSummaryPrivilegeRequested", @{@"userId": @(userId), @"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onSmartSummaryPrivilegeRequested");
}
- (void)onSubscribeUserFail:(MobileRTCSubscribeFailReason)errorCode size:(NSInteger)size userId:(NSUInteger)userId {
    RNZoomUsEmit(@"onSubscribeUserFail", @{@"errorCode": @(errorCode), @"size": @(size), @"userId": @(userId)});
    NSLog(@"RNZoomUsVideoView onSubscribeUserFail");
}
- (void)onSmartSummaryStartReqResponse:(BOOL)timeout decline:(BOOL)isDecline{
    RNZoomUsEmit(@"onSmartSummaryStartReqResponse", @{@"timeout": @(timeout), @"isDecline": @(isDecline)});
    NSLog(@"RNZoomUsVideoView onSmartSummaryStartReqResponse");
}
- (void)onSinkRevokeVoteupQuestion:(NSString *)questionID orderChanged:(BOOL)orderChanged{
    RNZoomUsEmit(@"onSinkRevokeVoteupQuestion", @{@"questionID": questionID ?: [NSNull null], @"orderChanged": @(orderChanged)});
    NSLog(@"RNZoomUsVideoView onSinkRevokeVoteupQuestion");
}
- (void)onSinkQAAllowAskQuestionAnonymouslyNotification:(BOOL)beAllowed{
    RNZoomUsEmit(@"onSinkQAAllowAskQuestionAnonymouslyNotification", @{@"beAllowed": @(beAllowed)});
    NSLog(@"RNZoomUsVideoView onSinkQAAllowAskQuestionAnonymouslyNotification");
}
- (void)onSinkQAAllowAttendeeAnswerQuestionNotification:(BOOL)beAllowed{
    RNZoomUsEmit(@"onSinkQAAllowAttendeeAnswerQuestionNotification", @{@"beAllowed": @(beAllowed)});
    NSLog(@"RNZoomUsVideoView onSinkQAAllowAttendeeAnswerQuestionNotification");
}
- (void)onSinkMeetingVideoQualityChanged:(MobileRTCVideoQuality)qality userID:(NSUInteger)userID{
    RNZoomUsEmit(@"onSinkMeetingVideoQualityChanged", @{@"qality": @(qality), @"userID": @(userID)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingVideoQualityChanged");
}
- (void)onSinkAttendeePromoteConfirmResult:(BOOL)agree userId:(NSUInteger)userId{
    RNZoomUsEmit(@"onSinkAttendeePromoteConfirmResult", @{@"agree": @(agree), @"userId": @(userId)});
    NSLog(@"RNZoomUsVideoView onSinkAttendeePromoteConfirmResult");
}
- (void)onSendPairingCodeStateChanged:(MobileRTCH323ParingStatus)state MeetingNumber:(unsigned long long)meetingNumber{
    RNZoomUsEmit(@"onSendPairingCodeStateChanged", @{@"state": @(state), @"meetingNumber": @(meetingNumber)});
    NSLog(@"RNZoomUsVideoView onSendPairingCodeStateChanged");
}
- (void)onSinkQAAllowAttendeeUpVoteQuestionNotification:(BOOL)beAllowed{
    RNZoomUsEmit(@"onSinkQAAllowAttendeeUpVoteQuestionNotification", @{@"beAllowed": @(beAllowed)});
    NSLog(@"RNZoomUsVideoView onSinkQAAllowAttendeeUpVoteQuestionNotification");
}
- (void)onSinkQAAllowAttendeeViewAllQuestionNotification:(BOOL)beAllowed{
    RNZoomUsEmit(@"onSinkQAAllowAttendeeViewAllQuestionNotification", @{@"beAllowed": @(beAllowed)});
    NSLog(@"RNZoomUsVideoView onSinkQAAllowAttendeeViewAllQuestionNotification");
}
- (void)onSinkMeetingShowMinimizeMeetingOrBackZoomUI:(MobileRTCMinimizeMeetingState)state{
    RNZoomUsEmit(@"onSinkMeetingShowMinimizeMeetingOrBackZoomUI", @{@"state": @(state)});
    NSLog(@"RNZoomUsVideoView onSinkMeetingShowMinimizeMeetingOrBackZoomUI");
}

- (void)onSinkRequestForLiveTranscriptReceived:(NSUInteger)requesterUserId bAnonymous:(BOOL)bAnonymous{
    RNZoomUsEmit(@"onSinkRequestForLiveTranscriptReceived", @{@"requesterUserId": @(requesterUserId), @"bAnonymous": @(bAnonymous)});
    NSLog(@"RNZoomUsVideoView onSinkRequestForLiveTranscriptReceived");
}
- (void)onShareFromMainSession:(NSUInteger)sharingID shareStatus:(MobileRTCSharingStatus)status shareAction:(MobileRTCShareAction *)shareAction{
    RNZoomUsEmit(@"onShareFromMainSession", @{@"sharingID": @(sharingID), @"status": @(status), @"shareActionPresent": @(shareAction != nil)});
    NSLog(@"RNZoomUsVideoView onShareFromMainSession");
}
- (void)onSinkLiveTranscriptionMsgReceived:(NSString *)msg speakerId:(NSUInteger)speakerId type:(MobileRTCLiveTranscriptionOperationType)type{
    NSLog(@"RNZoomUsVideoView onSinkLiveTranscriptionMsgReceived");
}
- (void)onSinkJoinWebinarNeedUserNameAndEmailWithCompletion:(BOOL (^)(NSString * _Nonnull, NSString * _Nonnull, BOOL))completion{
    RNZoomUsEmit(@"onSinkJoinWebinarNeedUserNameAndEmailWithCompletion", nil);
    NSLog(@"RNZoomUsVideoView onSinkJoinWebinarNeedUserNameAndEmailWithCompletion");
}
- (void)onTalkPrivilegeChanged:(BOOL)hasPrivilege{
    RNZoomUsEmit(@"onTalkPrivilegeChanged", @{@"hasPrivilege": @(hasPrivilege)});
    NSLog(@"RNZoomUsVideoView onTalkPrivilegeChanged");
}

- (void)onUpgradeFreeMeetingResult:(NSUInteger)result{
    RNZoomUsEmit(@"onUpgradeFreeMeetingResult", @{@"result": @(result)});
    NSLog(@"RNZoomUsVideoView onUpgradeFreeMeetingResult");
}
- (void)onUserConfirmToStartArchive:(MobileRTCArchiveConfrimHandle *)handler{
    RNZoomUsEmit(@"onUserConfirmToStartArchive", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onUserConfirmToStartArchive");
}
- (void)onUserRawLiveStreamingStatusChanged:(NSArray<MobileRTCRawLiveStreamInfo *> *)liveStreamList{
    RNZoomUsEmit(@"onUserRawLiveStreamingStatusChanged", @{@"liveStreamListPresent": @(liveStreamList != nil)});
    NSLog(@"RNZoomUsVideoView onUserRawLiveStreamingStatusChanged");
}
- (void)onUserRawLiveStreamPrivilegeChanged:(NSUInteger)userId hasPrivilege:(_Bool)hasPrivilege{
    RNZoomUsEmit(@"onUserRawLiveStreamPrivilegeChanged", @{@"userId": @(userId), @"hasPrivilege": @(hasPrivilege)});
    NSLog(@"RNZoomUsVideoView onUserRawLiveStreamPrivilegeChanged");
}
- (void)onVideoAlphaChannelStatusChanged:(BOOL)alphaChannelOn{
    RNZoomUsEmit(@"onVideoAlphaChannelStatusChanged", @{@"alphaChannelOn": @(alphaChannelOn)});
    NSLog(@"RNZoomUsVideoView onVideoAlphaChannelStatusChanged");
}
- (void)onWhiteboardStatusChanged:(MobileRTCWhiteboardStatus)status{
    RNZoomUsEmit(@"onWhiteboardStatusChanged", @{@"status": @(status)});
    NSLog(@"RNZoomUsVideoView onWhiteboardStatusChanged");
}
- (void)onWaitingRoomUserJoin:(NSUInteger)userId{
    NSLog(@"RNZoomUsVideoView onWaitingRoomUserJoin");
}
- (void)onWaitingRoomUserLeft:(NSUInteger)userId{
    NSLog(@"RNZoomUsVideoView onWaitingRoomUserLeft");
}
- (void)onWaitingRoomStatusChange:(BOOL)needWaiting{
    RNZoomUsEmit(@"onWaitingRoomStatusChange", @{@"needWaiting": @(needWaiting)});
    NSLog(@"RNZoomUsVideoView onWaitingRoomStatusChange");
}
- (void)onWaitingRoomEntranceEnabled:(BOOL)enabled{
    RNZoomUsEmit(@"onWaitingRoomEntranceEnabled", @{@"enabled": @(enabled)});
    NSLog(@"RNZoomUsVideoView onWaitingRoomEntranceEnabled");
}
- (void)onWebinarNeedInputScreenName:(MobileRTCWebinarInputScreenNameHandler *)handler{
    RNZoomUsEmit(@"onWebinarNeedInputScreenName", @{@"handlerPresent": @(handler != nil)});
    NSLog(@"RNZoomUsVideoView onWebinarNeedInputScreenName");
}
- (void)onWaitingRoomPresetAudioStatusChanged:(BOOL)audioCanTurnOn{
    NSLog(@"RNZoomUsVideoView onWaitingRoomPresetAudioStatusChanged");
}
- (void)onWaitingRoomPresetVideoStatusChanged:(BOOL)videoCanTurnOn{
    NSLog(@"RNZoomUsVideoView onWaitingRoomPresetVideoStatusChanged");
}
- (void)onWaitingRoomUserNameChanged:(NSInteger)userID userName:(NSString *)userName{
    NSLog(@"RNZoomUsVideoView onWaitingRoomUserNameChanged");
}
- (void)onWhiteboardSettingsChanged:(MobileRTCWhiteboardShareOption)shareOption createOption:(MobileRTCWhiteboardCreateOption)createOption enable:(BOOL)enable{
    RNZoomUsEmit(@"onWhiteboardSettingsChanged", @{@"shareOption": @(shareOption), @"createOption": @(createOption), @"enable": @(enable)});
    NSLog(@"RNZoomUsVideoView onWhiteboardSettingsChanged");
}
- (void)onZoomIdentityExpired{
    RNZoomUsEmit(@"onZoomIdentityExpired", nil);
    NSLog(@"RNZoomUsVideoView onZoomIdentityExpired");
}

- (void)setMuteMyAudio:(BOOL *)isMute{
    if (_rnZoomUsVideoViewController)
    {
        //        [_rnZoomUsVideoViewController setMuteMyAudio:isMute == Nil ? NO : YES];
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        [ms muteMyAudio:isMute == Nil ? NO : YES];
    }
}

- (void) countInMeetingUser {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    NSUInteger inMeetingUserCount = [[ms getInMeetingUserList] count];
    NSLog(@"RNZoomUsVideoView onInMeetingUserUpdated==%@", @(inMeetingUserCount));
    if (self.onInMeetingUserCount) {
        self.onInMeetingUserCount(@{
            @"event": @"meetingCount",
            @"userList": @(inMeetingUserCount)
        });
    }
}

- (void)setMuteMyCamera:(BOOL *)isMute{
    if (_rnZoomUsVideoViewController)
    {
        //        [_rnZoomUsVideoViewController setMuteMyCamera:isMute == Nil ? NO : YES];
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        [ms muteMyVideo:isMute == Nil ? NO : YES];
    }
}

- (void)setFullScreen:(BOOL *)fullScreen {
    NSLog(@"RNZoomUsVideoView setFullScreen");
    [[GlobalData sharedInstance] setGlobalOrientation:fullScreen == Nil ? 1 : 3];
}


//- (BOOL)onCheckIfMeetingVoIPCallRunning{
//    return [providerDelegate isInCall];
//}
@end
