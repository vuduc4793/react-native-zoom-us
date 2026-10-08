//
//  RNZoomUsEvents.m
//  react-native-zoom-us
//

#import "RNZoomUsEvents.h"
#import <objc/runtime.h>

NSString *const RNZoomUsSDKCallbackNotification = @"RNZoomUsSDKCallback";
NSString *const RNZoomUsSDKCallbackEventKey = @"event";
NSString *const RNZoomUsSDKCallbackPayloadKey = @"payload";

void RNZoomUsEmit(NSString *event, NSDictionary *payload) {
    if (event.length == 0) return;

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
    userInfo[RNZoomUsSDKCallbackEventKey] = event;
    if (payload != nil) userInfo[RNZoomUsSDKCallbackPayloadKey] = payload;

    [[NSNotificationCenter defaultCenter] postNotificationName:RNZoomUsSDKCallbackNotification
                                                        object:nil
                                                      userInfo:userInfo];
}


static const NSUInteger RNZoomUsRefMax = 512;
static NSMutableDictionary<NSString *, id> *RNZoomUsRefsById;
static NSMapTable *RNZoomUsRefsByObject; // identity -> id
static NSMutableArray<NSString *> *RNZoomUsRefOrder; // least recently used first
static unsigned long long RNZoomUsRefNext = 0;

static void RNZoomUsRefInit(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        RNZoomUsRefsById = [NSMutableDictionary dictionary];
        RNZoomUsRefsByObject = [[NSMapTable alloc]
            initWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality
                  valueOptions:NSPointerFunctionsStrongMemory capacity:64];
        RNZoomUsRefOrder = [NSMutableArray array];
    });
}

NSString *RNZoomUsRefPut(id value) {
    RNZoomUsRefInit();
    @synchronized (RNZoomUsRefsById) {
        NSString *existing = [RNZoomUsRefsByObject objectForKey:value];
        if (existing && RNZoomUsRefsById[existing]) {
            [RNZoomUsRefOrder removeObject:existing];
            [RNZoomUsRefOrder addObject:existing];
            return existing;
        }
        NSString *refId = [NSString stringWithFormat:@"i%llu", ++RNZoomUsRefNext];
        RNZoomUsRefsById[refId] = value;
        [RNZoomUsRefsByObject setObject:refId forKey:value];
        [RNZoomUsRefOrder addObject:refId];
        while (RNZoomUsRefOrder.count > RNZoomUsRefMax) {
            NSString *oldest = RNZoomUsRefOrder.firstObject;
            [RNZoomUsRefOrder removeObjectAtIndex:0];
            id gone = RNZoomUsRefsById[oldest];
            [RNZoomUsRefsById removeObjectForKey:oldest];
            if (gone) [RNZoomUsRefsByObject removeObjectForKey:gone];
        }
        return refId;
    }
}

id RNZoomUsRefGet(NSString *refId) {
    if (![refId isKindOfClass:[NSString class]]) return nil;
    RNZoomUsRefInit();
    @synchronized (RNZoomUsRefsById) {
        return RNZoomUsRefsById[refId];
    }
}

void RNZoomUsRefRelease(NSString *refId) {
    if (![refId isKindOfClass:[NSString class]]) return;
    RNZoomUsRefInit();
    @synchronized (RNZoomUsRefsById) {
        id gone = RNZoomUsRefsById[refId];
        [RNZoomUsRefsById removeObjectForKey:refId];
        [RNZoomUsRefOrder removeObject:refId];
        if (gone) [RNZoomUsRefsByObject removeObjectForKey:gone];
    }
}

static const int RNZoomUsSerializeMaxDepth = 2;
static id RNZoomUsSerializeDepth(id value, int depth);

static NSString *RNZoomUsPublicTypeName(Class cls) {
    for (Class c = cls; c != Nil; c = class_getSuperclass(c)) {
        NSString *name = NSStringFromClass(c);
        if ([name hasPrefix:@"MobileRTC"]) return name;
    }
    return nil;
}

static BOOL RNZoomUsIsReadableSelectorName(NSString *name) {
    if ([name containsString:@":"] || [name hasPrefix:@"."] || [name hasPrefix:@"_"]) return NO;
    for (NSString *prefix in @[@"get", @"is", @"can", @"has"]) {
        if ([name hasPrefix:prefix] && name.length > prefix.length
            && [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[name characterAtIndex:prefix.length]]) {
            return YES;
        }
    }
    return NO;
}

/// Call a zero-argument selector and box what it returns, or nil when the
/// return type is not something JSON can carry (struct, pointer, SEL...).
static id RNZoomUsCallGetter(id target, SEL sel, int depth) {
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    if (sig == nil || sig.numberOfArguments != 2) return nil;
    const char *ret = sig.methodReturnType;
    while (*ret && strchr("rnNoORV", *ret)) ret++;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = sel;
    switch (*ret) {
        case '@': {
            [inv invoke];
            __unsafe_unretained id result = nil;
            [inv getReturnValue:&result];
            return RNZoomUsSerializeDepth(result, depth + 1);
        }
#define RNZOOM_BOX(code, type) case code: { [inv invoke]; type v = 0; [inv getReturnValue:&v]; return @(v); }
        RNZOOM_BOX('c', char) RNZOOM_BOX('C', unsigned char) RNZOOM_BOX('B', BOOL)
        RNZOOM_BOX('s', short) RNZOOM_BOX('S', unsigned short) RNZOOM_BOX('i', int)
        RNZOOM_BOX('I', unsigned int) RNZOOM_BOX('l', long) RNZOOM_BOX('L', unsigned long)
        RNZOOM_BOX('q', long long) RNZOOM_BOX('Q', unsigned long long)
        RNZOOM_BOX('f', float) RNZOOM_BOX('d', double)
#undef RNZOOM_BOX
        default:
            return nil;
    }
}

static NSDictionary *RNZoomUsSerializeObject(id value, NSString *type, int depth) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"__type"] = type;
    // Handlers and other SDK objects can be acted on from JS by this id.
    out[@"__ref"] = RNZoomUsRefPut(value);
    if (depth >= RNZoomUsSerializeMaxDepth) return out;

    NSMutableDictionary<NSString *, NSString *> *selectors = [NSMutableDictionary dictionary]; // key -> selector
    for (Class c = [value class]; c != Nil && RNZoomUsPublicTypeName(c) != nil; c = class_getSuperclass(c)) {
        unsigned int count = 0;
        objc_property_t *props = class_copyPropertyList(c, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = @(property_getName(props[i]));
            char *getter = property_copyAttributeValue(props[i], "G");
            NSString *selName = getter ? @(getter) : name;
            if (getter) free(getter);
            if (!selectors[name]) selectors[name] = selName;
        }
        free(props);
        Method *methods = class_copyMethodList(c, &count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *selName = NSStringFromSelector(method_getName(methods[i]));
            if (!RNZoomUsIsReadableSelectorName(selName)) continue;
            NSString *key = selName;
            if ([selName hasPrefix:@"get"]) {
                key = [[[selName substringWithRange:NSMakeRange(3, 1)] lowercaseString]
                       stringByAppendingString:[selName substringFromIndex:4]];
            }
            if (!selectors[key]) selectors[key] = selName;
        }
        free(methods);
    }
    for (NSString *key in selectors) {
        SEL sel = NSSelectorFromString(selectors[key]);
        if (![value respondsToSelector:sel]) continue;
        @try {
            id boxed = RNZoomUsCallGetter(value, sel, depth);
            if (boxed) out[key] = boxed;
        } @catch (NSException *ex) {
            // A getter that raises is left out rather than failing the event.
        }
    }
    return out;
}

static id RNZoomUsSerializeDepth(id value, int depth) {
    if (value == nil || value == [NSNull null]) return [NSNull null];
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSDate class]]) return @([(NSDate *)value timeIntervalSince1970] * 1000.0);
    if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSSet class]]) {
        NSMutableArray *out = [NSMutableArray array];
        if (depth > RNZoomUsSerializeMaxDepth) return out;
        for (id item in (id<NSFastEnumeration>)value) [out addObject:RNZoomUsSerializeDepth(item, depth + 1)];
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        if (depth > RNZoomUsSerializeMaxDepth) return out;
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) {
            out[[k description]] = RNZoomUsSerializeDepth(v, depth + 1);
        }];
        return out;
    }
    NSString *type = RNZoomUsPublicTypeName([value class]);
    if (type == nil) return @{@"__type": NSStringFromClass([value class]) ?: @"unknown"};
    return RNZoomUsSerializeObject(value, type, depth);
}

id RNZoomUsSerialize(id value) {
    @try {
        return RNZoomUsSerializeDepth(value, 0);
    } @catch (NSException *ex) {
        return [NSNull null];
    }
}


@interface RNZoomUsPromptResponder : NSObject
@property (nonatomic, readonly) BOOL answered;
- (instancetype)initWithAnswer:(void (^)(BOOL accept))answer;
/// Answer the prompt. Returns NO when it was already answered (by JS or by the
/// timeout), in which case nothing happens.
- (BOOL)respond:(BOOL)accept;
@end

@implementation RNZoomUsPromptResponder {
    void (^_answer)(BOOL);
}
- (instancetype)initWithAnswer:(void (^)(BOOL))answer {
    if ((self = [super init])) _answer = [answer copy];
    return self;
}
- (BOOL)respond:(BOOL)accept {
    void (^answer)(BOOL) = nil;
    @synchronized (self) {
        if (_answered) return NO;
        _answered = YES;
        answer = _answer;
        _answer = nil;
    }
    if (answer) {
        if ([NSThread isMainThread]) answer(accept);
        else dispatch_async(dispatch_get_main_queue(), ^{ answer(accept); });
    }
    return YES;
}
@end

static NSMutableDictionary<NSString *, NSDictionary *> *RNZoomUsPromptModes;

void RNZoomUsSetPromptMode(NSString *prompt, NSString *mode, double timeoutMs) {
    if (![prompt isKindOfClass:[NSString class]]) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ RNZoomUsPromptModes = [NSMutableDictionary dictionary]; });
    @synchronized (RNZoomUsPromptModes) {
        RNZoomUsPromptModes[prompt] = @{
            @"mode": [mode isEqual:@"js"] ? @"js" : @"auto",
            @"timeoutMs": @(timeoutMs > 0 ? timeoutMs : 10000),
        };
    }
}

NSDictionary *RNZoomUsOfferPrompt(NSString *prompt, BOOL defaultAnswer, void (^answer)(BOOL)) {
    NSDictionary *config = nil;
    if (RNZoomUsPromptModes) {
        @synchronized (RNZoomUsPromptModes) { config = RNZoomUsPromptModes[prompt]; }
    }
    if (answer == nil) return @{@"mode": @"none"};
    if (![config[@"mode"] isEqual:@"js"]) {
        answer(defaultAnswer);
        return @{@"mode": @"auto", @"defaultAnswer": @(defaultAnswer)};
    }
    RNZoomUsPromptResponder *responder = [[RNZoomUsPromptResponder alloc] initWithAnswer:answer];
    NSString *ref = RNZoomUsRefPut(responder);
    double timeoutMs = [config[@"timeoutMs"] doubleValue];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutMs * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if ([responder respond:defaultAnswer]) {
            NSLog(@"RNZoomUs: prompt %@ not answered by JS in %.0fms, used default", prompt, timeoutMs);
        }
        RNZoomUsRefRelease(ref);
    });
    return @{
        @"mode": @"js",
        @"defaultAnswer": @(defaultAnswer),
        @"timeoutMs": @(timeoutMs),
        @"responder": @{@"__ref": ref, @"__type": @"RNZoomUsPromptResponder"},
    };
}
