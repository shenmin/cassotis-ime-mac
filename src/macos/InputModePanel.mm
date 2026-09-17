#import "InputSession.h"
#import "CandidateAppearance.h"
#import "ProductName.h"
#import <Carbon/Carbon.h>
#import <QuartzCore/QuartzCore.h>
#include <cmath>

static const NSSize modeSize={64,40};
static constexpr CGFloat clearance=8;

NSRect CassotisInputModeFrameAtCaret(NSRect caret, NSSize size, NSRect visible,
    NSArray<NSValue *> *accessories, NSRect current) {
    if(size.width<=0 || size.height<=0 || size.width>visible.size.width || size.height>visible.size.height)
        return NSZeroRect;
    auto clear=[&](NSRect frame) {
        if(!NSContainsRect(visible,frame) ||
           !(NSMinY(frame)>=NSMaxY(caret)+clearance || NSMaxY(frame)<=NSMinY(caret)-clearance)) return false;
        for(NSValue *value in accessories)
            if(NSIntersectsRect(frame,NSInsetRect(value.rectValue,-clearance,-clearance))) return false;
        return true;
    };
    // Once placed, stay put unless a newly appearing/expanding accessory
    // overlaps us. Disappearing system animations must not make the hint jump.
    if(NSEqualSizes(current.size,size) && clear(current)) return current;
    auto clampX=[&](CGFloat x) { return MIN(MAX(x,NSMinX(visible)),NSMaxX(visible)-size.width); };
    CGFloat x=clampX(NSMinX(caret)-16);
    CGFloat above=NSMaxY(caret)+clearance,below=NSMinY(caret)-size.height-clearance;
    // System language badges normally appear below the insertion point.
    // Prefer above even before their first window reaches the window list.
    for(CGFloat y : {above,below}) {
        NSRect frame=NSMakeRect(x,y,size.width,size.height);
        if(clear(frame)) return frame;
    }
    std::vector<CGFloat> xs={x,NSMinX(visible),NSMaxX(visible)-size.width};
    std::vector<CGFloat> ys={above,below,NSMinY(visible),NSMaxY(visible)-size.height};
    for(NSValue *value in accessories) {
        NSRect rect=value.rectValue;
        xs.push_back(clampX(NSMinX(rect)-size.width-clearance));
        xs.push_back(clampX(NSMaxX(rect)+clearance));
        ys.push_back(NSMinY(rect)-size.height-clearance);
        ys.push_back(NSMaxY(rect)+clearance);
    }
    NSRect best=NSZeroRect; CGFloat distance=CGFLOAT_MAX;
    for(CGFloat px:xs) for(CGFloat py:ys) {
        NSRect frame=NSMakeRect(px,py,size.width,size.height);
        if(!clear(frame)) continue;
        CGFloat dx=NSMidX(frame)-NSMinX(caret),dy=NSMidY(frame)-NSMidY(caret);
        CGFloat score=dx*dx+dy*dy;
        if(score<distance) { best=frame; distance=score; }
    }
    return best;
}

static NSArray<NSValue *> *caretAccessories(NSRect caret,pid_t clientPID) {
    NSMutableArray<NSValue *> *rects=[NSMutableArray array];
    // Bounds, owner PID and level are public window metadata. Do not request
    // screen capture/accessibility access, window titles or window pixels.
    // AppKit hosts the system cursor accessory in the client application's
    // floating window, rather than necessarily under CursorUIViewService.
    NSArray *windows=CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly|kCGWindowListExcludeDesktopElements,kCGNullWindowID));
    CGFloat desktopTop=NSScreen.screens.firstObject.frame.origin.y+NSScreen.screens.firstObject.frame.size.height;
    for(NSDictionary *window in windows) {
        pid_t owner=[window[(__bridge NSString *)kCGWindowOwnerPID] intValue];
        NSInteger level=[window[(__bridge NSString *)kCGWindowLayer] integerValue];
        if(owner==getpid() || level<NSFloatingWindowLevel || level>NSPopUpMenuWindowLevel ||
           [window[(__bridge NSString *)kCGWindowAlpha] doubleValue]<=0) continue;
        if(owner!=clientPID && ![[NSRunningApplication runningApplicationWithProcessIdentifier:owner].bundleIdentifier
            isEqual:@"com.apple.TextInputUI.xpc.CursorUIViewService"]) continue;
        CGRect quartz;
        if(!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(__bridge NSString *)kCGWindowBounds],&quartz)) continue;
        NSRect rect=NSMakeRect(quartz.origin.x,desktopTop-CGRectGetMaxY(quartz),quartz.size.width,quartz.size.height);
        if(!std::isfinite(rect.origin.x) || !std::isfinite(rect.origin.y) ||
           rect.size.width<12 || rect.size.height<12 || rect.size.width>800 || rect.size.height>180) continue;
        if(NSIntersectsRect(rect,NSInsetRect(caret,-200,-120))) [rects addObject:[NSValue valueWithRect:rect]];
    }
    return rects;
}

@interface CassotisInputModeView : NSView
@property(nonatomic, strong) NSColor *fill;
@property(nonatomic, strong) NSColor *border;
@property(nonatomic) BOOL aboveCaret;
@property(nonatomic) CGFloat pointerX;
@property(nonatomic, strong) NSImageView *logo;
@property(nonatomic, strong) NSTextField *symbol;
@end
@implementation CassotisInputModeView
- (instancetype)init {
    self=[super initWithFrame:NSMakeRect(0,0,modeSize.width,modeSize.height)];
    if(self) {
        self.wantsLayer=YES;
        self.accessibilityIdentifier=@"input-mode-bubble";
        _logo=[[NSImageView alloc] init];
        _logo.image=[NSBundle.mainBundle imageForResource:@"CassotisInputSourceRounded.tiff"]?:
            [[NSImage alloc] initWithContentsOfFile:@"resources/CassotisInputSourceRounded.tiff"];
        _logo.imageScaling=NSImageScaleProportionallyUpOrDown;
        _logo.accessibilityIdentifier=@"input-mode-logo";
        _logo.accessibilityLabel=CassotisShortName();
        [self addSubview:_logo];
        _symbol=[NSTextField labelWithString:@""];
        _symbol.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        _symbol.alignment=NSTextAlignmentCenter;
        _symbol.accessibilityIdentifier=@"input-mode-symbol";
        [self addSubview:_symbol];
    }
    return self;
}
- (void)layout {
    [super layout];
    CGFloat center=(self.bounds.size.height+(self.aboveCaret?5:-5))/2;
    self.logo.frame=NSMakeRect(12,center-8,16,16);
    CGFloat height=self.symbol.fittingSize.height;
    self.symbol.frame=NSMakeRect(36,center-height/2,16,height);
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    // One outline avoids a seam where the small pointer joins the bubble.
    NSBezierPath *shape=[NSBezierPath bezierPath];
    CGFloat width=self.bounds.size.width,height=self.bounds.size.height,top=height-6;
    CGFloat pointer=MIN(MAX(self.pointerX,15),width-15);
    [shape moveToPoint:NSMakePoint(10,1)];
    [shape lineToPoint:NSMakePoint(width-10,1)];
    [shape curveToPoint:NSMakePoint(width-1,10) controlPoint1:NSMakePoint(width-5,1) controlPoint2:NSMakePoint(width-1,5)];
    [shape lineToPoint:NSMakePoint(width-1,top-9)];
    [shape curveToPoint:NSMakePoint(width-10,top) controlPoint1:NSMakePoint(width-1,top-4) controlPoint2:NSMakePoint(width-5,top)];
    [shape lineToPoint:NSMakePoint(pointer+5,top)];
    [shape lineToPoint:NSMakePoint(pointer,height-1)];
    [shape lineToPoint:NSMakePoint(pointer-5,top)];
    [shape lineToPoint:NSMakePoint(10,top)];
    [shape curveToPoint:NSMakePoint(1,top-9) controlPoint1:NSMakePoint(5,top) controlPoint2:NSMakePoint(1,top-4)];
    [shape lineToPoint:NSMakePoint(1,10)];
    [shape curveToPoint:NSMakePoint(10,1) controlPoint1:NSMakePoint(1,5) controlPoint2:NSMakePoint(5,1)];
    [shape closePath];
    if(self.aboveCaret) {
        NSAffineTransform *flip=[NSAffineTransform transform];
        [flip translateXBy:0 yBy:height]; [flip scaleXBy:1 yBy:-1];
        [shape transformUsingAffineTransform:flip];
    }
    [self.fill setFill]; [shape fill];
    [self.border setStroke]; shape.lineWidth=1; [shape stroke];
}
@end

@implementation CassotisInputModePanel {
    NSTimer *_dismissTimer;
    NSTimer *_positionTimer;
    NSUInteger _revision;
    NSRect _caret,_visible;
    pid_t _clientPID;
}
- (instancetype)init {
    self=[super initWithContentRect:NSMakeRect(0,0,modeSize.width,modeSize.height)
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
- (void)dealloc { [_dismissTimer invalidate]; [_positionTimer invalidate]; }
- (void)dismiss {
    ++_revision; [_dismissTimer invalidate]; _dismissTimer=nil;
    [_positionTimer invalidate]; _positionTimer=nil;
    [self.contentView.layer removeAllAnimations];
    [self orderOut:nil];
}
- (BOOL)placeKeepingFrame:(NSRect)current {
    NSRect position=CassotisInputModeFrameAtCaret(_caret,modeSize,_visible,caretAccessories(_caret,_clientPID),current);
    if(NSIsEmptyRect(position)) return NO;
    if(!NSIsEmptyRect(current) && NSEqualRects(position,self.frame)) return YES;
    CassotisInputModeView *view=(CassotisInputModeView *)self.contentView;
    view.aboveCaret=NSMinY(position)>=NSMaxY(_caret);
    view.pointerX=NSMinX(_caret)-NSMinX(position);
    [self setFrame:position display:NO];
    [view setNeedsLayout:YES]; [view layoutSubtreeIfNeeded]; [view setNeedsDisplay:YES];
    return YES;
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
    _caret=caret; _visible=screen.visibleFrame;
    _clientPID=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
    CassotisInputModeView *view=(CassotisInputModeView *)self.contentView;
    auto colors=CassotisColors(CassotisCandidateTheme(NSUserDefaults.standardUserDefaults),NSApp.effectiveAppearance);
    view.fill=colors.background; view.border=colors.border;
    view.symbol.stringValue=mode==0?@"中":@"英";
    view.symbol.textColor=colors.text;
    view.accessibilityValue=mode==0?@"中文":@"英文";
    view.symbol.accessibilityLabel=view.accessibilityValue;
    self.accessibilityLabel=[NSString stringWithFormat:@"%@，%@",CassotisShortName(),view.accessibilityValue];
    if(![self placeKeepingFrame:NSZeroRect]) return NO;
    [self orderFrontRegardless];
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
    _positionTimer=[NSTimer timerWithTimeInterval:0.06 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        CassotisInputModePanel *panel=weak;
        if(!panel || revision!=panel->_revision) return;
        if(IsSecureEventInputEnabled() || NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier!=panel->_clientPID ||
           ![panel placeKeepingFrame:panel.frame]) [panel dismiss];
    }];
    [NSRunLoop.mainRunLoop addTimer:_positionTimer forMode:NSRunLoopCommonModes];
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
