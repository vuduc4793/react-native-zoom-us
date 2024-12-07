//
//  RNZoomUsVideoView.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/11.
//
//

#import "RNZoomUsVideoView.h"
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
    _rnZoomUsVideoViewController = [[CustomMeetingViewController alloc] init];
    _rnZoomUsVideoViewController.view.frame = self.bounds;
        [self addSubview:_rnZoomUsVideoViewController.view];
    return self;
}

- (void)reactSetFrame:(CGRect)frame {
    [super reactSetFrame:frame];
}

- (void)dealloc
{
    
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    
    if (ms) {
        ms.delegate = self;
        [self addViewControllerAsSubView];
        if (_rnZoomUsVideoViewController != nil) {
            _rnZoomUsVideoViewController.view.frame = self.bounds;
        }
    }
}

- (void)removeFromSuperview {
    if (_rnZoomUsVideoViewController != nil) {
        [_rnZoomUsVideoViewController willMoveToParentViewController:nil];
        [_rnZoomUsVideoViewController.view removeFromSuperview];
        [_rnZoomUsVideoViewController removeFromParentViewController];
        _rnZoomUsVideoViewController = nil;
        [super removeFromSuperview];
    }
}

-(void)addViewControllerAsSubView
{
}
#pragma mark - Meeting Service Delegate
- (void)onMeetingStateChange:(MobileRTCMeetingState)state{
    NSLog(@"MobileRTC onMeetingStateChange =>%@", @(state));
    NSString* result;
    switch(state) {
        case MobileRTCMeetingState_Idle:
            result = @"MEETING_STATUS_IDLE";
            break;
        case MobileRTCMeetingState_Connecting:
            result = @"MEETING_STATUS_CONNECTING";
            if (providerDelegate.callingUUID == nil) {
                NSUUID *callUUID = [NSUUID UUID];
                
                CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:callUUID handle:[[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"Học Viện Minh Trí Thành"]];
                CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
                callUpdate.remoteHandle = startCallAction.handle;
                callUpdate.hasVideo = startCallAction.video;
                CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
                [callController requestTransaction:transaction completion:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error requesting start call transaction: %@", error.localizedDescription);
                        providerDelegate.callingUUID = nil;
                    } else {
                        NSLog(@"Requested start call transaction succeeded");
                        NSLog(@"callUUID 1: %@", callUUID);
                        providerDelegate.callingUUID = callUUID;
                        NSLog(@"callUUID 2: %@", providerDelegate.callingUUID);
                    }
                }];
            }
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
    
    NSLog(@"MobileRTC onMeetingStateChange =>%@", result);
    
    
    if (self.onMeetingStateChange) {
            self.onMeetingStateChange(@{
                @"event": @"success",
                @"status": result
            });
        }
}

- (void)onSinkMeetingActiveVideo:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingActiveVideo =>>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingVideoStatusChange => %@",@(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingVideoStatusChange:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingVideoStatusChange:userID];
    }
}

- (void)onMyVideoStateChange {
    NSLog(@"MobileRTC onMyVideoStateChange");
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onMyVideoStateChange)])
    {
        [_rnZoomUsVideoViewController onMyVideoStateChange];
    }
}

- (void)onSpotlightVideoChange:(BOOL)on {}

- (void)onSinkMeetingPreviewStopped {
    NSLog(@"MobileRTC onSinkMeetingPreviewStopped");
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
    NSLog(@"MobileRTC onSinkMeetingVideoStatusChange=%@, videoStatus=%@",@(userID), @(videoStatus));
    
    if (self.onSinkMeetingVideoStatusChange) {
            self.onSinkMeetingVideoStatusChange(@{
                @"event": @"onSinkMeetingVideoStatusChange",
                @"videoStatus": @(videoStatus)
            });
        }
}

- (void)onSinkMeetingActiveVideoForDeck:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingActiveVideoForDeck =>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}

- (void)onSinkMeetingUserLeft:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingUserLeft==%@", @(userID));
    if (self.onSinkMeetingUserLeft) {
            self.onSinkMeetingUserLeft(@{
                @"event": @"userLeave",
                @"userList": @[@(userID)]
            });
        }
    [self countInMeetingUser];
}
- (void)onSinkMeetingUserJoin:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingUserJoin==%@", @(userID));
    if (self.onSinkMeetingUserJoin) {
            self.onSinkMeetingUserJoin(@{
                @"event": @"userJoin",
                @"userList": @[@(userID)]
            });
        }
    [self countInMeetingUser];
}

- (void)onSinkMeetingAudioRequestUnmuteByHost {
    if (self.onMeetingAudioRequestUnmuteByHost) {
            self.onMeetingAudioRequestUnmuteByHost(@{
                @"event": @"REQUEST_AUDIO",
                @"status": @(YES)
            });
        }
}

- (void)onSinkMeetingVideoRequestUnmuteByHost:(MobileRTCSDKError (^)(BOOL))completion {
    if (self.onMeetingVideoRequestUnmuteByHost) {
            self.onMeetingVideoRequestUnmuteByHost(@{
                @"event": @"REQUEST_VIDEO",
                @"status": @(YES)
            });
        }
}
- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingAudioStatusChange=%@",@(userID));
}
- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID audioStatus:(MobileRTC_AudioStatus)audioStatus {
    NSLog(@"MobileRTC onSinkMeetingAudioStatusChange=%@, audioStatus=%@",@(userID), @(audioStatus));
    
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
//    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
//    NSArray *users = [ms getInMeetingUserList];
//    NSLog(@"MobileRTC onInMeetingUserUpdated:%@", users);
    [self countInMeetingUser];
}

- (void)onInMeetingUserAvatarPathUpdated:(NSInteger)userID {
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
    NSLog(@"MobileRTC MobileRTCMeetingChat-->%@",chatInfo.content);
    if (self.onChatMessageNotification) {
        NSDictionary *chatInfoDict = nil;
        if (chatInfo) {
//            MobileRTCMeetingUserInfo *userInfo = [self getUserInfo:chatInfo.chatId];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
            NSString *dateString = [dateFormatter stringFromDate:chatInfo.date];
              chatInfoDict = @{
//                  @"avatar": userInfo.avatarPath,
                  @"chatId": chatInfo.chatId,
                  @"senderId": chatInfo.senderId,
                  @"senderName": chatInfo.senderName,
                  @"receiverId": chatInfo.receiverId,
                  @"receiverName": chatInfo.receiverName,
                  @"content": chatInfo.content,
                  @"date": dateString,
                  @"chatMessageType": @(chatInfo.chatMessageType),
                  @"isMyself": @(chatInfo.isMyself),
                  @"isPrivate": @(chatInfo.isPrivate),
                  @"isChatToAll": @(chatInfo.isChatToAll),
                  @"isChatToAllPanelist": @(chatInfo.isChatToAllPanelist),
                  @"isChatToWaitingroom": @(chatInfo.isChatToWaitingroom),
                  @"isComment": @(chatInfo.isComment),
                  @"isThread": @(chatInfo.isThread),
                  @"threadID": chatInfo.threadID,
                  
              };
          }
            self.onChatMessageNotification(@{
                @"event": @"onChatMessageNotification",
                @"chatInfo": chatInfoDict
            });
        }
}

- (void)onChatMsgDeleteNotification:(NSString *_Nonnull)msgID deleteBy:(MobileRTCChatMessageDeleteType)deleteBy
{
    NSLog(@"MobileRTC onChatMsgDeleteNotification-->%@ deleteBy-->%@",msgID,@(deleteBy));
    
    if (self.onChatMsgDeleteNotification) {
        NSDictionary *chatInfoDict = nil;
        chatInfoDict = @{
            @"deleteBy": @(deleteBy),
            @"msgID": msgID,
        };
        self.onChatMsgDeleteNotification(@{
            @"event": @"onChatMsgDeleteNotification",
            @"msgDelete": chatInfoDict
        });
    }
}

- (void)onSinkUserNameChanged:(NSArray <NSNumber *>* _Nullable)userNameChangedArr
{
    NSLog(@"onSinkUserNameChanged:%@", userNameChangedArr);
}

- (void)onSinkMeetingUserRaiseHand:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingUserRaiseHand==%@", @(userID));
}

- (void)onSinkMeetingUserLowerHand:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingUserLowerHand==%@", @(userID));
}

- (void)onMeetingHostChange:(NSUInteger)hostId {
    NSLog(@"MobileRTC onMeetingHostChange==%@", @(hostId));
}

- (void)onMeetingCoHostChange:(NSUInteger)userID isCoHost:(BOOL)isCoHost {
    NSLog(@"MobileRTC onMeetingCoHostChange==%@ isCoHost===%@", @(userID), @(isCoHost));
}

- (void)onClaimHostResult:(MobileRTCClaimHostError)error
{
    NSLog(@"MobileRTC onClaimHostResult==%@", @(error));
}

#pragma mark - BO MEETING

- (void)onHasCreatorRightsNotification:(MobileRTCBOCreator *_Nonnull)creator
{
    NSLog(@"---BO--- Own Creator");
}

- (void)onHasAdminRightsNotification:(MobileRTCBOAdmin * _Nonnull)admin
{
    NSLog(@"---BO--- Own Admin");
}

- (void)onHasAssistantRightsNotification:(MobileRTCBOAssistant * _Nonnull)assistant
{
    NSLog(@"---BO--- Own Assistant");
}

- (void)onHasAttendeeRightsNotification:(MobileRTCBOAttendee * _Nonnull)attendee
{
    NSString *boName = [attendee getBOName];
    
    if (self.onHasAttendeeRightsNotification) {
            self.onHasAttendeeRightsNotification(@{
                @"event": @"onHasAttendeeRightsNotification",
                @"boName": boName
            });
        }
    NSLog(@"---BO--- Own Attendee");
}

- (void)onHasDataHelperRightsNotification:(MobileRTCBOData * _Nonnull)dataHelper
{
    NSLog(@"---BO--- Own Data Helper");
}

- (void)onLostCreatorRightsNotification
{
    NSLog(@"---BO--- Lost Creator");
}

- (void)onLostAdminRightsNotification;
{
    NSLog(@"---BO--- Lost Admin");
}

- (void)onLostAssistantRightsNotification
{
    NSLog(@"---BO--- Lost Assistant");
}

- (void)onLostAttendeeRightsNotification
{
    NSLog(@"---BO--- Lost Attendee");
}

- (void)onNewBroadcastMessageReceived:(NSString *_Nullable)broadcastMsg senderID:(NSUInteger)senderID {
    NSLog(@"---BO--- Broadcast Message Received:%@ senderID:%@", broadcastMsg, @(senderID));
}

- (void)onBOStopCountDown:(NSUInteger)seconds
{
    NSLog(@"---BO--- onBOStopCountDown:%@", @(seconds));
}

- (void)onHostInviteReturnToMainSession:(NSString *_Nullable)hostName replyHandler:(MobileRTCReturnToMainSessionHandler *_Nullable)replyHandler
{
    NSLog(@"---BO--- onHostInviteReturnToMainSession hostName=:%@, replyHandler=:%p", hostName, replyHandler);
}

- (void)onBOStatusChanged:(MobileRTCBOStatus)status
{
    NSLog(@"---BO--- onBOStatusChanged status=:%@", @(status));
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
                @"status": result
            });
        }
}

- (void)onBOSwitchRequestReceived:(NSString*)newBOName newBOID:(NSString*)newBOID {
    NSLog(@"---BO--- onBOSwitchRequestReceived newBOName=:%@ newBOID=:%@", newBOName, newBOID);
}

- (void)onLostDataHelperRightsNotification
{
    NSLog(@"---BO--- Lost DataHelper");
}

- (void)onHelpRequestReceived:(NSString *_Nullable)strUserID {
    NSLog(@"---BO--- help request received from %@", strUserID);
}

- (void)onHelpRequestHandleResultReceived:(MobileRTCBOHelpReply)eResult {
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
    NSLog(@"---BO--- help request replied: %@", replyStatus);
}

- (void)onHostJoinedThisBOMeeting {
    NSLog(@"---BO--- Host has joined this BO");
}

- (void)onHostLeaveThisBOMeeting {
    NSLog(@"---BO--- Host has left this BO");
}

- (void)onBOInfoUpdated:(NSString *_Nullable)boId;
{
    NSLog(@"---BO--- BO info updated");
}

- (void)onUnAssignedUserUpdated
{
    NSLog(@"---BO--- un-assigned user updated");
}

- (void)onBOListInfoUpdated
{
    NSLog(@"---BO--- onBOListInfoUpdated");
}

- (void)onStartBOError:(MobileRTCBOControllerError)errType {
    NSLog(@"---BO--- admin start bo error: %@", @(errType));
}

- (void)onBOEndTimerUpdated:(NSUInteger)remaining isTimesUpNotice:(BOOL)isTimesUpNotice {
    NSLog(@"---BO--- admin bo %lu seconds left, isTimesUpNotice: %@", remaining, isTimesUpNotice ? @"Y" : @"N");
}

- (void)onBOCreateSuccess:(NSString *_Nullable)BOID {
    NSLog(@"---BO--- creator create success ret bo_id: %@", BOID);
}

- (void)onWebPreAssignBODataDownloadStatusChanged:(MobileRTCBOPreAssignBODataStatus)status {
    NSLog(@"---BO--- onWebPreAssignBODataDownloadStatusChanged: %@", @(status));
}

#pragma mark - SHARING

- (void)onSharingContentStartReceiving {
    NSLog(@"MobileRTC onSharingContentStartReceiving");
}

- (void)onSinkSharingStatus:(MobileRTCSharingStatus)status userID:(NSUInteger)userID
{
    NSLog(@"MobileRTC onSinkSharingStatus==%@ userID==%@", @(status),@(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkSharingStatus:userID:)])
    {
        [_rnZoomUsVideoViewController onSinkSharingStatus:status userID:userID];
    }
}

- (void)onSinkShareSizeChange:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkShareSizeChange==%@",@(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkShareSizeChange:)])
    {
        [_rnZoomUsVideoViewController onSinkShareSizeChange: userID];
    }
}

- (void)connectAudio {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    MobileRTCMeetingSettings *zoomSettings = [[MobileRTC sharedRTC] getMeetingSettings];
    
    if (!ms) return;
    [ms connectMyAudio: YES];
    [zoomSettings setAutoConnectInternetAudio:YES];
//    [ms muteMyAudio: YES];
//    [ms muteMyVideo: YES];
    NSLog(@"connectAudio");
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
    NSLog(@"MobileRTC onInMeetingUserUpdated==%@", @(inMeetingUserCount));
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
    
}


- (BOOL)onCheckIfMeetingVoIPCallRunning{
    return [providerDelegate isInCall];
}
@end
