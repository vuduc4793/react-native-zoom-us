//
//  RNZoomUsVideoUnits.m
//  react-native-zoom-us
//

#import "RNZoomUsVideoUnits.h"
#import <MobileRTC/MobileRTC.h>

static NSInteger const RNZoomUsNoTarget = -1;

static BOOL RNZoomUsIsInMeeting(MobileRTCMeetingService *ms) {
    return ms != nil && [ms getMeetingState] == MobileRTCMeetingState_InMeeting;
}

static NSInteger RNZoomUsInteger(NSDictionary *unit, NSString *key, NSInteger fallback) {
    id value = unit[key];
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : fallback;
}

static CGFloat RNZoomUsPercent(NSDictionary *unit, NSString *key, CGFloat fallback) {
    id value = unit[key];
    if (![value isKindOfClass:[NSNumber class]]) return fallback;
    double percent = [value doubleValue];
    if (!isfinite(percent)) return fallback;
    return MAX(0, MIN(100, percent));
}

static BOOL RNZoomUsBool(NSDictionary *unit, NSString *key, BOOL fallback) {
    id value = unit[key];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : fallback;
}

static MobileRTCVideoAspect RNZoomUsAspect(NSInteger mode) {
    switch (mode) {
        case 1: return MobileRTCVideoAspect_Full_Filled;
        case 2: return MobileRTCVideoAspect_LetterBox;
        case 3: return MobileRTCVideoAspect_PanAndScan;
        case 0: return MobileRTCVideoAspect_Original;
        // 4 is Android's "trustee" (let Zoom pick); letterbox never crops.
        default: return MobileRTCVideoAspect_LetterBox;
    }
}

#pragma mark - One unit

@interface RNZoomUsVideoUnitCell : UIView
@property (nonatomic, copy, readonly) NSString *kind;
@property (nonatomic, copy) NSDictionary *unit;
@property (nonatomic, strong, readonly) MobileRTCVideoView *videoView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIImageView *micOffView;
@property (nonatomic, assign) NSInteger shownTarget;
@property (nonatomic, assign) NSInteger lastAspect;
@end

@implementation RNZoomUsVideoUnitCell

- (instancetype)initWithKind:(NSString *)kind
{
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _kind = [kind copy];
    _shownTarget = RNZoomUsNoTarget;
    _lastAspect = -1;
    self.clipsToBounds = YES;
    self.userInteractionEnabled = NO;

    if ([kind isEqualToString:@"active"]) {
        _videoView = [[MobileRTCActiveVideoView alloc] initWithFrame:CGRectZero];
    } else if ([self isShareKind]) {
        _videoView = [[MobileRTCActiveShareView alloc] initWithFrame:CGRectZero];
    } else {
        // "preview" and "attendee": a plain attendee view. After joining, the
        // local camera is rendered as an attendee (myselfUserID), which is what
        // Zoom's own custom-UI sample does.
        _videoView = [[MobileRTCVideoView alloc] initWithFrame:CGRectZero];
    }
    _videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _videoView.backgroundColor = [UIColor clearColor];
    [self addSubview:_videoView];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _nameLabel.textColor = [UIColor whiteColor];
    _nameLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    _nameLabel.layer.cornerRadius = 4;
    _nameLabel.layer.masksToBounds = YES;
    _nameLabel.hidden = YES;
    [self addSubview:_nameLabel];

    _micOffView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"mic.slash.fill"]];
    _micOffView.tintColor = [UIColor colorWithRed:1 green:0.27 blue:0.23 alpha:1];
    _micOffView.contentMode = UIViewContentModeScaleAspectFit;
    _micOffView.hidden = YES;
    [self addSubview:_micOffView];
    return self;
}

- (BOOL)isShareKind
{
    return [_kind isEqualToString:@"share"] || [_kind isEqualToString:@"active-share"];
}

- (void)setUnit:(NSDictionary *)unit
{
    _unit = [unit copy];
    NSInteger rgb = RNZoomUsInteger(unit, @"background", 0);
    self.backgroundColor = [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                                           green:((rgb >> 8) & 0xFF) / 255.0
                                            blue:(rgb & 0xFF) / 255.0
                                           alpha:1];
    BOOL border = RNZoomUsBool(unit, @"border", NO);
    self.layer.borderWidth = border ? 1 : 0;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    self.layer.cornerRadius = border ? 6 : 0;

    NSInteger aspect = RNZoomUsInteger(unit, @"aspectMode", 0);
    if (aspect != _lastAspect) {
        _lastAspect = aspect;
        [_videoView setVideoAspect:RNZoomUsAspect(aspect)];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    _videoView.frame = bounds;

    CGFloat inset = 6;
    CGFloat height = 18;
    CGFloat x = inset;
    if (!_micOffView.hidden) {
        _micOffView.frame = CGRectMake(x, CGRectGetHeight(bounds) - inset - height, height, height);
        x += height + 4;
    }
    if (!_nameLabel.hidden) {
        CGFloat maxWidth = MAX(0, CGRectGetWidth(bounds) - x - inset);
        CGSize fit = [_nameLabel sizeThatFits:CGSizeMake(maxWidth, height)];
        _nameLabel.frame = CGRectMake(x, CGRectGetHeight(bounds) - inset - height, MIN(fit.width + 10, maxWidth), height);
    }
}

- (void)stop
{
    if (_shownTarget == RNZoomUsNoTarget) return;
    _shownTarget = RNZoomUsNoTarget;
    if ([self isShareKind]) {
        [(MobileRTCActiveShareView *)_videoView stopActiveShare];
    } else {
        [_videoView stopAttendeeVideo];
    }
    _nameLabel.hidden = YES;
    _micOffView.hidden = YES;
    [self setNeedsLayout];
}

- (void)showTarget:(NSInteger)target
{
    if (target == RNZoomUsNoTarget) {
        [self stop];
        return;
    }
    if (target == _shownTarget) return;
    [self stop];
    BOOL shown = [self isShareKind]
        ? [(MobileRTCActiveShareView *)_videoView showActiveShareWithShareSourceID:(NSUInteger)target]
        : [_videoView showAttendeeVideoWithUserID:(NSUInteger)target];
    // Remember the target only if Zoom took it, so the next refresh retries.
    _shownTarget = shown ? target : RNZoomUsNoTarget;
    if (shown) {
        [_videoView setVideoAspect:RNZoomUsAspect(_lastAspect < 0 ? 0 : _lastAspect)];
        if ([self isShareKind]) {
            [(MobileRTCActiveShareView *)_videoView changeShareScaleWithShareSourceID:(NSUInteger)target];
        }
    }
}

/** Name badge and muted icon for the participant this unit renders. */
- (void)updateBadgeForUser:(NSInteger)userID service:(MobileRTCMeetingService *)ms
{
    MobileRTCMeetingUserInfo *info = (userID > 0 && ms) ? [ms userInfoByID:(NSUInteger)userID] : nil;
    BOOL wantName = RNZoomUsBool(_unit, @"showUsername", YES);
    BOOL wantMic = RNZoomUsBool(_unit, @"showAudioOff", YES);
    NSString *name = info.userName;

    BOOL nameHidden = !(wantName && name.length > 0);
    BOOL micHidden = !(wantMic && info != nil && info.audioStatus != nil
                       && (info.audioStatus.isMuted || info.audioStatus.audioType == MobileRTCAudioType_None));
    if (!nameHidden) _nameLabel.text = [NSString stringWithFormat:@" %@ ", name];
    if (nameHidden != _nameLabel.hidden || micHidden != _micOffView.hidden || !nameHidden) {
        _nameLabel.hidden = nameHidden;
        _micOffView.hidden = micHidden;
        [self setNeedsLayout];
    }
}

@end

#pragma mark - Container

@interface RNZoomUsVideoUnits ()
@property (nonatomic, strong) NSMutableArray<RNZoomUsVideoUnitCell *> *cells;
@property (nonatomic, assign) NSInteger activeShareSourceID;
@end

@implementation RNZoomUsVideoUnits

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _cells = [NSMutableArray array];
        _activeShareSourceID = 0;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        // Taps belong to the React Native controls drawn above.
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)dealloc
{
    for (RNZoomUsVideoUnitCell *cell in _cells) [cell stop];
}

- (void)setUnits:(NSArray *)units
{
    NSMutableArray<NSDictionary *> *valid = [NSMutableArray array];
    if ([units isKindOfClass:[NSArray class]]) {
        for (id unit in units) {
            if ([unit isKindOfClass:[NSDictionary class]]) [valid addObject:unit];
        }
    }

    // Reuse cells by position while the kind matches; a kind change needs a
    // different MobileRTC view class, so that cell is rebuilt.
    for (NSUInteger i = 0; i < valid.count; i++) {
        NSDictionary *unit = valid[i];
        NSString *kind = [unit[@"kind"] isKindOfClass:[NSString class]] ? unit[@"kind"] : @"active";
        RNZoomUsVideoUnitCell *cell = i < _cells.count ? _cells[i] : nil;
        if (cell && ![cell.kind isEqualToString:kind]) {
            [cell stop];
            [cell removeFromSuperview];
            cell = nil;
        }
        if (!cell) {
            cell = [[RNZoomUsVideoUnitCell alloc] initWithKind:kind];
            if (i < _cells.count) {
                _cells[i] = cell;
            } else {
                [_cells addObject:cell];
            }
            [self addSubview:cell];
        }
        cell.unit = unit;
        // Keep the stacking order equal to the array order (later on top).
        [self bringSubviewToFront:cell];
    }
    while (_cells.count > valid.count) {
        RNZoomUsVideoUnitCell *cell = _cells.lastObject;
        [cell stop];
        [cell removeFromSuperview];
        [_cells removeLastObject];
    }
    [self setNeedsLayout];
    [self refresh];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    for (RNZoomUsVideoUnitCell *cell in _cells) {
        NSDictionary *unit = cell.unit;
        CGFloat x = RNZoomUsPercent(unit, @"x", 0) / 100.0 * width;
        CGFloat y = RNZoomUsPercent(unit, @"y", 0) / 100.0 * height;
        CGFloat w = RNZoomUsPercent(unit, @"width", 100) / 100.0 * width;
        CGFloat h = RNZoomUsPercent(unit, @"height", 100) / 100.0 * height;
        cell.frame = CGRectMake(x, y, w, h);
    }
}

- (void)shareStatusChangedForUser:(NSUInteger)userID shareSourceID:(NSUInteger)shareSourceID active:(BOOL)active
{
    NSInteger source = shareSourceID != 0 ? (NSInteger)shareSourceID : (NSInteger)userID;
    if (active) {
        _activeShareSourceID = source;
    } else if (_activeShareSourceID == source || source == 0) {
        _activeShareSourceID = 0;
    }
    [self refresh];
}

- (void)stopAll
{
    for (RNZoomUsVideoUnitCell *cell in _cells) {
        [cell stop];
        [cell removeFromSuperview];
    }
    [_cells removeAllObjects];
    _activeShareSourceID = 0;
}

#pragma mark - Resolving targets

- (NSArray<NSNumber *> *)attendeesWithoutMe:(MobileRTCMeetingService *)ms
{
    NSArray<NSNumber *> *all = [ms getInMeetingUserList];
    if (![all isKindOfClass:[NSArray class]]) return @[];
    NSUInteger me = [ms myselfUserID];
    NSMutableArray<NSNumber *> *others = [NSMutableArray arrayWithCapacity:all.count];
    for (NSNumber *user in all) {
        if ([user isKindOfClass:[NSNumber class]] && user.unsignedIntegerValue != me) [others addObject:user];
    }
    return others;
}

- (NSInteger)firstShareSourceOfUser:(NSInteger)userID service:(MobileRTCMeetingService *)ms
{
    if (userID <= 0) return RNZoomUsNoTarget;
    NSArray<MobileRTCSSharingSourceInfo *> *sources = [ms getSharingSourceInfoList:userID];
    for (MobileRTCSSharingSourceInfo *info in sources) {
        if (![info isKindOfClass:[MobileRTCSSharingSourceInfo class]]) continue;
        MobileRTCSharingStatus status = [info getStatus];
        if (status == MobileRTCSharingStatus_Other_Share_End || status == MobileRTCSharingStatus_Self_Send_End) continue;
        NSUInteger source = [info getShareSourceID];
        if (source != 0) return (NSInteger)source;
    }
    return RNZoomUsNoTarget;
}

/** Whoever is sharing right now, for when the share event came before us. */
- (NSInteger)anyRemoteShareSource:(MobileRTCMeetingService *)ms
{
    NSUInteger me = [ms myselfUserID];
    for (NSNumber *user in [ms getInMeetingUserList] ?: @[]) {
        if (![user isKindOfClass:[NSNumber class]] || user.unsignedIntegerValue == me) continue;
        NSInteger source = [self firstShareSourceOfUser:user.integerValue service:ms];
        if (source != RNZoomUsNoTarget) return source;
    }
    return RNZoomUsNoTarget;
}

- (void)refresh
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    if (_cells.count == 0) return;

    MobileRTCMeetingService *ms = [[MobileRTC sharedRTC] getMeetingService];
    if (!RNZoomUsIsInMeeting(ms)) {
        // Between rooms (breakout switch, reconnect) user ids are reissued;
        // rendering a stale one shows a frozen frame, so show nothing.
        for (RNZoomUsVideoUnitCell *cell in _cells) [cell stop];
        _activeShareSourceID = 0;
        return;
    }

    NSUInteger me = [ms myselfUserID];
    NSArray<NSNumber *> *others = nil;

    for (RNZoomUsVideoUnitCell *cell in _cells) {
        NSString *kind = cell.kind;
        NSDictionary *unit = cell.unit;
        NSInteger target = RNZoomUsNoTarget;
        NSInteger badgeUser = RNZoomUsNoTarget;

        if ([kind isEqualToString:@"active"]) {
            NSUInteger active = [ms activeUserID];
            target = (NSInteger)(active != 0 ? active : me);
            badgeUser = target;
        } else if ([kind isEqualToString:@"preview"]) {
            target = me != 0 ? (NSInteger)me : RNZoomUsNoTarget;
            badgeUser = target;
        } else if ([kind isEqualToString:@"attendee"] || [kind isEqualToString:@"share"]) {
            NSInteger userID = RNZoomUsInteger(unit, @"userId", -1);
            if (userID < 0) {
                if (!others) others = [self attendeesWithoutMe:ms];
                NSInteger index = RNZoomUsInteger(unit, @"userIndex", 0);
                userID = (index >= 0 && index < (NSInteger)others.count) ? others[index].integerValue : RNZoomUsNoTarget;
            } else if (userID > 0 && [ms userInfoByID:(NSUInteger)userID] == nil) {
                // Left the meeting, or an id from the room we were in before.
                userID = RNZoomUsNoTarget;
            }
            badgeUser = userID;
            target = [kind isEqualToString:@"share"] ? [self firstShareSourceOfUser:userID service:ms] : userID;
        } else if ([kind isEqualToString:@"active-share"]) {
            if (_activeShareSourceID == 0) {
                NSInteger found = [self anyRemoteShareSource:ms];
                if (found != RNZoomUsNoTarget) _activeShareSourceID = found;
            }
            target = _activeShareSourceID != 0 ? _activeShareSourceID : RNZoomUsNoTarget;
        }

        [cell showTarget:target];
        if (![cell isShareKind]) [cell updateBadgeForUser:badgeUser service:ms];
    }
}

@end
