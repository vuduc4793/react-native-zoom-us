## Changelog

### 14.0.1

iOS fixes found by running the custom UI in a live class.

- `<ZoomVideoView>` now draws its slots on iOS. iOS ignored `layout` and showed
  one full-screen speaker plus a self preview, so `Attendee` (gallery),
  `Preview`, `Share` and `ActiveShare` did nothing. Each slot is now its own
  MobileRTC view, placed where the slot was laid out, with the name badge and
  muted icon. Units go blank between rooms (breakout switch, reconnect)
  instead of freezing on a stale user id. The legacy `video-view.tsx` keeps the
  old renderer: the new mode is turned on by `<ZoomVideoView>` only
  (`unitLayout`, iOS only).
- iOS slots land exactly on their layout. Positions were rounded to whole
  percents, up to 4pt off on a phone screen, so video spilled past the tile it
  belonged to. iOS now takes fractional percents; Android still rounds, since
  `MobileRTCVideoUnitRenderInfo` only takes whole numbers there.
- `getAllChatMessageID` resolved its promise twice when there was chat, which
  React Native reports as an error (a red box in debug builds).
- The self preview of the legacy renderer had a red background, visible
  whenever the camera had no frame (camera off, simulator).

### 14.0.0

First stable release with the Zoom SDK as an on-demand Play feature module.

Highlights:

- Zoom Meeting SDK 7.2.1.43944 (Android) / 7.2.1.39202 (iOS, pod `RNZoomSDK`)
- Android is split in two: `android/` is a small loader that ships in the base
  APK, and `android-impl/` holds the bridge and the SDK for an on-demand
  dynamic feature module, which keeps the base download well under Play's
  200 MB limit. See docs/DYNAMIC-FEATURE.md
- One OTA-adaptable surface on both platforms: `zoom` and `ref` reach any method of
  the SDK's controllers and objects, `create` for SDK objects, `listen` for any
  listener or delegate, `setButtonOverrides`, and `setPromptMode` for the
  unmute, reminder and (Android) network prompts
- Cross-platform helpers for custom UIs: `zoomMeeting`, `zoomQA`,
  `zoomPolling`, lazy participant loading (`zoomMeeting.getParticipantIds`) and full-screen
  sharing from a custom UI on both platforms (iOS broadcast extension, see
  docs/IOS-SCREENSHARE.md)

Detailed notes:

Android:

- Updated Zoom Meeting SDK to 7.2.1.43944 (from JitPack, `com.github.vuduc4793:jitpack-zoom-us`)
- BREAKING CHANGE: minSdkVersion raised to 28 (Android 9) — required by mobilertc.aar 7.1.x
- compileSdk/targetSdk raised to 36, Java 17
- Dependency set re-synced with the SDK's own `versions.gradle` (Kotlin 2.2.20,
  coroutines 1.9.0, lifecycle 2.9.1, Compose BOM 2025.10.01, +profileinstaller,
  +coil-gif, +lifecycle-viewmodel-compose)
- Implemented three listener callbacks added in 7.1.x: `onMeetingNeedConfirmPreview`,
  `onUserNetworkStatusChanged`, `onAppSignalPanelUpdated`
- `proguard.cfg` is now shipped as a `consumerProguardFiles`, so apps no longer
  need to copy the Zoom keep-rules into their own `proguard-rules.pro`
- Module declares `namespace` instead of a manifest `package` (AGP 8 requirement)

New in v2 (both platforms):

- `<ZoomVideoView>` replaces the hand-computed `layout` array with ordinary
  React Native layout, and can be nested anywhere instead of having to sit at
  the top of the view tree. `<ZoomUsVideoView>` is unchanged and still exported.
  See docs/VIDEO-VIEW-V2.md
- Fixed the two reasons the old view only worked full-screen at the root:
  Android never measured the surfaces Zoom adds at runtime (no `requestLayout`
  override), and on iOS the meeting view controller was never added as a child
  view controller, so it got no lifecycle, rotation or safe-area callbacks
- Android: added a `zOrder` prop, GL teardown/rebuild on window attach/detach,
  and `release()` on unmount so a remount no longer comes back black
- Video units can be addressed by `userId` instead of `userIndex`, which shifted
  as people joined and left
- Every SDK callback is now forwarded on one `ZoomUsEvent` channel on both
  platforms, including the 84 Android ones that were previously empty stubs.
  `src/events/generated.ts` is generated from the native emitters by
  `scripts/generate-events.py`. Previously the `onSink*` view props only fired
  on iOS, because the Android view manager declared no events at all
- Added `useZoomEvent`, `useZoomAnyEvent`, `useZoomParticipants`,
  `useZoomParticipantCount`, `addZoomListener`, `addZoomAnyListener`
- iOS now forwards all 250 void `MobileRTCMeetingServiceDelegate` callbacks.
  Previously ~205 of them only called NSLog, so they never reached JS.
  `RNZoomUsVideoView` covers 250/250 and `RNZoomUs` 246/250; the 4 it does not
  cover take a completion block the SDK waits on, and the 6 non-void callbacks
  (`onClickedEndButton:`, `onCheckIfMeetingVoIPCallRunning`, ...) are left alone
  because their return value changes what the SDK does
- Because only one object can hold `MobileRTCMeetingService.delegate`, and
  `RNZoomUsVideoView` takes it over from `RNZoomUs` as soon as a video view
  mounts, callbacks are now posted through `RNZoomUsEmit()` and forwarded by the
  module, so events arrive no matter which object is the live delegate
- The typed event map covers both platforms: 42 Android-only, 187 iOS-only, 56
  shared. Generated by `scripts/generate-events.py` and
  `scripts/generate-ios-delegates.py`
- Added codegen specs (`src/specs/`) and `codegenConfig`. The module matches the
  generated TurboModule spec and the view manager matches the generated Fabric
  interface; switching the native side over is now a small change
- Fixed `isHostUser` resolving its promise twice, and widened `isHostUser` /
  `addVideoView` / `removeVideoView` / `rotateMyVideo` from `int` to `double`,
  which also stops Zoom's 64-bit user ids being truncated

iOS:

- Updated Zoom Meeting SDK to 7.2.1.39202
- BREAKING CHANGE: minimum deployment target raised to iOS 15.0
- BREAKING CHANGE: the simulator slice is arm64-only; the podspec now sets
  `EXCLUDED_ARCHS[sdk=iphonesimulator*] = x86_64 i386` for both this pod and the app
- Removed the call to `-enableVideoCallPictureInPicture:`, deleted in SDK 7.1.x
  (only the `-videoCallPictureInPictureEnabled` getter remains; the setter was
  documented as ZoomUI-only and was already a no-op with `enableCustomizedMeetingUI`)
- Podspec version now tracks `package.json`, and depends on `React-Core`
- Fixed `startMeeting` passing the boxed `userType` object where an enum was
  expected, so the user type the caller asked for never reached the SDK
- Fixed `muteAttendee` passing an `NSNumber *` where an `NSUInteger` user id was
  expected, so it never muted the requested attendee
- Added the missing Foundation/UIKit imports to `GlobalData.h` and
  `ThumbPreviewView.h`, whose include guard also closed before its `@interface`

### 8.0.0

Android:

- Updated ZoomSDK to 5.17.11.20433

### 7.0.0

iOS:

- Updated ZoomSDK to 5.17.11.14222

### 6.20.0

iOS:

- Updated ZoomSDK to 5.14.11.8690
- BREAKING CHANGE: removed clientKey/clientSecret for initialize - use jwtToken instead

### 6.19.0

Android:

- Updated ZoomSDK to 5.16.2.16555
- BREAKING CHANGE: minSDKVersion has been upgraded to version 24

### 6.18.0

Android:

- Updated ZoomSDK to 5.13.10.12577
- BREAKING CHANGE: minSdkVersion has upgraded to version 23 (minimum platform version: Android 6.0)

### 6.17.1

Simplify installation for iOS and Android after using react-native@0.72.2

### 6.17.0

iOS updates:

- Updated ZoomSDK to 5.13.10.7064
- Delete `userId` param in `startMeeting`

### 6.16.5

Android:

- Use jitpack again - no need for applying breaking changes on 6.16.0

### 6.16.0

ANDROID BREAKING CHANGES:

- Add manually `commonlib.aar` and `mobilertc.aar`. See [Getting started](https://github.com/mieszko4/react-native-zoom-us/tree/feat/upgrade-android-to-5.13.1.11014#getting-started)
- Increased compileSdkVersion to 33
- Increased targetSdkVersion to 33
  Android updates:
- Update ZoomSDK to 5.13.1.11014
- Add new required listeners
  onSinkPanelistChatPrivilegeChanged(InMeetingChatController.MobileRTCWebinarPanelistChatPrivilege privilege)
  onShareMeetingChatStatusChanged(boolean start)
- Change deprecated listeners in favour of:
  - onSpotlightVideoChanged(boolean on) -> onSpotlightVideoChanged(List<Long> userList)
- Delete `userId` param in `startMeeting`

### 6.15.0

- Add `disableMinimizeMeeting` for `initialize` (iOS only)
- Add `disableClearWebKitCache` for `initialize`
- Fix `MeetingSettings` change not working in `initialize`
- Fix `autoConnectAudio` not working on iOS

### 6.13.0

Android updates:

- Add more logs
- Clean up passing initializePromise and meetingPromise, clean up to use only one initialize() call, use reactContext.getCurrentActivity()
- Wrap methods in try/catch
- Make sure to execute ZoomSDK on the main thread only
- Make `leaveMeeting` return promise
- Add `noMeetingErrorMessage` to `startMeeting` params
- On destroy unregister listeners and leave meeting
- On foreground register listeners and return to the meeting

### 6.12.0

iOS updates:

- Updated ZoomSDK to 5.11.0.3907

### 6.11.0

iOS updates:

- Updated ZoomSDK to 5.10.3.3244
- Changed deprecated listeners in favour of:
  - `(void)onSinkUserNameChanged:(NSUInteger)userID userName:(NSString *_Nonnull)userName -> (void)onSinkUserNameChanged:(NSArray <NSNumber*>* _Nullable)userNameChangedArr`
  - `(void)onMeetingCoHostChange:(NSUInteger)userId -> (void)onMeetingCoHostChange:(NSUInteger)userId isCoHost:(BOOL)isCoHost`

### 6.9.0

Android updates:

- Updated ZoomSDK to 5.10.3.5614
- Increased compileSdkVersion to 31
- Increased targetSdkVersion to 31
- Increased minSdkVersion to 21
- Increased buildToolsVersion to 30.0.2
- Added new required listeners
  - onLocalVideoOrderUpdated(List<Long> localOrderList)
  - onAllHandsLowered()
  - onPermissionRequested(String[] permissions)
  - onChatMsgDeleteNotification(String msgID, ChatMessageDeleteType deleteBy)
- Changed deprecated listeners in favour of:
  - onLocalRecordingStatus(RecordingStatus recordingStatus) -> onLocalRecordingStatus(long userId, RecordingStatus recordingStatus)
  - onUserNameChanged(long userId, String name) -> onUserNamesChanged(List<Long> userList)
  - onUserNetworkQualityChanged(long userId) -> onSinkMeetingVideoQualityChanged(VideoQuality videoQuality, long userId)
  - onMeetingCoHostChanged(long userId) -> onMeetingCoHostChange(long userId, boolean isCoHost)

### 6.7.0

Android updates:

- Updated ZoomSDK to 5.9.1.3674
- Added new installation steps
- Updated native dependencies
- Added new required listeners
  - onSharingStatus(SharingStatus status, long userId)
  - onFollowHostVideoOrderChanged(boolean bFollow)
  - onVideoOrderUpdated(List<Long> orderList)
- Updated renamed listener
  - onMeetingNeedCloseOtherMeeting(InMeetingEventHandler handler)

iOS updates:

- Updated ZoomSDK to 5.9.1.2191
- Added new required listeners
  - `onSinkSharingStatus:(MobileRTCSharingStatus)status userID:(NSUInteger)userID`
  - `onVideoOrderUpdated:(NSArray <NSNumber *>* _Nullable)orderArr`
  - `onFollowHostVideoOrderChanged:(BOOL)follow`
    `
    Be aware that you might need to follow the android installation steps to get this working on android 28 and above.

### 6.4.0

Android updates:

- Fix share screen for Custom View

### 6.3.1

- Upgrade iOS ZoomSDK to 5.7.1.645
- Upgrade android ZoomSDK to 5.7.1.1268

### 6.1.0

iOS updates:

- Upgrade ios ZoomSDk to 5.7.1.644
- Add `isInitialized()` method

### 6.0.0

Android updates:

- Upgrade android ZoomSDK to 5.7.1.1267
- Delete local archive repository for .arr files
- `participant_id` param is removed from sdk
- `Breaking changes`: Make sure to check [upgrading v6.0.0](docs/UPGRADING.md#600-jitpack)

### 5.12.0

- (ios) Upgrade ZoomSDK to 5.5.12511.0421
