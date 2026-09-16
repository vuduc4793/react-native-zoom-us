//
//  RNZoomUsEvents.h
//  react-native-zoom-us
//
//  Delivery path for SDK callbacks that are handled outside the module.
//
//  Only one object can hold MobileRTCMeetingService.delegate at a time, and in
//  practice RNZoomUsVideoView takes it over from RNZoomUs as soon as a video
//  view is mounted. Neither class has a reference to the other, so callbacks are
//  posted as a notification and RNZoomUs -- the RCTEventEmitter -- observes it
//  and forwards to JavaScript. That keeps the two delegate implementations
//  decoupled and means an event reaches JS no matter which one is live.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RNZoomUsSDKCallbackNotification;
extern NSString *const RNZoomUsSDKCallbackEventKey;
extern NSString *const RNZoomUsSDKCallbackPayloadKey;

/// Forward one SDK callback to JavaScript. Safe to call from any thread and
/// when no JavaScript listener is attached.
void RNZoomUsEmit(NSString *event, NSDictionary *_Nullable payload);

NS_ASSUME_NONNULL_END
