//
//  RNZoomUsVideoView.h
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/11.
//
//

#if __has_include("React/RCTViewManager.h")
#import "React/RCTViewManager.h"
#else
#import "RCTViewManager.h"
#endif

#import <UIKit/UIKit.h>
#import <MobileRTC/MobileRTCMeetingDelegate.h>
#import "CustomMeetingViewController.h"
#import "RCTEventEmitter.h"
@interface RNZoomUsVideoView : UIView<MobileRTCMeetingServiceDelegate>

@property(nonatomic, strong)CustomMeetingViewController* rnZoomUsVideoViewController;
@property (nonatomic, strong) UILabel *label;
@property(nonatomic, copy)RCTBubblingEventBlock onSinkMeetingUserLeft;
@property(nonatomic, copy)RCTBubblingEventBlock onSinkMeetingUserJoin;
@property(nonatomic, copy)RCTBubblingEventBlock onMeetingStateChange;
- (void)setMuteMyAudio:(BOOL*)muteMyAudio;
- (void)setMuteMyCamera:(BOOL*)muteMyCamera;
- (void)setFullScreen:(BOOL*)fullScreen;
@end
