#import "ShortcutRecorder.h"
#import "InputSession.h"
#import <Carbon/Carbon.h>

static NSString *keyName(uint16_t key) {
    switch(key) {
        case 16:return @"Shift"; case 17:return @"Ctrl"; case 18:return @"Option";
        case 32:return @"Space"; case 9:return @"Tab"; case 13:return @"Return";
        case 8:return @"Delete ⌫"; case 46:return @"Delete ⌦"; case 27:return @"Esc";
        case 37:return @"←"; case 38:return @"↑"; case 39:return @"→"; case 40:return @"↓";
        case 33:return @"Page Up"; case 34:return @"Page Down"; case 35:return @"End"; case 36:return @"Home";
        case 106:return @"Num *"; case 107:return @"Num +"; case 109:return @"Num −";
        case 110:return @"Num ."; case 111:return @"Num /";
        case 0xba:return @";";case 0xbb:return @"=";case 0xbc:return @",";case 0xbd:return @"−";
        case 0xbe:return @".";case 0xbf:return @"/";case 0xc0:return @"`";
        case 0xdb:return @"[";case 0xdc:return @"\\";case 0xdd:return @"]";case 0xde:return @"'";
        default:break;
    }
    if(key>=0x70 && key<=0x83) return [NSString stringWithFormat:@"F%d",key-0x70+1];
    if((key>='A' && key<='Z') || (key>='0' && key<='9')) return [NSString stringWithFormat:@"%C",(unichar)key];
    return @"";
}
static NSMutableArray<NSString *> *modifierNames(NSUInteger flags) {
    NSMutableArray *names=[NSMutableArray array];
    if(flags&NSEventModifierFlagControl) [names addObject:@"Ctrl"];
    if(flags&NSEventModifierFlagOption) [names addObject:@"Option"];
    if(flags&NSEventModifierFlagShift) [names addObject:@"Shift"];
    if(flags&NSEventModifierFlagCommand) [names addObject:@"Command"];
    return names;
}
NSString *CassotisShortcutDescription(const cassotis::Shortcut &s) {
    NSMutableArray *names=modifierNames(((s.modifiers&1)?NSEventModifierFlagShift:0)|
        ((s.modifiers&2)?NSEventModifierFlagControl:0)|((s.modifiers&4)?NSEventModifierFlagOption:0));
    NSString *key=keyName(s.key); if(key.length) [names addObject:key];
    return [names componentsJoinedByString:@" + "];
}
NSString *CassotisShortcutValidationError(const cassotis::Shortcut &s) {
    if(s.disabled) return nil;
    if(s.modifiers&~7) return @"Command 和 Fn 组合键由 macOS 管理，请选择 Ctrl、Option 或 Shift。";
    if(s.key==32 && (s.modifiers&2)) return @"Ctrl + Space 组合键保留给 macOS 切换输入源。";
    if(s.key>=16 && s.key<=18) return s.key==16 && !s.modifiers?nil:@"单独的修饰键仅支持 Shift；请再按一个字母或功能键。";
    if(!keyName(s.key).length || (!s.modifiers && !(s.key>=0x70 && s.key<=0x83)))
        return @"请使用 Ctrl、Option、Shift 组合键，F1–F20，或单独的 Shift。";
    return nil;
}

@implementation CassotisShortcutRecorder {
    cassotis::Shortcut _shortcut;
    NSString *_displayString;
    BOOL _recording;
    NSUInteger _gestureFlags;
    id _eventMonitor;
}
- (instancetype)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame];
    if(self) {
        self.focusRingType=NSFocusRingTypeNone;
        self.toolTip=@"点击后直接按快捷键；Esc 取消，Tab 移至下一项。";
        self.accessibilityRole=NSAccessibilityButtonRole;
        self.accessibilityElement=YES;
        _displayString=@"点击录制快捷键";
    }
    return self;
}
- (void)dealloc { if(_eventMonitor) [NSEvent removeMonitor:_eventMonitor]; }
- (NSSize)intrinsicContentSize { return NSMakeSize(220,32); }
- (BOOL)acceptsFirstResponder { return self.enabled; }
- (NSTextInputContext *)inputContext { return nil; }
- (NSString *)displayString { return _displayString; }
- (BOOL)recording { return _recording; }
- (cassotis::Shortcut)shortcut { return _shortcut; }
- (void)setShortcut:(cassotis::Shortcut)value { _shortcut=value; [self cancelRecording]; }
- (void)setEnabled:(BOOL)value { [super setEnabled:value]; if(!value) [self cancelRecording]; self.needsDisplay=YES; }
- (void)display:(NSString *)text {
    _displayString=text; self.accessibilityValue=text; self.needsDisplay=YES;
    NSAccessibilityPostNotification(self,NSAccessibilityValueChangedNotification);
}
- (void)beginRecording {
    if(!self.enabled) return;
    _recording=YES; _gestureFlags=0;
    [self display:@"请按快捷键…"];
    if(self.validationMessage) self.validationMessage(@"直接按下所需组合键；Esc 取消录制。" );
    if(!_eventMonitor) {
        __weak CassotisShortcutRecorder *weak=self;
        _eventMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown|NSEventMaskKeyUp|NSEventMaskFlagsChanged
            handler:^NSEvent *(NSEvent *event) {
                CassotisShortcutRecorder *control=weak;
                if(!control || !control.recording || !control.window.keyWindow || control.window.firstResponder!=control) return event;
                if(event.type==NSEventTypeFlagsChanged) [control flagsChanged:event];
                else if(event.type==NSEventTypeKeyDown) [control keyDown:event];
                return nil;
            }];
    }
}
- (void)cancelRecording {
    _recording=NO; _gestureFlags=0;
    if(_eventMonitor) { [NSEvent removeMonitor:_eventMonitor]; _eventMonitor=nil; }
    NSString *name=CassotisShortcutDescription(_shortcut);
    [self display:name.length?name:@"点击录制快捷键"];
}
- (BOOL)becomeFirstResponder { [self beginRecording]; return YES; }
- (BOOL)resignFirstResponder { [self cancelRecording]; return YES; }
- (void)mouseDown:(NSEvent *)event {
    (void)event; if(self.enabled) { [self.window makeFirstResponder:self]; [self beginRecording]; }
}
- (BOOL)accessibilityPerformPress {
    if(!self.enabled) return NO;
    [self.window makeFirstResponder:self]; [self beginRecording]; return YES;
}
- (void)accept:(cassotis::Shortcut)value {
    NSString *error=CassotisShortcutValidationError(value);
    if(error) { if(self.validationMessage) self.validationMessage(error); return; }
    _shortcut=value; [self cancelRecording];
    if(self.validationMessage) self.validationMessage(@"快捷键已录制。" );
    [self sendAction:self.action to:self.target];
}
- (void)flagsChanged:(NSEvent *)event {
    if(!_recording) return;
    NSUInteger flags=event.modifierFlags&(NSEventModifierFlagShift|NSEventModifierFlagControl|
        NSEventModifierFlagOption|NSEventModifierFlagCommand);
    _gestureFlags|=flags;
    if(flags) [self display:[modifierNames(flags) componentsJoinedByString:@" + "]];
    else if(_gestureFlags==NSEventModifierFlagShift && (event.keyCode==kVK_Shift || event.keyCode==kVK_RightShift)) {
        [self accept:{16,0,false}];
    } else if(_gestureFlags) {
        _gestureFlags=0;
        [self display:@"请按组合键…"];
        if(self.validationMessage) self.validationMessage(@"单独的修饰键仅支持 Shift；按住 Ctrl 或 Option 时再按另一个键。" );
    }
}
- (void)keyDown:(NSEvent *)event {
    if(!_recording) { if(event.keyCode==kVK_Space || event.keyCode==kVK_Return) [self beginRecording]; return; }
    NSUInteger modifiers=event.modifierFlags&(NSEventModifierFlagShift|NSEventModifierFlagControl|
        NSEventModifierFlagOption|NSEventModifierFlagCommand);
    if(event.keyCode==kVK_Escape && !modifiers) { [self cancelRecording]; return; }
    if(event.keyCode==kVK_Tab && !(modifiers&~NSEventModifierFlagShift)) {
        [self cancelRecording];
        if(modifiers&NSEventModifierFlagShift) [self.window selectPreviousKeyView:self];
        else [self.window selectNextKeyView:self];
        return;
    }
    if(event.ARepeat) return;
    auto key=CassotisTranslateKey(event,NO);
    key.text=(event.charactersIgnoringModifiers?:@"").UTF8String;
    cassotis::Shortcut value={CassotisShortcutKey(key),uint8_t(key.modifiers&15),false};
    NSMutableArray *names=modifierNames(modifiers);
    NSString *name=keyName(value.key);
    if(name.length) [names addObject:name];
    [self display:[names componentsJoinedByString:@" + "]];
    // Function flags also accompany arrows and physical F keys; those remain usable.
    if(event.keyCode==kVK_Function || ((event.modifierFlags&NSEventModifierFlagFunction) && (!key.special || key.special==5))) {
        if(self.validationMessage) self.validationMessage(@"Fn 组合键由 macOS 管理，请选择其他按键。" );
        return;
    }
    [self accept:value];
}
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if(self.window.firstResponder==self && _recording) { [self keyDown:event]; return YES; }
    return NO;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSBezierPath *path=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,1,1) xRadius:6 yRadius:6];
    [NSColor.controlBackgroundColor setFill]; [path fill];
    [(_recording?NSColor.keyboardFocusIndicatorColor:NSColor.separatorColor) setStroke];
    path.lineWidth=_recording?2:1; [path stroke];
    NSMutableParagraphStyle *style=[[NSMutableParagraphStyle alloc] init]; style.alignment=NSTextAlignmentCenter;
    style.lineBreakMode=NSLineBreakByTruncatingTail;
    NSDictionary *attributes=@{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName:self.enabled?NSColor.labelColor:NSColor.disabledControlTextColor,
        NSParagraphStyleAttributeName:style};
    CGFloat height=[_displayString sizeWithAttributes:attributes].height;
    [_displayString drawInRect:NSMakeRect(8,floor((self.bounds.size.height-height)/2),self.bounds.size.width-16,height) withAttributes:attributes];
}
@end
