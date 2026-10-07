//
//  RNZoomUsCommands.m
//

#import "RNZoomUsCommands.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <MobileRTC/MobileRTC.h>

/// How deep to follow SDK objects when flattening a return value. Some of them
/// hold references back into the meeting graph, so this has to be bounded.
static const NSInteger kMaxDepth = 2;

static NSError *RNZoomUsCommandsError(NSString *message) {
    return [NSError errorWithDomain:@"us.zoom.sdk.commands"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"unknown"}];
}

/// Strip the qualifiers Objective-C puts in front of a type encoding (`r` for
/// const, `n`/`N` for in/inout, and so on) so the switch below only has to deal
/// with the type itself.
static const char *RNZoomUsSkipQualifiers(const char *enc) {
    while (enc && *enc && strchr("rnNoORV", *enc) != NULL) enc++;
    return enc;
}

@implementation RNZoomUsCommands

+ (nullable id)resolve:(nullable NSString *)path error:(NSError **)error {
    id target = [MobileRTC sharedRTC];
    if (target == nil) {
        if (error) *error = RNZoomUsCommandsError(@"[MobileRTC sharedRTC] is nil; the SDK is not loaded");
        return nil;
    }
    if (path == nil || path.length == 0) return target;

    for (NSString *rawStep in [path componentsSeparatedByString:@"."]) {
        NSString *step = [rawStep stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        if (step.length == 0) continue;

        SEL sel = NSSelectorFromString(step);
        if (![target respondsToSelector:sel]) {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ does not respond to %@ while resolving %@",
                NSStringFromClass([target class]), step, path]);
            return nil;
        }
        NSMethodSignature *sig = [target methodSignatureForSelector:sel];
        if (sig.numberOfArguments != 2 || RNZoomUsSkipQualifiers(sig.methodReturnType)[0] != '@') {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ is not a zero-argument getter returning an object, so it cannot be a route step",
                step]);
            return nil;
        }

        id next = nil;
        @try {
            next = ((id (*)(id, SEL))objc_msgSend)(target, sel);
        } @catch (NSException *ex) {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ threw %@: %@", step, ex.name, ex.reason]);
            return nil;
        }
        if (next == nil) {
            // Matches the Android bridge: a service getter returns nil until the
            // SDK reaches the state that owns it, and saying so beats a crash.
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ returned nil; the SDK is not in a state where %@ exists yet",
                step, path]);
            return nil;
        }
        target = next;
    }
    return target;
}

/// Candidate selectors for a call. JavaScript sends what the generated types
/// say, which for anything taking arguments is the full selector. A bare name
/// with one argument is also accepted because it is the obvious thing to write.
+ (NSArray<NSString *> *)candidatesFor:(NSString *)name argCount:(NSUInteger)count {
    if ([name containsString:@":"]) return @[name];
    if (count == 0) return @[name];
    if (count == 1) return @[[name stringByAppendingString:@":"]];
    return @[];
}

+ (nullable id)call:(id)target
           selector:(NSString *)name
               args:(nullable NSArray *)args
              error:(NSError **)error {
    NSUInteger count = args == nil ? 0 : args.count;

    if (name.length == 0) {
        if (error) *error = RNZoomUsCommandsError(@"no method name");
        return nil;
    }
    // +1 returns are not safe through NSInvocation: it does not know the
    // ownership convention, so the object would be over-released or leaked.
    for (NSString *prefix in @[@"alloc", @"new", @"copy", @"mutableCopy"]) {
        if ([name hasPrefix:prefix]) {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ follows the +1 ownership convention and cannot cross the generic bridge", name]);
            return nil;
        }
    }

    NSArray<NSString *> *candidates = [self candidatesFor:name argCount:count];
    if (candidates.count == 0) {
        if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
            @"%@ takes %lu arguments, so JavaScript has to send the full selector "
            @"(for example \"setVideoQuality:userID:\")", name, (unsigned long)count]);
        return nil;
    }

    SEL sel = NULL;
    NSMethodSignature *sig = nil;
    for (NSString *candidate in candidates) {
        SEL s = NSSelectorFromString(candidate);
        if (s != NULL && [target respondsToSelector:s]) {
            sel = s;
            sig = [target methodSignatureForSelector:s];
            break;
        }
    }
    if (sel == NULL || sig == nil) {
        if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
            @"%@ does not respond to %@", NSStringFromClass([target class]),
            [candidates componentsJoinedByString:@" or "]]);
        return nil;
    }

    NSUInteger expected = sig.numberOfArguments - 2;
    if (expected != count) {
        if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
            @"%@ takes %lu argument(s) but %lu were given",
            NSStringFromSelector(sel), (unsigned long)expected, (unsigned long)count]);
        return nil;
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.target = target;
    inv.selector = sel;

    // Primitive arguments need storage that outlives the setArgument: call;
    // object arguments stay alive because `args` holds them for the whole call.
    NSMutableArray<NSMutableData *> *scratch = [NSMutableArray arrayWithCapacity:count];

    for (NSUInteger i = 0; i < count; i++) {
        const char *enc = RNZoomUsSkipQualifiers([sig getArgumentTypeAtIndex:i + 2]);
        id value = args[i];
        if ([value isKindOfClass:[NSNull class]]) value = nil;

        if (enc[0] == '@') {
            if (value != nil &&
                !([value isKindOfClass:[NSString class]] ||
                  [value isKindOfClass:[NSNumber class]] ||
                  [value isKindOfClass:[NSArray class]] ||
                  [value isKindOfClass:[NSDictionary class]])) {
                if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                    @"argument %lu is a %@, which the bridge cannot carry",
                    (unsigned long)i, NSStringFromClass([value class])]);
                return nil;
            }
            __unsafe_unretained id unretained = value;
            [inv setArgument:&unretained atIndex:(NSInteger)(i + 2)];
            continue;
        }

        if (value == nil) {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"argument %lu is null but %s is not an object", (unsigned long)i, enc]);
            return nil;
        }
        if (![value isKindOfClass:[NSNumber class]]) {
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"argument %lu must be a number or boolean for %s", (unsigned long)i, enc]);
            return nil;
        }

        NSNumber *num = (NSNumber *)value;
        NSUInteger size = 0, align = 0;
        NSGetSizeAndAlignment(enc, &size, &align);
        NSMutableData *slot = [NSMutableData dataWithLength:size > 0 ? size : sizeof(void *)];
        [scratch addObject:slot];
        void *buf = slot.mutableBytes;

        switch (enc[0]) {
            case 'B': *(bool *)buf = num.boolValue; break;
            case 'c': *(char *)buf = num.charValue; break;
            case 'C': *(unsigned char *)buf = num.unsignedCharValue; break;
            case 's': *(short *)buf = num.shortValue; break;
            case 'S': *(unsigned short *)buf = num.unsignedShortValue; break;
            case 'i': *(int *)buf = num.intValue; break;
            case 'I': *(unsigned int *)buf = num.unsignedIntValue; break;
            case 'l': *(long *)buf = (long)num.longLongValue; break;
            case 'L': *(unsigned long *)buf = (unsigned long)num.unsignedLongLongValue; break;
            case 'q': *(long long *)buf = num.longLongValue; break;
            case 'Q': *(unsigned long long *)buf = num.unsignedLongLongValue; break;
            case 'f': *(float *)buf = num.floatValue; break;
            case 'd': *(double *)buf = num.doubleValue; break;
            default:
                // Structs, unions, pointers, Class and SEL are refused rather
                // than guessed at: a wrong guess here is a crash, and native
                // cannot be fixed over the air.
                if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                    @"argument %lu has type \"%s\", which needs a native wrapper "
                    @"rather than the generic bridge", (unsigned long)i, enc]);
                return nil;
        }
        [inv setArgument:buf atIndex:(NSInteger)(i + 2)];
    }

    @try {
        [inv invoke];
    } @catch (NSException *ex) {
        if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
            @"%@ threw %@: %@", NSStringFromSelector(sel), ex.name, ex.reason]);
        return nil;
    }

    const char *ret = RNZoomUsSkipQualifiers(sig.methodReturnType);
    switch (ret[0]) {
        case 'v': return nil;
        case '@': {
            void *raw = NULL;
            [inv getReturnValue:&raw];
            return [self marshal:(__bridge id)raw depth:0];
        }
        case 'B': { bool v = false; [inv getReturnValue:&v]; return @(v); }
        case 'c': { char v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'C': { unsigned char v = 0; [inv getReturnValue:&v]; return @(v); }
        case 's': { short v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'S': { unsigned short v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'i': { int v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'I': { unsigned int v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'l': { long v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'L': { unsigned long v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'q': { long long v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'Q': { unsigned long long v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'f': { float v = 0; [inv getReturnValue:&v]; return @(v); }
        case 'd': { double v = 0; [inv getReturnValue:&v]; return @(v); }
        case '#': {
            Class v = Nil; [inv getReturnValue:&v];
            return v == Nil ? nil : NSStringFromClass(v);
        }
        default:
            if (error) *error = RNZoomUsCommandsError([NSString stringWithFormat:
                @"%@ returns \"%s\", which the bridge cannot carry",
                NSStringFromSelector(sel), ret]);
            return nil;
    }
}

+ (nullable id)marshal:(nullable id)value depth:(NSInteger)depth {
    if (value == nil || [value isKindOfClass:[NSNull class]]) return nil;
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return @([(NSDate *)value timeIntervalSince1970] * 1000.0);
    }
    if ([value isKindOfClass:[NSData class]]) {
        return @{@"byteLength": @(((NSData *)value).length)};
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *out = [NSMutableArray array];
        for (id item in (NSArray *)value) {
            id m = [self marshal:item depth:depth + 1];
            [out addObject:m ?: [NSNull null]];
        }
        return out;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id k, id v, __unused BOOL *stop) {
            id m = [self marshal:v depth:depth + 1];
            out[[k description]] = m ?: [NSNull null];
        }];
        return out;
    }

    if (depth >= kMaxDepth) return [value description];

    // An SDK object: flatten its declared properties. Reading @property is far
    // safer than invoking every zero-argument selector the way the Java side
    // can afford to -- on Objective-C that would also hit action methods and
    // initialisers.
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (Class cls = [value class]; cls != Nil && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int n = 0;
        objc_property_t *props = class_copyPropertyList(cls, &n);
        if (props == NULL) continue;
        for (unsigned int i = 0; i < n; i++) {
            NSString *key = @(property_getName(props[i]));
            if (key.length == 0 || out[key] != nil) continue;
            @try {
                id raw = [value valueForKey:key];
                id m = [self marshal:raw depth:depth + 1];
                out[key] = m ?: [NSNull null];
            } @catch (NSException *ex) {
                // A property that throws outside a meeting is normal; the key
                // is left out rather than failing the whole call.
            }
        }
        free(props);
    }
    return out;
}

@end
