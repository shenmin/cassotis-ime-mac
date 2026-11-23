#import <AppKit/AppKit.h>
@interface CassotisSettingsController : NSWindowController
+ (instancetype)shared;
- (void)reloadSettings;
@end

void CassotisShowAboutPanel(void);
BOOL CassotisSettingsFieldKey(NSControl *control, NSEvent *event);
