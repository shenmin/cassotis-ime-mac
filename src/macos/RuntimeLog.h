#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const CassotisRuntimeLoggingEnabledKey;

@interface CassotisRuntimeLog : NSObject
+ (instancetype)shared;
- (instancetype)initWithDirectory:(NSURL *)directory defaults:(NSUserDefaults *)defaults;
@property(nonatomic) BOOL enabled;
- (NSPipe *)captureOutputOfTask:(NSTask *)task;
- (void)appendData:(NSData *)data;
@end
NS_ASSUME_NONNULL_END
