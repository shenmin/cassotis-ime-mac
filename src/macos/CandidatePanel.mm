#import "InputSession.h"
#import "ProductName.h"
#import <InputMethodKit/InputMethodKit.h>
#import "CandidateAppearance.h"
#include <cmath>

BOOL CassotisClientCaretRect(id client, NSRect *rect) {
    @try {
        // IMK uses an inline-composition index, including when it is empty.
        // A document selectedRange offset breaks Terminal's rectangle lookup.
        NSRect line=NSZeroRect;
        [client attributesForCharacterIndex:0 lineHeightRectangle:&line];
        if(std::isfinite(line.origin.x) && std::isfinite(line.origin.y) &&
           std::isfinite(line.size.width) && std::isfinite(line.size.height) &&
           line.size.width>=0 && line.size.height>0) { *rect=line; return YES; }
    } @catch(NSException *e) { (void)e; }
    return NO;
}
NSRect CassotisPanelFrameAtCaret(NSRect caret, NSSize size, NSRect visible) {
    size.width=MIN(size.width,visible.size.width); size.height=MIN(size.height,visible.size.height);
    CGFloat x=MIN(MAX(caret.origin.x,NSMinX(visible)),NSMaxX(visible)-size.width);
    constexpr CGFloat clearance=8;
    CGFloat y=NSMinY(caret)-size.height-clearance;
    if(y<NSMinY(visible)) y=MIN(NSMaxY(caret)+clearance,NSMaxY(visible)-size.height);
    return NSMakeRect(x,MAX(y,NSMinY(visible)),size.width,size.height);
}

@implementation CassotisCandidatePanel {
    NSUInteger _revision;
}
- (instancetype)init {
    self=[super initWithContentRect:NSMakeRect(0,0,300,100)
        styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel
        backing:NSBackingStoreBuffered defer:NO];
    if(self) {
        self.level=NSPopUpMenuWindowLevel;
        self.floatingPanel=YES; self.hidesOnDeactivate=NO;
        self.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|
            NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;
        self.hasShadow=YES; self.opaque=NO; self.backgroundColor=NSColor.clearColor;
        self.accessibilityLabel=[CassotisShortName() stringByAppendingString:@"候选词"];
    }
    return self;
}
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
- (void)clicked:(NSButton *)sender {
    // An event queued before a candidate refresh must not select the new row
    // at the old numerical position.
    if([sender isDescendantOf:self.contentView] && self.selection) self.selection(sender.tag);
}
- (void)deleteClicked:(id)sender {
    if([sender isKindOfClass:NSButton.class]) {
        if([sender isDescendantOf:self.contentView] && self.deletion) self.deletion([sender tag]);
    } else if([sender isKindOfClass:NSMenuItem.class]) {
        NSArray<NSNumber *> *identity=[sender representedObject];
        if(identity.count==2 && identity[0].unsignedIntegerValue==_revision && self.deletion)
            self.deletion(identity[1].integerValue);
    }
}
- (void)showResult:(const cassotis::Result &)r client:(id)client {
    ++_revision;
    if(r.preedit.empty() || (r.candidates.empty() && r.completion.empty())) { [self orderOut:nil]; return; }
    NSRect caret=NSMakeRect(NSEvent.mouseLocation.x,NSEvent.mouseLocation.y,1,20);
    CassotisClientCaretRect(client,&caret);
    NSScreen *screen=NSScreen.mainScreen;
    // Insertion rectangles may have zero width; rect intersection would then
    // miss the caret's display and fall back to the application's main screen.
    NSPoint anchor=NSMakePoint(NSMinX(caret),NSMidY(caret));
    for(NSScreen *candidate in NSScreen.screens) if(NSPointInRect(anchor,candidate.frame)) { screen=candidate; break; }
    NSRect visible=screen.visibleFrame;
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    self.contentView=CassotisCandidateView(r,CassotisCandidateFontSize(defaults),
        [defaults stringForKey:@"CandidateFontFamily"],CassotisCandidateTheme(defaults),
        visible.size.width-16,NSApp.effectiveAppearance,
        self,@selector(clicked:),@selector(deleteClicked:),_revision,self.completionKey);
    NSSize fitting=self.contentView.fittingSize;
    fitting.width=MAX(180,fitting.width);
    [self setFrame:CassotisPanelFrameAtCaret(caret,fitting,visible) display:YES];
    [self orderFrontRegardless];
}
@end
