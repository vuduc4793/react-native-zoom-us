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

/// An SDK object as plain data for JavaScript: NSString/NSNumber/NSArray/
/// NSDictionary pass through, NSDate becomes epoch milliseconds, and MobileRTC*
/// objects become a dictionary of their properties and zero-argument
/// get/is/can/has methods (two levels deep), plus `__type`. Anything else --
/// UIKit objects, blocks -- comes back as `{__type}` only. Never nil.
id RNZoomUsSerialize(id _Nullable value);

/// SDK objects handed to JavaScript, by id. RNZoomUsSerialize registers every
/// MobileRTC object it serializes and adds `__ref`; JS can then call methods on
/// it (RNZoomUs.invokeRef) or pass it back as an argument ({__ref}). Bounded:
/// the least recently used go first, so a very old ref can expire.
NSString *RNZoomUsRefPut(id value);
id _Nullable RNZoomUsRefGet(NSString *_Nullable refId);
void RNZoomUsRefRelease(NSString *_Nullable refId);

/// A prompt Zoom hands over as a completion block (host asks to start my
/// video). Mode "auto" (default) answers at once with `defaultAnswer`, exactly
/// as before. Mode "js" hands JS a responder ({__ref}) whose `respond:` answers
/// it; if JS has not answered within the timeout, `defaultAnswer` is used, so
/// a silent JS can never leave Zoom waiting. Returns payload keys to emit.
NSDictionary *RNZoomUsOfferPrompt(NSString *prompt, BOOL defaultAnswer, void (^answer)(BOOL accept));
void RNZoomUsSetPromptMode(NSString *prompt, NSString *mode, double timeoutMs);

NS_ASSUME_NONNULL_END
