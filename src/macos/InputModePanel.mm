#import "InputSession.h"
#import "CandidateAppearance.h"
#import "ProductName.h"
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>

@interface CassotisInputModeView : NSView
@property(nonatomic, strong) NSColor *fill;
@property(nonatomic, strong) NSColor *border;
@property(nonatomic) BOOL aboveCaret;
@property(nonatomic, strong) NSTextField *symbol;
@end
@implementation CassotisInputModeView
- (instancetype)init {
    self=[super initWithFrame:NSMakeRect(0,0,46,46)];
    if(self) {
        self.wantsLayer=YES;
        self.accessibilityIdentifier=@"input-mode-bubble";
        _symbol=[NSTextField labelWithString:@""];
        _symbol.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        _symbol.alignment=NSTextAlignmentCenter;
        _symbol.accessibilityIdentifier=@"input-mode-symbol";
        [self addSubview:_symbol];
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    // One outline avoids a seam where the small pointer joins the bubble.
    NSBezierPath *shape=[NSBezierPath bezierPath];
    [shape moveToPoint:NSMakePoint(13,1)];
    [shape lineToPoint:NSMakePoint(33,1)];
    [shape curveToPoint:NSMakePoint(45,13) controlPoint1:NSMakePoint(40,1) controlPoint2:NSMakePoint(45,6)];
    [shape lineToPoint:NSMakePoint(45,28)];
    [shape curveToPoint:NSMakePoint(33,40) controlPoint1:NSMakePoint(45,35) controlPoint2:NSMakePoint(40,40)];
    [shape lineToPoint:NSMakePoint(22,40)];
    [shape lineToPoint:NSMakePoint(17,45)];
    [shape lineToPoint:NSMakePoint(12,40)];
    [shape curveToPoint:NSMakePoint(1,28) controlPoint1:NSMakePoint(5,40) controlPoint2:NSMakePoint(1,35)];
    [shape lineToPoint:NSMakePoint(1,13)];
    [shape curveToPoint:NSMakePoint(13,1) controlPoint1:NSMakePoint(1,6) controlPoint2:NSMakePoint(6,1)];
    [shape closePath];
    if(self.aboveCaret) {
        NSAffineTransform *flip=[NSAffineTransform transform];
        [flip translateXBy:0 yBy:46]; [flip scaleXBy:1 yBy:-1];
        [shape transformUsingAffineTransform:flip];
    }
    [self.fill setFill]; [shape fill];
    [self.border setStroke]; shape.lineWidth=1; [shape stroke];
}
@end

@implementation CassotisInputModePanel {
    NSTimer *_dismissTimer;
    NSUInteger _revision;
}
- (instancetype)init {
    self=[super initWithContentRect:NSMakeRect(0,0,46,46)
        styleMask:NSWindowStyleMaskBorderless|NSWindowStyleMaskNonactivatingPanel
        backing:NSBackingStoreBuffered defer:NO];
    if(self) {
        self.level=NSPopUpMenuWindowLevel;
        self.floatingPanel=YES; self.hidesOnDeactivate=NO;
        self.collectionBehavior=NSWindowCollectionBehaviorCanJoinAllSpaces|
            NSWindowCollectionBehaviorFullScreenAuxiliary|NSWindowCollectionBehaviorIgnoresCycle;
        self.hasShadow=YES; self.opaque=NO; self.backgroundColor=NSColor.clearColor;
        self.ignoresMouseEvents=YES;
        self.animationBehavior=NSWindowAnimationBehaviorNone;
        self.title=[CassotisShortName() stringByAppendingString:@"输入状态"];
        self.contentView=[[CassotisInputModeView alloc] init];
    }
    return self;
}
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)canBecomeMainWindow { return NO; }
- (void)dealloc { [_dismissTimer invalidate]; }
- (void)dismiss {
    ++_revision; [_dismissTimer invalidate]; _dismissTimer=nil;
    [self.contentView.layer removeAllAnimations];
    [self orderOut:nil];
}
- (BOOL)showMode:(uint8_t)mode client:(id)client {
    [self dismiss];
    NSUInteger revision=_revision;
    NSRect caret;
    if(mode>1 || IsSecureEventInputEnabled() || !CassotisClientCaretRect(client,&caret)) return NO;
    // The IMK client call can reenter activation or input handling. Do not
    // resurrect a cancelled hint or overwrite a newer mode when it returns.
    if(revision!=_revision) return NO;
    // A status hint must be tied to a real insertion point, never the mouse or
    // a stale/off-screen rectangle returned while the next client activates.
    NSScreen *screen=nil;
    NSPoint anchor=NSMakePoint(NSMinX(caret),NSMidY(caret));
    for(NSScreen *candidate in NSScreen.screens)
        if(NSPointInRect(anchor,candidate.visibleFrame)) { screen=candidate; break; }
    if(!screen) return NO;
    NSRect position=CassotisPanelFrameAtCaret(caret,NSMakeSize(46,46),screen.visibleFrame);
    CassotisInputModeView *view=(CassotisInputModeView *)self.contentView;
    auto colors=CassotisColors(CassotisCandidateTheme(NSUserDefaults.standardUserDefaults),NSApp.effectiveAppearance);
    view.fill=colors.background; view.border=colors.border;
    view.aboveCaret=NSMinY(position)>=NSMaxY(caret);
    view.symbol.stringValue=mode==0?@"中":@"英";
    view.symbol.textColor=colors.text;
    CGFloat symbolHeight=view.symbol.fittingSize.height;
    view.symbol.frame=NSMakeRect(1,(view.aboveCaret?26:21)-symbolHeight/2,44,symbolHeight);
    view.accessibilityValue=mode==0?@"中文":@"英文";
    view.symbol.accessibilityLabel=view.accessibilityValue;
    self.accessibilityLabel=[NSString stringWithFormat:@"%@，%@",CassotisShortName(),view.accessibilityValue];
    [view setNeedsDisplay:YES];
    [self setFrame:position display:YES]; [self orderFrontRegardless];
    BOOL reduceMotion=NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue=@0; fade.toValue=@1; fade.duration=0.12;
    [view.layer addAnimation:fade forKey:@"mode-fade"];
    if(!reduceMotion) {
        CABasicAnimation *scale=[CABasicAnimation animationWithKeyPath:@"transform.scale"];
        scale.fromValue=@0.88; scale.toValue=@1; scale.duration=0.14;
        scale.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [view.layer addAnimation:scale forKey:@"mode-scale"];
    }
    __weak CassotisInputModePanel *weak=self;
    _dismissTimer=[NSTimer timerWithTimeInterval:0.85 repeats:NO block:^(NSTimer *timer) {
        (void)timer; [weak fadeOutRevision:revision];
    }];
    [NSRunLoop.mainRunLoop addTimer:_dismissTimer forMode:NSRunLoopCommonModes];
    return YES;
}
- (void)fadeOutRevision:(NSUInteger)revision {
    if(revision!=_revision) return;
    CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue=@1; fade.toValue=@0; fade.duration=0.15;
    fade.fillMode=kCAFillModeForwards; fade.removedOnCompletion=NO;
    [self.contentView.layer addAnimation:fade forKey:@"mode-fade"];
    __weak CassotisInputModePanel *weak=self;
    _dismissTimer=[NSTimer timerWithTimeInterval:0.15 repeats:NO block:^(NSTimer *timer) {
        (void)timer;
        CassotisInputModePanel *panel=weak;
        if(panel && revision==panel->_revision) [panel dismiss];
    }];
    [NSRunLoop.mainRunLoop addTimer:_dismissTimer forMode:NSRunLoopCommonModes];
}
@end
