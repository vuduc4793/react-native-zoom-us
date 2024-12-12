//
//  CustomMeetingViewController.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/12.
//
//

#import "GlobalData.h"
#import "CustomMeetingViewController.h"
#import <AVFoundation/AVFoundation.h>
@implementation CustomMeetingViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self initSubView];
}

- (void)initSubView
{
    [self.view addSubview:self.baseView];
    
    self.vcArray = [NSMutableArray array];
    [self.vcArray addObject:self.videoVC];
    [self.vcArray addObject:self.remoteShareVC];
    [self.view addSubview:self.thumbView];
    [self showVideoView];
    [self updateVideoOrShare];
    //    [self setMuteMyCamera: YES];
    //    [self setMuteMyAudio: YES];
    self.thumbView.hidden = YES;
}

- (void)uninitSubView
{
    self.baseView = nil;
    [self removeAllSubView];
    self.videoVC = nil;
    self.remoteShareVC = nil;
    self.thumbView = nil;
}

- (void)dealloc {
    [self uninitSubView];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self initSubView];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    [self updateVideoOrShare];
    //    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
}

- (void)updateVideoOrShare
{
    NSUInteger pinUserId = [[GlobalData sharedInstance] userID];
    NSUInteger globalActiveShareID = [[GlobalData sharedInstance] globalActiveShareID];
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    if (self.remoteShareVC.parentViewController)
    {
        [self.remoteShareVC updateShareView];
    }
    
    //    [self.thumbView updateThumbViewVideo];
    [self activeLoudspeaker];
    BOOL isWebinarAttendee = [ms isWebinarAttendee];
    BOOL isViewingShare = [ms isViewingShare];
    if (isWebinarAttendee) {
        if (pinUserId) {
            [self.videoVC showAttendeeVideoWithUserID:pinUserId];
        } else {
            NSUInteger activeUserID = [[[MobileRTC sharedRTC] getMeetingService] activeUserID];
            [self.videoVC showAttendeeVideoWithUserID:activeUserID];
        }
    } else {
        if (pinUserId) {
            [self.videoVC showAttendeeVideoWithUserID:pinUserId];
        } else {
            [self.videoVC showAttendeeVideoWithUserID:[[[MobileRTC sharedRTC] getMeetingService] myselfUserID]];
        }
    }
    CGRect frame = self.videoVC.view.frame;
    frame.origin.y = 0;
    self.videoVC.view.frame = frame;
}

- (void) showCurrentShareVideo {
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    BOOL isViewingShare = [ms isViewingShare];
    if (isViewingShare == 1) {
        [self showRemoteShareView];
    } else {
        [self showVideoView];
    }
}
- (void) activeLoudspeaker {
    dispatch_async(dispatch_get_main_queue(), ^{
//        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//        AVAudioSessionRouteDescription *currentRoute = audioSession.currentRoute;
        
        BOOL headphoneConnected = YES;
//        for (AVAudioSessionPortDescription *port in currentRoute.outputs) {
//            if ([port.portType isEqualToString:AVAudioSessionPortHeadphones]) {
//                headphoneConnected = YES;
//                break;
//            }
//        }
        if([UIDevice currentDevice].systemVersion.floatValue >= 6.0) {
            if (headphoneConnected) {
                BOOL ok = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
                if (ok) {
                }
            } else {
                BOOL ok = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
                if (ok) {
                }
            }
        } else {
            UInt32 route;
            if (headphoneConnected) {
                route = kAudioSessionOverrideAudioRoute_Speaker;
            } else {
                route = kAudioSessionOverrideAudioRoute_None;
            }
            AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute, sizeof(route), &route);
        }
    });
}
- (ThumbView *)thumbView
{
    if (!_thumbView)
    {
        _thumbView = [[ThumbView alloc] init];
        __weak typeof(self) weakSelf = self;
        _thumbView.pinOnClickBlock = ^(NSInteger pinUserID) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [[GlobalData sharedInstance] setUserID:pinUserID];
            //            strongSelf.pinUserId = pinUserID;
            [strongSelf.videoVC showAttendeeVideoWithUserID:pinUserID];
        };
    }
    
    return _thumbView;
}



- (void)updateMyAudioStatus
{
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    [ms muteMyAudio:self.muteMyAudio];
}

- (void)updateMyVideoStatus
{
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    [ms muteMyAudio:self.muteMyCamera];
}


- (void)removeAllSubView
{
    for (UIViewController * vc in self.vcArray)
    {
        [vc willMoveToParentViewController:nil];
        [vc.view removeFromSuperview];
        [vc removeFromParentViewController];
    }
}

- (void)showSubView:(UIViewController*)viewCtrl
{
    [self addChildViewController:viewCtrl];
    [self.baseView addSubview:viewCtrl.view];
    
    [viewCtrl didMoveToParentViewController:self];
    
    viewCtrl.view.frame = self.view.bounds;
    CGRect frame = viewCtrl.view.frame;
    frame.origin.y = 0;
    viewCtrl.view.frame = frame;
    
}

- (void)showVideoView
{
    [self.remoteShareVC stopShareView];
    [self removeAllSubView];
    [self showSubView:self.videoVC];
}

- (void)showRemoteShareView
{
    [self.videoVC stopActiveVideo];
    [self removeAllSubView];
    [self showSubView:self.remoteShareVC];
}

- (UIView*)baseView
{
    if (!_baseView)
    {
        _baseView = [[UIView alloc] initWithFrame:self.view.bounds];
        _baseView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    }
    return _baseView;
}

- (VideoViewController*)videoVC
{
    if (!_videoVC)
    {
        _videoVC = [[VideoViewController alloc]init];
        _videoVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _videoVC;
}

- (RemoteShareViewController*)remoteShareVC
{
    if (!_remoteShareVC)
    {
        _remoteShareVC = [[RemoteShareViewController alloc] init];
        _remoteShareVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _remoteShareVC;
}

- (void)onSinkMeetingUserJoin:(NSUInteger)userID{
    NSLog(@"MobileRTC onSinkMeetingUserJoin==%@", @(userID));
}

- (void)onSinkMeetingUserLeft:(NSUInteger)userID{
    NSLog(@"MobileRTC onSinkMeetingUserLeft==%@", @(userID));
}
-(void)setMuteMyAudio:(BOOL)isMute{
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    [ms muteMyAudio:isMute];
}
-(void)setMuteMyCamera:(BOOL)isMute{
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    [ms muteMyVideo:isMute];
}

@end
