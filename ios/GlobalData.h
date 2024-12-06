@interface GlobalData : NSObject

+ (instancetype)sharedInstance;
@property (nonatomic, assign) NSUInteger userID;
@property (nonatomic, assign) NSUInteger globalActiveShareID;
@property (nonatomic, assign) NSUUID *globalCallingUUID;

@end
