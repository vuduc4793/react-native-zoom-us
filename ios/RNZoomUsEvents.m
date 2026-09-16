//
//  RNZoomUsEvents.m
//  react-native-zoom-us
//

#import "RNZoomUsEvents.h"

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
