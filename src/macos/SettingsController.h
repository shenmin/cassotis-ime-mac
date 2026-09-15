#import <AppKit/AppKit.h>
@interface CassotisSettingsController : NSWindowController
+ (instancetype)shared;
- (void)reloadSettings;
@end
