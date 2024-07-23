//
//  CustomMeetingViewController+MeetingDelegate.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/12.
//  
//

#import "CustomMeetingViewController+MeetingDelegate.h"

@implementation CustomMeetingViewController (MeetingDelegate)

- (void)onMeetingStateChange:(MobileRTCMeetingState)state
{
    if (state == MobileRTCMeetingState_InMeeting) {
        [self.videoVC.preVideoView removeFromSuperview];
        [[[MobileRTC sharedRTC] getMeetingService] setParentViewCtroller:self];
        BOOL isWebinarAttendee = [[[MobileRTC sharedRTC] getMeetingService] isWebinarAttendee];
        if (isWebinarAttendee) {
        } else {
        }
    }
}

- (void)onSinkMeetingActiveVideo:(NSUInteger)userID
{
    self.pinUserId = userID;
    [self updateVideoOrShare];
}

- (void)onSinkMeetingPreviewStopped
{
}

- (void)onSinkMeetingAudioStatusChange:(NSUInteger)userID
{
    self.pinUserId = userID;
    [self updateMyAudioStatus];

    [self updateVideoOrShare];
}

- (void)onSinkMeetingMyAudioTypeChange
{
    [self updateMyAudioStatus];
}

- (void)onSinkMeetingVideoStatusChange:(NSUInteger)userID
{
    self.pinUserId = userID;
    [self updateMyVideoStatus];

    [self updateVideoOrShare];
}

- (void)onMyVideoStateChange
{
    [self updateMyVideoStatus];

    [self updateVideoOrShare];
}

- (void)onSinkMeetingUserJoin:(NSUInteger)userID
{
    [self updateVideoOrShare];
}

- (void)onSinkMeetingUserLeft:(NSUInteger)userID
{
    [self updateVideoOrShare];
}

- (void)onSinkSharingStatus:(MobileRTCSharingStatus)status userID:(NSUInteger)userID
{
    if (status == MobileRTCSharingStatus_Self_Send_Begin) {
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        if ([ms isMeetingChatLegalNoticeAvailable]) {
            NSString *LegalNoticePromoteTitle = [ms getChatLegalNoticesPrompt];
            NSString *LegalNoticePromoteExplained = [ms getChatLegalNoticesExplained];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:LegalNoticePromoteTitle message:LegalNoticePromoteExplained delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil, nil];
            [alert show];
        }
    }
    
    if (status == MobileRTCSharingStatus_Self_Send_Begin)
    {
        if([[[MobileRTC sharedRTC] getMeetingService] isMyself:userID] && [[[MobileRTC sharedRTC] getMeetingService] isDeviceSharing]) { //share device
            return;
        }
    }
    else if (status == MobileRTCSharingStatus_Other_Share_Begin)
    {
        self.remoteShareVC.activeShareID = userID;
        [self showRemoteShareView];
    }
    else if (status == MobileRTCSharingStatus_Self_Send_End ||
             status == MobileRTCSharingStatus_Other_Share_End)
    {
        [self showVideoView];
    }
}

- (void)onSinkShareSizeChange:(NSUInteger)userID
{
}

- (void)onSinkMeetingShareReceiving:(NSUInteger)userID
{
}

- (void)onWaitingRoomStatusChange:(BOOL)needWaiting
{
    if (needWaiting)
    {
#if 0
        MobileRTCWaitingRoomService *ws = [[MobileRTC sharedRTC] getWaitingRoomService];
        
        MobileRTCSDKError error = [ws getWaitingRoomCustomizeData];
        NSLog(@"getWaitingRoomCustomizeData = %@", @(error));
#endif
        
        UIViewController *vc = [UIViewController new];
        
        vc.title = @"Need wait for host Approve";
        
        UIBarButtonItem *leaveItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Leave", @"") style:UIBarButtonItemStylePlain target:self action:@selector(onEndButtonClick:)];
        [vc.navigationItem setRightBarButtonItem:leaveItem];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:NULL];
        
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

- (void)onEndButtonClick:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}
-(void)setMuteMyAudio:(BOOL)muteMyAudio
{
    self.muteMyAudio = muteMyAudio;
    [self updateMyAudioStatus];
}
-(void)setMuteMyCamera:(BOOL)muteMyCamera
{
    self.muteMyCamera = muteMyCamera;
    [self updateMyVideoStatus];
}
@end
