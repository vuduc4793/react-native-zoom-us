//
//  RNZoomUsListeners.m
//  react-native-zoom-us
//

#import "RNZoomUsListeners.h"
#import "RNZoomUsEvents.h"
#import <objc/runtime.h>
#import <MobileRTC/MobileRTC.h>

static NSError *RNZoomUsListenersError(NSString *message) {
    return [NSError errorWithDomain:@"us.zoom.sdk.listeners"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"unknown"}];
}

static const char *RNZoomUsListenersSkipQualifiers(const char *enc) {
    while (enc && *enc && strchr("rnNoORV", *enc) != NULL) enc++;
    return enc;
}

static void RNZoomUsOnMain(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

#pragma mark - Generic delegate (createListener)

@implementation RNZoomUsDelegateProxy {
    Protocol *_protocol;
    // selector name -> type encoding, for every instance method of the protocol
    NSDictionary<NSString *, NSString *> *_methods;
}

/// Instance methods of `proto` and everything it adopts, except NSObject's own
/// protocol: NSObject already implements those, and answering them here would
/// turn -description and friends into events.
static void RNZoomUsCollectMethods(Protocol *proto, NSMutableDictionary<NSString *, NSString *> *out,
                                   NSHashTable *seen) {
    if (proto == NULL || [seen containsObject:proto]) return;
    [seen addObject:proto];
    if (protocol_isEqual(proto, @protocol(NSObject))) return;
    for (int required = 1; required >= 0; required--) {
        unsigned int count = 0;
        struct objc_method_description *list = protocol_copyMethodDescriptionList(proto, (BOOL)required, YES, &count);
        for (unsigned int i = 0; list != NULL && i < count; i++) {
            if (list[i].name == NULL || list[i].types == NULL) continue;
            NSString *name = NSStringFromSelector(list[i].name);
            if (out[name] == nil) out[name] = @(list[i].types);
        }
        if (list) free(list);
    }
    unsigned int adoptedCount = 0;
    Protocol * __unsafe_unretained *adopted = protocol_copyProtocolList(proto, &adoptedCount);
    for (unsigned int i = 0; adopted != NULL && i < adoptedCount; i++) {
        RNZoomUsCollectMethods(adopted[i], out, seen);
    }
    if (adopted) free(adopted);
}

+ (instancetype)proxyForProtocolNamed:(NSString *)protocolName error:(NSError **)error {
    if (![protocolName isKindOfClass:[NSString class]] || protocolName.length == 0) {
        if (error) *error = RNZoomUsListenersError(@"no protocol name");
        return nil;
    }
    Protocol *proto = NSProtocolFromString(protocolName);
    if (proto == NULL) {
        if (error) *error = RNZoomUsListenersError([NSString stringWithFormat:
            @"%@ is not a protocol in this SDK build", protocolName]);
        return nil;
    }
    NSMutableDictionary *methods = [NSMutableDictionary dictionary];
    @try {
        RNZoomUsCollectMethods(proto, methods, [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaquePersonality | NSPointerFunctionsOpaqueMemory]);
    } @catch (NSException *ex) {
        if (error) *error = RNZoomUsListenersError([NSString stringWithFormat:
            @"reading %@ threw %@: %@", protocolName, ex.name, ex.reason]);
        return nil;
    }
    RNZoomUsDelegateProxy *proxy = [[self alloc] init];
    proxy->_protocol = proto;
    proxy->_protocolName = [protocolName copy];
    proxy->_methods = [methods copy];
    return proxy;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    if (aProtocol != NULL && _protocol != NULL &&
        (protocol_isEqual(_protocol, aProtocol) || protocol_conformsToProtocol(_protocol, aProtocol))) {
        return YES;
    }
    return [super conformsToProtocol:aProtocol];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector != NULL && _methods[NSStringFromSelector(aSelector)] != nil) return YES;
    return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *own = [super methodSignatureForSelector:aSelector];
    if (own != nil) return own;
    NSString *types = aSelector != NULL ? _methods[NSStringFromSelector(aSelector)] : nil;
    if (types == nil) return nil;
    @try {
        return [NSMethodSignature signatureWithObjCTypes:types.UTF8String];
    } @catch (NSException *ex) {
        NSLog(@"RNZoomUs: no signature for %@ (%@): %@", NSStringFromSelector(aSelector), types, ex.reason);
        return nil;
    }
}

/// One argument as something the bridge can carry.
static id RNZoomUsBoxArgument(NSInvocation *inv, NSUInteger index) {
    const char *enc = RNZoomUsListenersSkipQualifiers([inv.methodSignature getArgumentTypeAtIndex:index]);
    switch (enc[0]) {
        case '@': {
            if (enc[1] == '?') return [NSNull null]; // a block cannot cross the bridge
            __unsafe_unretained id value = nil;
            [inv getArgument:&value atIndex:(NSInteger)index];
            return RNZoomUsSerialize(value);
        }
        case '#': {
            __unsafe_unretained Class value = Nil;
            [inv getArgument:&value atIndex:(NSInteger)index];
            return value == Nil ? [NSNull null] : NSStringFromClass(value);
        }
        case ':': {
            SEL value = NULL;
            [inv getArgument:&value atIndex:(NSInteger)index];
            return value == NULL ? [NSNull null] : NSStringFromSelector(value);
        }
#define RNZOOM_ARG(code, type) case code: { type v = 0; [inv getArgument:&v atIndex:(NSInteger)index]; return @(v); }
        RNZOOM_ARG('c', char) RNZOOM_ARG('C', unsigned char) RNZOOM_ARG('B', bool)
        RNZOOM_ARG('s', short) RNZOOM_ARG('S', unsigned short) RNZOOM_ARG('i', int)
        RNZOOM_ARG('I', unsigned int) RNZOOM_ARG('l', long) RNZOOM_ARG('L', unsigned long)
        RNZOOM_ARG('q', long long) RNZOOM_ARG('Q', unsigned long long)
        RNZOOM_ARG('f', float) RNZOOM_ARG('d', double)
#undef RNZOOM_ARG
        default:
            return [NSNull null]; // pointers, structs, unions
    }
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *method = NSStringFromSelector(invocation.selector);
    if (method == nil || _methods[method] == nil) {
        [super forwardInvocation:invocation];
        return;
    }
    NSMethodSignature *sig = invocation.methodSignature;
    NSMutableArray *args = [NSMutableArray array];
    @try {
        for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
            id boxed = nil;
            @try {
                boxed = RNZoomUsBoxArgument(invocation, i);
            } @catch (NSException *ex) {
                boxed = nil;
            }
            [args addObject:boxed ?: [NSNull null]];
        }
        // The interface default: NO / 0 / nil, so Zoom keeps its own behaviour.
        const char *ret = RNZoomUsListenersSkipQualifiers(sig.methodReturnType);
        if (ret[0] != 'v' && sig.methodReturnLength > 0) {
            NSMutableData *zero = [NSMutableData dataWithLength:sig.methodReturnLength];
            [invocation setReturnValue:zero.mutableBytes];
        }
    } @catch (NSException *ex) {
        NSLog(@"RNZoomUs: listener %@ %@ failed: %@", _refId, method, ex.reason);
    }
    RNZoomUsEmit(@"onListenerCallback", @{
        @"listener": _refId ?: [NSNull null],
        @"method": method,
        @"args": args,
    });
}

@end

#pragma mark - Reminder delegate (setPromptMode "reminder")

@interface RNZoomUsReminderListener : NSObject <MobileRTCReminderDelegate>
@end

@implementation RNZoomUsReminderListener
- (void)onReminderNotify:(MobileRTCReminderContent *)content handle:(MobileRTCReminderHandler *)handler {
    id handlerPayload = [NSNull null];
    id contentPayload = [NSNull null];
    @try {
        if (handler != nil) {
            // Pinned: JS answers whenever the user does, and an evicted handler
            // would leave the reminder unanswerable.
            handlerPayload = @{@"__ref": RNZoomUsRefPin(handler),
                               @"__type": NSStringFromClass([handler class]) ?: @"MobileRTCReminderHandler"};
        }
        contentPayload = RNZoomUsSerialize(content);
    } @catch (NSException *ex) {
        NSLog(@"RNZoomUs: onReminderNotify serialization failed: %@", ex.reason);
    }
    RNZoomUsEmit(@"onReminderNotify", @{@"content": contentPayload ?: [NSNull null],
                                         @"handler": handlerPayload ?: [NSNull null]});
}
@end

// reminderDelegate is weak, so the listener is owned here.
static RNZoomUsReminderListener *RNZoomUsReminderListenerInstance;
static BOOL RNZoomUsReminderJS = NO;
static BOOL RNZoomUsReminderModeTouched = NO;

void RNZoomUsApplyReminderMode(void) {
    // Never touched by JS: leave the SDK exactly as it has always been.
    if (!RNZoomUsReminderModeTouched) return;
    RNZoomUsOnMain(^{
        @try {
            MobileRTC *rtc = [MobileRTC sharedRTC];
            if (rtc == nil || ![rtc respondsToSelector:@selector(getReminderHelper)]) return;
            MobileRTCReminderHelper *helper = [rtc getReminderHelper];
            if (helper == nil || ![helper respondsToSelector:@selector(setReminderDelegate:)]) return;
            if (RNZoomUsReminderJS) {
                if (RNZoomUsReminderListenerInstance == nil) {
                    RNZoomUsReminderListenerInstance = [[RNZoomUsReminderListener alloc] init];
                }
                helper.reminderDelegate = RNZoomUsReminderListenerInstance;
            } else {
                helper.reminderDelegate = nil;
            }
        } @catch (NSException *ex) {
            NSLog(@"RNZoomUs: setting reminderDelegate failed: %@", ex.reason);
        }
    });
}

void RNZoomUsSetReminderMode(NSString *mode) {
    RNZoomUsReminderModeTouched = YES;
    RNZoomUsReminderJS = [mode isKindOfClass:[NSString class]] && [mode isEqualToString:@"js"];
    RNZoomUsApplyReminderMode();
}

NSString *RNZoomUsReminderMethodName(id target, NSString *method) {
    Class handlerClass = NSClassFromString(@"MobileRTCReminderHandler");
    if (handlerClass != Nil && [target isKindOfClass:handlerClass] && [method isEqual:@"decline"]) {
        return @"declined"; // Android calls it decline(); keep JS identical on both
    }
    return method;
}

void RNZoomUsAfterInvokeRef(id target, NSString *refId, NSString *method) {
    Class handlerClass = NSClassFromString(@"MobileRTCReminderHandler");
    if (handlerClass == Nil || ![target isKindOfClass:handlerClass]) return;
    if ([@[@"accept", @"declined", @"decline", @"ignore"] containsObject:method ?: @""]) {
        RNZoomUsRefUnpin(refId);
    }
}

#pragma mark - Toolbar button overrides (setButtonOverrides)

static NSDictionary<NSString *, NSNumber *> *RNZoomUsButtonOverrides;

static NSObject *RNZoomUsButtonLock(void) {
    static NSObject *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSObject alloc] init]; });
    return lock;
}

void RNZoomUsSetButtonOverrides(NSDictionary *overrides) {
    NSMutableDictionary *clean = [NSMutableDictionary dictionary];
    if ([overrides isKindOfClass:[NSDictionary class]]) {
        [overrides enumerateKeysAndObjectsUsingBlock:^(id key, id value, __unused BOOL *stop) {
            if (![key isKindOfClass:[NSString class]]) return;
            clean[key] = @([value isKindOfClass:[NSNumber class]] && [value boolValue]);
        }];
    }
    @synchronized (RNZoomUsButtonLock()) {
        RNZoomUsButtonOverrides = [clean copy];
    }
}

BOOL RNZoomUsMeetingButtonClicked(NSString *button, BOOL baseline) {
    BOOL override = NO;
    @synchronized (RNZoomUsButtonLock()) {
        override = button != nil && [RNZoomUsButtonOverrides[button] boolValue];
    }
    BOOL handled = baseline || override;
    RNZoomUsEmit(@"onClickMeetingButton", @{@"button": button ?: @"", @"handled": @(handled)});
    return handled;
}
