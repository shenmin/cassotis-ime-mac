#import "InstallerController.h"
#import "InputSourceRegistration.h"
#include <cstdio>

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
int main(int argc,const char **argv) {
    @autoreleasepool {
        if(argc==2 && strcmp(argv[1],"--input-source-status")==0) {
            NSData *data=[NSJSONSerialization dataWithJSONObject:CassotisInputSourceRegistrationState() options:0 error:nil];
            if(!data) return 1;
            fwrite(data.bytes,1,data.length,stdout); fputc('\n',stdout); return 0;
        }
        [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        NSMenu *menu=[[NSMenu alloc] init]; NSMenuItem *item=[[NSMenuItem alloc] init];
        NSMenu *appMenu=[[NSMenu alloc] init]; [appMenu addItemWithTitle:@"退出安装程序" action:@selector(terminate:) keyEquivalent:@"q"];
        item.submenu=appMenu; [menu addItem:item]; NSApp.mainMenu=menu;
        CassotisInstallerDelegate *delegate=[[CassotisInstallerDelegate alloc] init]; NSApp.delegate=delegate;
        [NSApp run];
    }
    return 0;
}
