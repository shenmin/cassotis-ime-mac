#import "InstallerController.h"

@interface CassotisInstallerDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) CassotisInstallerController *controller;
@end
@implementation CassotisInstallerDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSURL *payload=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"Payload"];
    self.controller=[[CassotisInstallerController alloc] initWithPayloadURL:payload];
    [self.controller showWindow:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { (void)sender; return YES; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender; return self.controller.working?NSTerminateCancel:NSTerminateNow;
}
@end
int main() {
    @autoreleasepool {
        [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSMenu *menu=[[NSMenu alloc] init]; NSMenuItem *item=[[NSMenuItem alloc] init];
        NSMenu *appMenu=[[NSMenu alloc] init]; [appMenu addItemWithTitle:@"退出安装程序" action:@selector(terminate:) keyEquivalent:@"q"];
        item.submenu=appMenu; [menu addItem:item]; NSApp.mainMenu=menu;
        CassotisInstallerDelegate *delegate=[[CassotisInstallerDelegate alloc] init]; NSApp.delegate=delegate;
        [NSApp run];
    }
    return 0;
}
