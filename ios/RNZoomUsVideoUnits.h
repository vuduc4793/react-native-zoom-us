//
//  RNZoomUsVideoUnits.h
//  react-native-zoom-us
//
//  Renders the `layout` prop of <ZoomVideoView> on iOS: one MobileRTC view per
//  unit, placed by the percentages the JS side measured. Android does the same
//  with MobileRTCVideoViewManager; iOS has no such manager, so each unit owns
//  its own MobileRTCVideoView subclass.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNZoomUsVideoUnits : UIView

/** Array of unit dictionaries (kind, x, y, width, height, userId, ...). */
- (void)setUnits:(nullable NSArray *)units;

/** Re-resolve which user/share each unit shows. Safe to call often. */
- (void)refresh;

/** A share started or stopped; remembers the source for "active-share". */
- (void)shareStatusChangedForUser:(NSUInteger)userID
                    shareSourceID:(NSUInteger)shareSourceID
                           active:(BOOL)active;

/** Stop every render and drop all units. */
- (void)stopAll;

@end

NS_ASSUME_NONNULL_END
