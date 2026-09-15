#import <AppKit/AppKit.h>

@interface CassotisInstallerController : NSWindowController <NSWindowDelegate>
@property(nonatomic, readonly) BOOL working;
@property(nonatomic, readonly) BOOL succeeded;
- (instancetype)initWithPayloadURL:(NSURL *)payload;
- (void)install:(id)sender;
@end
