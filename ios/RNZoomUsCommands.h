//
//  RNZoomUsCommands.h
//
//  Calls any Zoom SDK method by selector, so the bridge does not need a
//  hand-written wrapper per call. iOS counterpart of
//  android-impl/.../RNZoomUsCommands.java.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNZoomUsCommands : NSObject

/// Walk a dot path of zero-argument getters from [MobileRTC sharedRTC].
/// An empty path resolves to the MobileRTC singleton itself.
+ (nullable id)resolve:(nullable NSString *)path error:(NSError **)error;

/// Invoke `name` on `target` with `args`. `name` may be a full selector
/// ("joinMeetingWithJoinParam:") or a bare name when the method takes none.
+ (nullable id)call:(id)target
           selector:(NSString *)name
               args:(nullable NSArray *)args
              error:(NSError **)error;

/// Replace {__ref} placeholders JS sent back with the objects they name:
/// a {__ref} map becomes the object, and an array becomes an array of the
/// referenced objects (recursively for nested arrays). Anything else is
/// returned unchanged. Sets `error` and returns nil when a ref has expired.
+ (nullable id)resolveRefs:(nullable id)value error:(NSError **)error;

/// Turn an SDK return value into something the React Native bridge can carry.
+ (nullable id)marshal:(nullable id)value depth:(NSInteger)depth;

@end

NS_ASSUME_NONNULL_END
