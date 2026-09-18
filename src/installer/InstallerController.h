#import <AppKit/AppKit.h>

@interface CassotisInstallerController : NSWindowController <NSWindowDelegate>
@property(nonatomic, readonly) BOOL working;
@property(nonatomic, readonly) BOOL succeeded;
@property(nonatomic, readonly) BOOL enabling;
@property(nonatomic, readonly) BOOL inputSourceEnabled;
- (instancetype)initWithPayloadURL:(NSURL *)payload;
- (void)install:(id)sender;
@end
