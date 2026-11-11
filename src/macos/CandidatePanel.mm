#import "InputSession.h"
#import "ProductName.h"
#import <InputMethodKit/InputMethodKit.h>
#import "CandidateAppearance.h"
#include <cmath>

NSString *const CassotisCandidateAtInputStartKey=@"CandidateAtInputStart";
BOOL CassotisCandidateAtInputStartEnabled(void) {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    return [defaults objectForKey:CassotisCandidateAtInputStartKey]==nil ||
        [defaults boolForKey:CassotisCandidateAtInputStartKey];
}
void CassotisSetCandidateAtInputStartEnabled(BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:CassotisCandidateAtInputStartKey];
}
static BOOL clientRect(id client, NSUInteger index, NSRect *rect) {
    @try {
        // IMK uses an inline-composition index, including when it is empty.
        // A document selectedRange offset breaks Terminal's rectangle lookup.
        NSRect line=NSZeroRect;
        [client attributesForCharacterIndex:index lineHeightRectangle:&line];
        if(std::isfinite(line.origin.x) && std::isfinite(line.origin.y) &&
           std::isfinite(line.size.width) && std::isfinite(line.size.height) &&
           line.size.width>=0 && line.size.height>0) { *rect=line; return YES; }
    } @catch(NSException *e) { (void)e; }
    return NO;
}
BOOL CassotisClientCaretRect(id client, NSRect *rect) { return clientRect(client,0,rect); }
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
    __weak id _lastClient;
    std::string _lastQuery;
    NSRect _lastCaret, _lastVisible;
    NSRect _compositionStart;
    BOOL _hasCompositionStart, _trackingMenu;
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
- (BOOL)trackingMenu { return _trackingMenu; }
- (void)orderOut:(id)sender {
    _hasCompositionStart=NO; _lastClient=nil; _lastQuery.clear();
    [super orderOut:sender];
}
- (void)beginCompositionWithClient:(id)client {
    _hasCompositionStart=CassotisClientCaretRect(client,&_compositionStart);
    _lastClient=client;
}
- (void)sendEvent:(NSEvent *)event {
    if(event.type!=NSEventTypeRightMouseDown || !self.contextMenu) { [super sendEvent:event]; return; }
    NSMenu *menu=self.contextMenu(); if(!menu) return;
    // Preserve the user-word delete command alongside the input-source menu.
    NSView *hit=[self.contentView hitTest:[self.contentView convertPoint:event.locationInWindow fromView:nil]];
    for(NSView *view=hit;view && view!=self.contentView;view=view.superview) {
        if(view.menu.numberOfItems) {
            [menu insertItem:NSMenuItem.separatorItem atIndex:0];
            for(NSMenuItem *item in view.menu.itemArray.reverseObjectEnumerator)
                [menu insertItem:[item copy] atIndex:0];
            break;
        }
    }
    // Menu tracking runs a nested loop. Freeze refreshes until it ends so a
    // pending result cannot replace the candidate beneath the chosen command.
    _trackingMenu=YES;
    @try { [NSMenu popUpContextMenu:menu withEvent:event forView:self.contentView]; }
    @finally { _trackingMenu=NO; }
}
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
    if(_trackingMenu) return;
    ++_revision;
    if(r.preedit.empty() || (r.candidates.empty() && r.rawInput.empty() && r.completion.empty() && r.warnings.empty())) { [self orderOut:nil]; return; }
    NSRect caret=NSMakeRect(NSEvent.mouseLocation.x,NSEvent.mouseLocation.y,1,20);
    CassotisClientCaretRect(client,&caret);
    NSString *preedit=[NSString stringWithUTF8String:r.preedit.c_str()];
    NSRect end=caret;
    BOOL hasEnd=clientRect(client,preedit.length,&end);
    if(CassotisCandidateAtInputStartEnabled()) {
        // Some hosts (including Terminal) return the current caret for every
        // inline index. Keep the position captured before inserting marked
        // text in that case; a new line or host starts a new anchor.
        if(_hasCompositionStart && _lastClient==client && (!hasEnd || NSEqualRects(caret,end)) &&
           NSMinX(caret)>=NSMinX(_compositionStart) &&
           fabs(NSMinY(caret)-NSMinY(_compositionStart))<=MAX(8,caret.size.height/2))
            caret.origin.x=_compositionStart.origin.x;
        else { _compositionStart=caret; _hasCompositionStart=YES; }
    } else if(hasEnd) caret=end;
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
    NSRect anchorCaret=caret;
    if(r.candidatePages.size()>1 && self.visible && _lastClient==client && _lastQuery==r.query &&
        fabs(NSMinY(caret)-NSMinY(_lastCaret))<0.5 && NSEqualRects(visible,_lastVisible))
        anchorCaret.origin.x=NSMinX(self.frame);
    [self setFrame:CassotisPanelFrameAtCaret(anchorCaret,fitting,visible) display:YES];
    _lastClient=client; _lastQuery=r.query; _lastCaret=caret; _lastVisible=visible;
    [self orderFrontRegardless];
}
@end
