//
//  RNZoomUsVideoViewManager.m
//  react-native-zoom-us
//
//  Created by John Vu on 2024/05/11.
//
//

#import <React/RCTViewManager.h>
#import "RNZoomUsVideoViewManager.h"
#import "RNZoomUsVideoView.h"


@implementation RNZoomUsVideoViewManager

RCT_EXPORT_MODULE(RNZoomUsVideoView)


- (UIView *)view
{
    UIView *containerView = [[RNZoomUsVideoView alloc] init];
    
    return containerView;
}


RCT_EXPORT_VIEW_PROPERTY(onSinkMeetingUserLeft, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onSinkMeetingUserJoin, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onMeetingStateChange, RCTBubblingEventBlock);

RCT_EXPORT_VIEW_PROPERTY(muteMyAudio, BOOL);
RCT_EXPORT_VIEW_PROPERTY(muteMyCamera, BOOL);
RCT_EXPORT_VIEW_PROPERTY(fullScreen, BOOL);

RCT_CUSTOM_VIEW_PROPERTY(color, NSString, UIView)
{
  [view setBackgroundColor:[self hexStringToColor:json]];
}

- hexStringToColor:(NSString *)stringToConvert
{
  NSString *noHashString = [stringToConvert stringByReplacingOccurrencesOfString:@"#" withString:@""];
  NSScanner *stringScanner = [NSScanner scannerWithString:noHashString];

  unsigned hex;
  if (![stringScanner scanHexInt:&hex]) return nil;
  int r = (hex >> 16) & 0xFF;
  int g = (hex >> 8) & 0xFF;
  int b = (hex) & 0xFF;

  return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:1.0f];
}
@end
