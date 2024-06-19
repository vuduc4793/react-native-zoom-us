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
@implementation RNZoomUsVideoView
BOOL hasObservers;

- (instancetype)init
{
    self = [super init];
    _rnZoomUsVideoViewController = [[CustomMeetingViewController alloc] init];
    _rnZoomUsVideoViewController.view.frame = self.bounds;
        [self addSubview:_rnZoomUsVideoViewController.view];
    return self;
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

- (void)onMeetingStateChange:(MobileRTCMeetingState)state{
    NSLog(@"MobileRTC onMeetingStateChange =>%@", @(state));
    NSString* result;
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
    NSLog(@"MobileRTC onSinkMeetingActiveVideo =>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingVideoStatusChange=%@",@(userID));
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
}

- (void)onSinkMeetingActiveVideoForDeck:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingActiveVideo =>%@", @(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkMeetingActiveVideo:)])
    {
        [_rnZoomUsVideoViewController onSinkMeetingActiveVideo:userID];
    }
}
- (void)onSinkSharingStatus:(MobileRTCSharingStatus)status userID:(NSUInteger)userID
{
    NSLog(@"MobileRTC onSinkSharingStatus==%@ userID==%@", @(status),@(userID));
    if (_rnZoomUsVideoViewController && [_rnZoomUsVideoViewController respondsToSelector:@selector(onSinkSharingStatus:userID:)])
    {
        [_rnZoomUsVideoViewController onSinkSharingStatus:status userID:userID];
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
}
- (void)onSinkMeetingUserJoin:(NSUInteger)userID {
    NSLog(@"MobileRTC onSinkMeetingUserJoin==%@", @(userID));
    if (self.onSinkMeetingUserJoin) {
            self.onSinkMeetingUserJoin(@{
                @"event": @"userJoin",
                @"userList": @[@(userID)]
            });
        }
}

- (void)connectAudio {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    if (!ms) return;
    [ms connectMyAudio: YES];
//    [ms muteMyAudio: NO];
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
@end
