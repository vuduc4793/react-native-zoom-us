//
//  RNZoomUsListeners.h
//  react-native-zoom-us
//
//  Native objects that let JavaScript receive SDK callbacks it opted into:
//  a generic delegate built for any protocol by name (createListener), the
//  reminder delegate behind setPromptMode("reminder", "js"), and the toolbar
//  button overrides behind setButtonOverrides. Every callback reaches JS on the
//  unified ZoomUsEvent channel through RNZoomUsEmit.
//
//  Native code cannot be patched over the air, so nothing here may throw:
//  inputs are validated and SDK / runtime calls are wrapped in @try.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// An object that adopts the protocol `protocolName` at runtime. Every method
/// of the protocol (required and optional, adopted protocols included) is
/// answered by emitting "onListenerCallback" {listener, method, args}; return
/// values are left zeroed (NO / 0 / nil). Returns nil and sets `error` when the
/// protocol is not in this binary.
@interface RNZoomUsDelegateProxy : NSObject
@property (nonatomic, copy, nullable) NSString *refId;
@property (nonatomic, readonly) NSString *protocolName;
+ (nullable instancetype)proxyForProtocolNamed:(NSString *)protocolName error:(NSError **)error;
@end

/// setPromptMode("reminder", mode): "js" makes the bridge the SDK's
/// reminderDelegate (onReminderNotify reaches JS with a pinned handler);
/// anything else clears it so Zoom handles reminders itself (the default).
/// Remembered, so it can be re-applied once the SDK is initialized.
void RNZoomUsSetReminderMode(NSString *_Nullable mode);
/// Re-apply the remembered reminder mode (after a successful initialize).
void RNZoomUsApplyReminderMode(void);

/// setButtonOverrides: keys invite, end, audio, video, share, more,
/// participants; YES means the app handles that toolbar button.
void RNZoomUsSetButtonOverrides(NSDictionary *_Nullable overrides);
/// A toolbar button of Zoom's own UI was tapped. Returns whether Zoom's default
/// action is suppressed (`baseline` or the override for `button`) and emits
/// "onClickMeetingButton" {button, handled}.
BOOL RNZoomUsMeetingButtonClicked(NSString *button, BOOL baseline);

/// When `target` is a reminder handler and `method` answers it, the ref no
/// longer needs pinning. Also maps the Android name "decline" to iOS
/// "declined". Returns the selector name to call.
NSString *RNZoomUsReminderMethodName(id _Nullable target, NSString *_Nullable method);
void RNZoomUsAfterInvokeRef(id _Nullable target, NSString *_Nullable refId, NSString *_Nullable method);

NS_ASSUME_NONNULL_END
