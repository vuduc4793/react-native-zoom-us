//
//  CustomMeetingViewController.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/12.
//  
//

#import "CustomMeetingViewController.h"
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
//    [self.thumbView updateFrame];
//    
//    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
//    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
//    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
//    
//    BOOL isWebinarAttendee = [ms isWebinarAttendee];
//    if (landscape)
//    {
//        if (!isWebinarAttendee) {
//            self.thumbView.hidden = YES;
//        }
//    }
//    else
//    {
//        self.thumbView.hidden = YES;
//    }
}

- (void)updateVideoOrShare
{
    if (self.remoteShareVC.parentViewController)
    {
        [self.remoteShareVC updateShareView];
    }
    
    [self.thumbView updateThumbViewVideo];
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    
    BOOL isWebinarAttendee = [ms isWebinarAttendee];
    if (isWebinarAttendee) {
        self.thumbView.hidden = YES;
        if (self.pinUserId) {
            [self.videoVC showActiveVideoWithUserID:self.pinUserId];
        } else {
            NSUInteger activeUserID = [ms activeUserID];
            [self.videoVC showActiveVideoWithUserID:activeUserID];
        }
    } else {
        if (self.pinUserId) {
            [self.videoVC showAttendeeVideoWithUserID:self.pinUserId];
        } else {
//            [self.videoVC showAttendeeVideoWithUserID:[ms myselfUserID]];
        }
    }
    
    CGRect frame = self.videoVC.view.frame;
    frame.origin.y = 0;
    self.videoVC.view.frame = frame;
}


- (ThumbView *)thumbView
{
    if (!_thumbView)
    {
        _thumbView = [[ThumbView alloc] init];
        __weak typeof(self) weakSelf = self;
        _thumbView.pinOnClickBlock = ^(NSInteger pinUserID) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.pinUserId = pinUserID;
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
