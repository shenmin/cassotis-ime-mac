#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>
#import <os/log.h>
#import "InputSession.h"
#import "SettingsController.h"
#import "ProductName.h"

static void CassotisShowAboutPanel(void) {
    NSMutableParagraphStyle *paragraph=[[NSMutableParagraphStyle alloc] init];
    paragraph.alignment=NSTextAlignmentCenter;
    NSAttributedString *website=[[NSAttributedString alloc] initWithString:CassotisWebsiteURL().absoluteString
        attributes:@{NSLinkAttributeName:CassotisWebsiteURL(),
            NSFontAttributeName:[NSFont systemFontOfSize:12],
            NSForegroundColorAttributeName:NSColor.linkColor,
            NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle),
            NSParagraphStyleAttributeName:paragraph}];
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName:CassotisProductName(),
        NSAboutPanelOptionCredits:website}];
    [NSApp activateIgnoringOtherApps:YES];
}

@interface CassotisInputController : IMKInputController
@end
@implementation CassotisInputController {
    CassotisInputSession *_session;
}
// Opt-in lifecycle diagnostics record identities and lengths, never input text.
- (void)trace:(const char *)operation sender:(id)sender {
    if(!getenv("CASSOTIS_TRACE_INPUT")) return;
    NSString *bundle=@"unknown";
    @try { if([sender respondsToSelector:@selector(bundleIdentifier)]) bundle=[sender bundleIdentifier]; }
    @catch(NSException *error) { (void)error; }
    os_log(OS_LOG_DEFAULT,"Cassotis lifecycle %{public}s controller=%p sender=%p current=%p marked=%lu bundle=%{public}@ foreground=%{public}@",
        operation,self,sender,_session.client,(unsigned long)_session.preedit.length,bundle,
        NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier);
}
- (id)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)client {
    self=[super initWithServer:server delegate:delegate client:client];
    if(self) _session=[[CassotisInputSession alloc] init]; return self;
}
- (NSUInteger)recognizedEvents:(id)sender {
    (void)sender; return NSEventMaskKeyDown|NSEventMaskKeyUp|NSEventMaskFlagsChanged|
        NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown;
}
- (void)activateServer:(id)sender {
    [self trace:"activate" sender:sender];
    if(![_session activateFromNotification:sender]) [self trace:"ignored-background-activate" sender:sender];
}
- (void)deactivateServer:(id)sender { [self trace:"deactivate" sender:sender]; [_session deactivate]; }
- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    if(event.type==NSEventTypeKeyUp) return NO;
    [self trace:event.type==NSEventTypeKeyDown?"key-down":"other-event" sender:sender];
    if(_session.client!=sender && event.type!=NSEventTypeKeyDown) return NO;
    if(_session.client!=sender) [_session activate:sender];
    return [_session handleEvent:event];
}
- (void)commitComposition:(id)sender { [self trace:"commit" sender:sender]; [_session commit]; }
- (void)cancelComposition:(id)sender { [self trace:"cancel" sender:sender]; [_session cancel]; }
- (void)showPreferences:(id)sender { (void)sender; [_session showSettings]; }
- (void)modeAction:(id)sender {
    NSMenuItem *item=[sender isKindOfClass:NSDictionary.class]?sender[kIMKCommandMenuItemName]:sender;
    [_session toggle:item.tag];
}
- (void)aboutAction:(id)sender {
    (void)sender;
    CassotisShowAboutPanel();
}
- (NSMenu *)menu {
    NSMenu *menu=[_session modeMenuWithTarget:self action:@selector(modeAction:)];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings=[[NSMenuItem alloc] initWithTitle:@"设置…" action:@selector(showPreferences:) keyEquivalent:@""];
    settings.target=self; [menu addItem:settings];
    NSMenuItem *about=[[NSMenuItem alloc] initWithTitle:[@"关于" stringByAppendingString:CassotisShortName()] action:@selector(aboutAction:) keyEquivalent:@""];
    about.target=self; [menu addItem:about]; return menu;
}
@end

@interface CassotisAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) IMKServer *server;
@end
@implementation CassotisAppDelegate
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification; CassotisStopEngine();
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification; CassotisStartEngine();
    if([NSProcessInfo.processInfo.arguments containsObject:@"--settings"])
        [CassotisSettingsController.shared showWindow:nil];
    else if([NSProcessInfo.processInfo.arguments containsObject:@"--about"])
        CassotisShowAboutPanel();
}
@end
int main(int argc,const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication]; [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        CassotisAppDelegate * __attribute__((objc_precise_lifetime)) delegate=[[CassotisAppDelegate alloc] init];
        delegate.server=[[IMKServer alloc] initWithName:@"CassotisIME_Connection"
            bundleIdentifier:NSBundle.mainBundle.bundleIdentifier];
        if(!delegate.server) return 1;
        NSApp.delegate=delegate; [NSApp run];
    }
    return 0;
}
