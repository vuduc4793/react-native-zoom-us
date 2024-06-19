//
//  ThumbView.m
//  MobileRTCSample
//
//  Created by Zoom Video Communications on 2018/10/15.
//  Copyright © 2018 Zoom Video Communications, Inc. All rights reserved.
//

#import "ThumbView.h"
#import "HorizontalTableView.h"
#import "ThumbTableViewCell.h"
#import <MobileRTC/MobileRTC.h>

#define kThumbTableViewCell  @"kThumbTableViewCell"

@interface ThumbView ()<UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (strong, nonatomic) HorizontalTableView       * thumbTableView;
@property (strong, nonatomic) UIButton                  * thumbHideButton;
//@property (nonatomic) BOOL firstInit;
@property (nonatomic) BOOL thumbHidden;
@end

@implementation ThumbView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        self.firstInit = YES;
        [self addSubview:self.thumbHideButton];
        [self addSubview:self.thumbTableView];
    }
    return self;
}

- (float)getCellSize
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    CGRect frame = [UIScreen mainScreen].bounds;
    CGFloat cellSize = 0;
    if (landscape)
    {
        cellSize = frame.size.height/4;
    }
    else
    {
        cellSize = frame.size.width/4;
    }
    return cellSize;
}

- (void)showThumbView {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    if (!landscape) {
        [UIView animateWithDuration:0.25 animations:^{
            self.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height-Bottom_Height-[self getCellSize]-BTN_HEIGHT, [UIScreen mainScreen].bounds.size.width, [self getCellSize]+BTN_HEIGHT);
        } completion:^(BOOL finished) {
        }];
    }

}

- (void)hiddenThumbView {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    if (!landscape) {
        [UIView animateWithDuration:0.25 animations:^{
            float offset = IPHONE_X ? SAFE_ZOOM_INSETS : 0;
            self.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height-[self getCellSize]-offset-BTN_HEIGHT, [UIScreen mainScreen].bounds.size.width, [self getCellSize]+BTN_HEIGHT);
        } completion:^(BOOL finished) {
        }];
    }
}

- (void)updateFrame
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    
    CGRect frame = [UIScreen mainScreen].bounds;
    
    if (landscape)
    {
        float offset = IPHONE_X ? SAFE_ZOOM_INSETS : 0;
        self.frame = CGRectMake(frame.size.width-[self getCellSize]-offset-BTN_HEIGHT, 0, [self getCellSize]+BTN_HEIGHT, frame.size.height);
    }
    else
    {
        self.frame = CGRectMake(0, frame.size.height-Bottom_Height-[self getCellSize]-BTN_HEIGHT, frame.size.width, [self getCellSize]+BTN_HEIGHT);
    }
    
    self.thumbHidden = NO;
    self.thumbTableView.hidden = NO;
    CGRect btnFrame = CGRectZero;
    NSString *btnImageName = nil;
    if (landscape)
    {
        self.thumbTableView.transform = CGAffineTransformIdentity;
        self.thumbTableView.frame = CGRectMake(BTN_HEIGHT, 0, [self getCellSize], frame.size.height);
        
        btnFrame = CGRectMake(0, 0, BTN_HEIGHT, self.frame.size.height);
        btnImageName = @"arrow_right_normal.png";
    }
    else
    {
        self.thumbTableView.transform = CGAffineTransformMakeRotation(-M_PI / 2);
        self.thumbTableView.frame = CGRectMake(0, BTN_HEIGHT, frame.size.width, [self getCellSize]);
        btnFrame = CGRectMake(0, 0, self.frame.size.width, BTN_HEIGHT);
        btnImageName = @"arrow_down_normal.png";
    }
    self.thumbHideButton.frame = btnFrame;
    [self.thumbHideButton setImage:[UIImage imageNamed:btnImageName] forState:UIControlStateNormal];
    
    self.thumbTableView.rowHeight = [self getCellSize];
    [self.thumbTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    
    [self.thumbTableView reloadData];
}

- (void)updateThumbViewVideo
{
//    if (self.firstInit) {
//        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
//        NSMutableArray *videoArray = [NSMutableArray arrayWithArray:[ms getInMeetingUserList]];
//        if (videoArray.count > 0) {
//            if ([videoArray containsObject:[NSNumber numberWithInteger:self.pinUserID]]) {
//                [[[MobileRTC sharedRTC] getMeetingService] pinVideo:YES withUser:self.pinUserID];
//            } else {
//                [[[MobileRTC sharedRTC] getMeetingService] pinVideo:YES withUser:[[videoArray objectAtIndex:0] intValue]];
//                self.pinUserID = [[videoArray objectAtIndex:0] intValue];
//            }
//        }
//        self.firstInit = NO;
//    }
    
    
    [self.thumbTableView reloadData];
}

- (void)dealloc {
    self.thumbTableView = nil;
}

- (HorizontalTableView*)thumbTableView
{
    if (!_thumbTableView)
    {
        _thumbTableView = [[HorizontalTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _thumbTableView.backgroundColor = [UIColor clearColor];
        _thumbTableView.separatorColor = [UIColor clearColor];
        _thumbTableView.pagingEnabled = NO;
        _thumbTableView.delegate=self;
        _thumbTableView.dataSource=self;
        _thumbTableView.showsVerticalScrollIndicator = NO;
        
        [_thumbTableView registerClass:[ThumbTableViewCell class] forCellReuseIdentifier:kThumbTableViewCell];
        
        UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        lpgr.minimumPressDuration = 1.0;
        lpgr.delegate = self;
        [_thumbTableView addGestureRecognizer:lpgr];
    }
    
    return _thumbTableView;
}

- (UIButton*)thumbHideButton
{
    if (!_thumbHideButton)
    {
        _thumbHideButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_thumbHideButton addTarget:self action:@selector(onThumbHideClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _thumbHideButton;
}

- (void)onThumbHideClicked:(id)sender
{
    self.thumbHidden = !self.thumbHidden;
    self.thumbTableView.hidden = self.thumbHidden;
    
    CGRect btnFrame = CGRectZero;
    NSString *btnImageName = nil;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    if (landscape) {
        if (self.thumbHidden) {
            btnFrame = CGRectMake([self getCellSize], 0, BTN_HEIGHT, self.frame.size.height);
        } else {
            btnFrame = CGRectMake(0, 0, BTN_HEIGHT, self.frame.size.height);
        }
        btnImageName = self.thumbHidden ? @"arrow_left_normal.png" : @"arrow_right_normal.png";
    } else {
        if (self.thumbHidden) {
            btnFrame = CGRectMake(0, [self getCellSize], self.frame.size.width, BTN_HEIGHT);
        } else {
            btnFrame = CGRectMake(0, 0, self.frame.size.width, BTN_HEIGHT);
        }
        btnImageName = self.thumbHidden ? @"arrow_up_normal.png" : @"arrow_down_normal.png";
    }
    
    self.thumbHideButton.frame = btnFrame;
    [self.thumbHideButton setImage:[UIImage imageNamed:btnImageName] forState:UIControlStateNormal];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = [[[[MobileRTC sharedRTC] getMeetingService] getInMeetingUserList] count];
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ThumbTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kThumbTableViewCell];
    if (cell == nil)
    {
        cell = [[ThumbTableViewCell alloc] initWithStyle: UITableViewCellStyleDefault reuseIdentifier:kThumbTableViewCell];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
//    cell.transform = CGAffineTransformMakeRotation(M_PI / 2);
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = UIInterfaceOrientationIsLandscape(orientation);
    cell.transform = landscape ? CGAffineTransformIdentity : CGAffineTransformMakeRotation(M_PI / 2);
    
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    NSMutableArray *videoArray = [NSMutableArray arrayWithArray:[ms getInMeetingUserList]];
    if ([videoArray count] == 0)
        return cell;
    
    // when in background no need to render video again
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if(UIApplicationStateActive != state)
        return cell;
    
    //Subscribe attendee Video
    NSUInteger row = [indexPath row];
    if (row >= [videoArray count])
        return cell;
    
    if(tableView.decelerating)
    {
        [cell stopThumbVideo];
        return cell;
    }
    
    NSUInteger userID = [[videoArray objectAtIndex:indexPath.row] intValue];
    [self showAttendeeVideo:cell.thumbView withUserID:userID];
    
    if (userID == self.pinUserID) {
        cell.backgroundColor = [UIColor greenColor];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    NSMutableArray *videoArray = [NSMutableArray arrayWithArray:[ms getInMeetingUserList]];
    if ([videoArray count] == 0)
        return;
    if (indexPath.row >= [videoArray count])
        return;
    NSUInteger userID = [[videoArray objectAtIndex:indexPath.row] intValue];
    self.pinUserID = userID;
    
    for (NSIndexPath *indexPath in tableView.indexPathsForVisibleRows) {
        ThumbTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.5];
    }
    ThumbTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.backgroundColor = [UIColor greenColor];

    if (self.pinOnClickBlock) {
        self.pinOnClickBlock(userID);
    }
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if(gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        CGPoint p = [gestureRecognizer locationInView:_thumbTableView ];
        NSIndexPath *indexPath = [_thumbTableView indexPathForRowAtPoint:p];
        if (indexPath == nil)
            return;
        
        MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
        NSMutableArray *videoArray = [NSMutableArray arrayWithArray:[ms getInMeetingUserList]];
        NSUInteger userID = [[videoArray objectAtIndex:indexPath.row] intValue];
        MobileRTCMeetingUserInfo *userInfo = [ms userInfoByID:userID];
        
        // for test userInfo.
        NSLog(@"isInterpreter->%@ getInterpreterActiveLanguage->%@", @(userInfo.isInterpreter), userInfo.interpreterActiveLanguage);
        
        NSString * roleString;
        switch (userInfo.userRole) {
            case MobileRTCUserRole_None:
                roleString = @"Role:None";
                break;
            case MobileRTCUserRole_Host:
                roleString = @"Role:Host";
                break;
            case MobileRTCUserRole_CoHost:
                roleString = @"Role:CoHost";
                break;
            case MobileRTCUserRole_Attendee:
                roleString = @"Role:Attendee";
                break;
            case MobileRTCUserRole_Panelist:
                roleString = @"Role:Webinar_Panelist";
                break;
            case MobileRTCUserRole_BreakoutRoom_Moderator:
                roleString = @"Role:BOMeeting_Moderator";
                break;
            default:
                roleString = @"Role:None";
                break;
        }
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:roleString
                                                                                            message:nil
                                                                                     preferredStyle:UIAlertControllerStyleActionSheet];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Show video Size"
                                                            style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                 CGSize size = [ms getUserVideoSize:userID];
                                                                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:[NSString stringWithFormat:@"video size:w=%f,h=%f", size.width,size.height] delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil, nil];
                                                                         [alert show];
                                                            }]];
        
        
        if ([ms isMeetingHost] || [ms isMeetingCoHost]) {
            if (userInfo.audioStatus.audioType != MobileRTCAudioType_None) {
                NSString *muteAudioString = [ms isUserAudioMuted:userID] ? @"Ask Unmute audio" : @"Mute Audio";
                [alertController addAction:[UIAlertAction actionWithTitle:muteAudioString
                                                                    style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction *action) {
                                                                    [ms muteUserAudio:[ms isUserAudioMuted:userID]?NO:YES withUID:userID];
                                                                    }]];
            }
            
            NSString *muteVideoString = [ms isUserVideoSending:userID] ? @"Stop video" : @"Ask start video";
            [alertController addAction:[UIAlertAction actionWithTitle:muteVideoString
                                                               style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction *action) {
                                                                    if ([ms isUserVideoSending:userID]) {
                                                                        [ms stopUserVideo:userID];
                                                                    } else {
                                                                        [ms askUserStartVideo:userID];
                                                                    }
                                                                 }]];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Change name to Test"
                                                                style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                                                                        [ms changeName:[NSString stringWithFormat:@"Test:%ld", indexPath.row] withUserID:userID];
                                                                  }]];
            if ([userInfo handRaised]) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"Lower the user hand"
                                                                style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                                                                        [ms lowerHand:userID];
                                                                  }]];
            }
            
            if (!userInfo.isCohost) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"Remove the user"
                                                                style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                                                                        [ms removeUser:userID];
                                                                  }]];
            }
            MobileRTCWaitingRoomService *ws = [[MobileRTC sharedRTC] getWaitingRoomService];
            if ([ws isSupportWaitingRoom] && [ws isWaitingRoomOnEntryFlagOn]) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"Put in waiting room"
                                                                style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction *action) {
                                                                        [ws putInWaitingRoom:userID];
                                                                  }]];
            }
        }
        
        if (!userInfo.isHost && [ms isMeetingHost]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"Make host"
                                                            style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
                                                                    [ms makeHost:userID];
                                                              }]];
        }
            
        if (!userInfo.isHost && !userInfo.isCohost && [ms isMeetingHost] && [ms canBeCoHost:userID]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"Make co-host"
                                                            style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *action) {
                                                                    [ms assignCohost:userID];
                                                              }]];
        }
        
        if (userInfo.isCohost && [ms isMeetingHost]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"Revoke co-host"
            style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                    [ms revokeCoHost:userID];
              }]];
        }
        
        if ([ms isWebinarMeeting]) {
            if (([ms isMeetingHost] || [ms isMeetingCoHost]) && userInfo.userRole == MobileRTCUserRole_Panelist) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"DePrompt the panelist to attendee"
                style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
                        [ms dePromptPanelist2Attendee:userID];
                  }]];
            }
        }
        
        if (![ms isPrivateChatDisabled]) {
            [alertController addAction:[UIAlertAction actionWithTitle:@"Send a private chat message"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                MobileRTCMeetingChat *msg= [[MobileRTCMeetingChat alloc]init];
                msg.receiverId = [NSString stringWithFormat:@"%lu",(unsigned long)userID];
                msg.content = @"This is a private chat message";
                MobileRTCSendChatError error = [ms sendChatMsg:msg];
                NSLog(@"SendChat:sendChatToUser ---> %@", @(error));
                                                            }]];
        }
        
        NSLog(@"LiveTranscription: canAssignOthersToSendCC===>%@", @([ms canAssignOthersToSendCC]));
        NSLog(@"LiveTranscription: canBeAssignedToSendCC===>%@", @([ms canBeAssignedToSendCC:userID]));
        if([ms isMeetingSupportCC] && [ms isLiveTranscriptionFeatureEnabled] && [ms canAssignOthersToSendCC]) {
            if ([ms canBeAssignedToSendCC:userID]) {
                [alertController addAction:[UIAlertAction actionWithTitle:@"assign CC privilege"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                    BOOL ret = [ms assignCCPrivilege:userID];
                    NSLog(@"assignCCPrivilege===> %@", @(ret));
                                                                }]];
                [alertController addAction:[UIAlertAction actionWithTitle:@"withdraw CC privilege"
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                    BOOL ret = [ms withdrawCCPrivilege:userID];
                    NSLog(@"withdrawCCPrivilege===> %@", @(ret));
                                                                }]];
            }
        }
        
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)                                                                                 style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction *action) {
                                    }]];
        
        UITableViewCell * cell = [_thumbTableView cellForRowAtIndexPath:indexPath];
        UIPopoverPresentationController *popover = alertController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = cell;
            popover.sourceRect = cell.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
//        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
//        [[appDelegate topViewController] presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self stopThumbViewVideo];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updateThumbViewVideo];
    [self scrollToRowPosition];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (decelerate == NO)
    {
        [self updateThumbViewVideo];
        [self scrollToRowPosition];
    }
}

- (void)scrollToRowPosition
{
    NSInteger rowHeight = self.thumbTableView.rowHeight;
    NSInteger offsetY = (NSInteger)self.thumbTableView.contentOffset.y % rowHeight;
    BOOL visibleCell = offsetY >= rowHeight/2;
    
    NSIndexPath *indexPath = [self.thumbTableView indexPathForRowAtPoint:CGPointMake(self.thumbTableView.contentOffset.x, self.thumbTableView.contentOffset.y)];
    if (visibleCell)
    {
        indexPath = [NSIndexPath indexPathForRow: indexPath.row+1 inSection: 0];
    }
    
    if (indexPath.row < [[[[MobileRTC sharedRTC] getMeetingService] getInMeetingUserList] count]) {
        [self.thumbTableView scrollToRowAtIndexPath: indexPath atScrollPosition: UITableViewScrollPositionTop animated: YES];
    }
}

- (void)showAttendeeVideo:(MobileRTCVideoView*)videoView withUserID:(NSUInteger)userID
{
    [videoView showAttendeeVideoWithUserID:userID];
    
    NSLog(@"video view's user id: %@", @([videoView getUserID]));
    [videoView setVideoAspect:MobileRTCVideoAspect_PanAndScan];
}

- (void)stopThumbViewVideo
{
    for (ThumbTableViewCell *cell in self.thumbTableView.visibleCells)
    {
        [cell stopThumbVideo];
    }
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end
