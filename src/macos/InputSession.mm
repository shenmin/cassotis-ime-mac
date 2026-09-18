#import "InputSession.h"
#import "SettingsController.h"
#import "ProductName.h"
#import "RuntimeLog.h"
#import <InputMethodKit/InputMethodKit.h>
#import <Carbon/Carbon.h>
#include <memory>
#include <sys/stat.h>
#include <signal.h>

static NSTask *engineTask;
static __weak CassotisInputSession *activeSession;
void CassotisStopEngine(void) {
    NSTask *task=engineTask;
    if(!task.running) return;
    [task terminate];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(task.running) kill(task.processIdentifier,SIGKILL);
    });
}

static NSString *str(const std::string &s) {
    return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}
static std::string utf8(NSString *s) {
    NSData *data=[s dataUsingEncoding:NSUTF8StringEncoding];
    return data?std::string((const char *)data.bytes,data.length):std::string();
}
NSString *CassotisSocketPath(void) {
    NSString *override=NSProcessInfo.processInfo.environment[@"CASSOTIS_SOCKET"];
    if(override.length) return override;
    return [[NSTemporaryDirectory() stringByAppendingPathComponent:@"CassotisIME-v1"] stringByAppendingPathComponent:@"engine.sock"];
}
void CassotisStartEngine(void) {
    static CFTimeInterval lastAttempt=0;
    if(engineTask.running || CFAbsoluteTimeGetCurrent()-lastAttempt<2) return;
    lastAttempt=CFAbsoluteTimeGetCurrent();
    cassotis::EngineClient existing;
    if(existing.connect(utf8(CassotisSocketPath()))) return;
    NSString *override=NSProcessInfo.processInfo.environment[@"CASSOTIS_ENGINE_EXECUTABLE"];
    NSString *exe=override?:[NSBundle.mainBundle.executablePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"cassotis-engine"];
    if(![NSFileManager.defaultManager isExecutableFileAtPath:exe]) return;
    NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/CassotisIME"];
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES
        attributes:@{NSFilePosixPermissions:@0700} error:nil];
    NSTask *task=[[NSTask alloc] init]; engineTask=task; task.executableURL=[NSURL fileURLWithPath:exe];
    task.arguments=@[@"--serve",@"--socket",CassotisSocketPath(),@"--parent-pid",[NSString stringWithFormat:@"%d",getpid()]];
    NSPipe *output=[CassotisRuntimeLog.shared captureOutputOfTask:task];
    task.standardInput=NSFileHandle.fileHandleWithNullDevice;
    NSError *error=nil;
    if(![task launchAndReturnError:&error]) {
        [output.fileHandleForWriting closeAndReturnError:nil];
        NSString *message=[NSString stringWithFormat:@"Cassotis engine launch failed: %@\n",error.localizedDescription];
        [CassotisRuntimeLog.shared appendData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    }
}
static unsigned char unshiftedNumber(unsigned char c, uint32_t modifiers) {
    if(modifiers&1) {
        const std::string symbols=")!@#$%^&*(";
        auto digit=symbols.find(c);
        if(digit!=std::string::npos) return '0'+digit;
    }
    return c;
}
cassotis::Key CassotisTranslateKey(NSEvent *e, BOOL release) {
    cassotis::Key k; auto flags=e.modifierFlags;
    k.modifiers=((flags&NSEventModifierFlagShift)?1:0)|((flags&NSEventModifierFlagControl)?2:0)|
        ((flags&NSEventModifierFlagOption)?4:0)|((flags&NSEventModifierFlagCommand)?8:0)|
        ((flags&NSEventModifierFlagCapsLock)?16:0);
    k.scan=e.keyCode; k.release=release; k.repeat=e.type==NSEventTypeKeyDown && e.ARepeat;
    k.timestamp=uint64_t(e.timestamp*1000);
    switch(e.keyCode) {
        case kVK_Delete:k.special=1;break; case kVK_ForwardDelete:k.special=2;break;
        case kVK_Return:case kVK_ANSI_KeypadEnter:k.special=3;break;case kVK_Escape:k.special=4;break;
        case kVK_Space:k.special=5;break;case kVK_Tab:k.special=6;break;
        case kVK_LeftArrow:k.special=7;break;case kVK_RightArrow:k.special=8;break;
        case kVK_UpArrow:k.special=9;break;case kVK_DownArrow:k.special=10;break;
        case kVK_Home:k.special=11;break;case kVK_End:k.special=12;break;
        case kVK_PageUp:k.special=13;break;case kVK_PageDown:k.special=14;break;
        case kVK_Shift:case kVK_RightShift:k.special=20;break;
        case kVK_Control:case kVK_RightControl:k.special=21;break;
        case kVK_Option:case kVK_RightOption:k.special=22;break;
        case kVK_Command:case kVK_RightCommand:k.special=23;break;
        case kVK_F1:k.special=24;break;case kVK_F2:k.special=25;break;case kVK_F3:k.special=26;break;
        case kVK_F4:k.special=27;break;case kVK_F5:k.special=28;break;case kVK_F6:k.special=29;break;
        case kVK_F7:k.special=30;break;case kVK_F8:k.special=31;break;case kVK_F9:k.special=32;break;
        case kVK_F10:k.special=33;break;case kVK_F11:k.special=34;break;case kVK_F12:k.special=35;break;
        case kVK_F13:k.special=36;break;case kVK_F14:k.special=37;break;case kVK_F15:k.special=38;break;
        case kVK_F16:k.special=39;break;case kVK_F17:k.special=40;break;case kVK_F18:k.special=41;break;
        case kVK_F19:k.special=42;break;case kVK_F20:k.special=43;break;
        case kVK_ANSI_KeypadMultiply:k.special=15;break;case kVK_ANSI_KeypadPlus:k.special=16;break;
        case kVK_ANSI_KeypadMinus:k.special=17;break;case kVK_ANSI_KeypadDecimal:k.special=18;break;
        case kVK_ANSI_KeypadDivide:k.special=19;break;
        default:break;
    }
    if(e.type==NSEventTypeKeyDown || e.type==NSEventTypeKeyUp)
        k.text=utf8((flags&(NSEventModifierFlagControl|NSEventModifierFlagCommand))?e.charactersIgnoringModifiers:e.characters);
    // The shared service reconstructs Windows virtual keys from text plus
    // modifiers. AppKit supplies '(' for Shift+9, whereas the engine expects
    // '9' with Shift. Normalize the entire shifted number row, by character
    // rather than physical key position, before sending it to that service.
    if(!k.special && k.text.size()==1) k.text[0]=unshiftedNumber(k.text[0],k.modifiers);
    return k;
}
uint16_t CassotisShortcutKey(const cassotis::Key &k) {
    if(k.special>=24 && k.special<=47) return uint16_t(0x70+k.special-24);
    static const uint16_t specials[]={0,8,46,13,27,32,9,37,39,38,40,36,35,33,34,106,107,109,110,111,16,17,18,91};
    if(k.special<24 && k.special) return specials[k.special];
    if(k.text.size()!=1) return 0;
    unsigned char c=unshiftedNumber(k.text[0],k.modifiers);
    if(isalnum(c)) return uint16_t(toupper(c));
    switch(c) {
        case ';':case ':':return 0xba;case '=':case '+':return 0xbb;
        case ',':case '<':return 0xbc;case '-':case '_':return 0xbd;
        case '.':case '>':return 0xbe;case '/':case '?':return 0xbf;
        case '`':case '~':return 0xc0;case '[':case '{':return 0xdb;
        case '\\':case '|':return 0xdc;case ']':case '}':return 0xdd;
        case '\'':case '"':return 0xde;default:return 0;
    }
}
@implementation CassotisInputSession {
    std::unique_ptr<cassotis::EngineClient> _engine;
    cassotis::Result _result;
    CassotisCandidatePanel *_panel;
    CassotisInputModePanel *_modePanel;
    BOOL _modeKnown, _modeFeedbackPending;
    uint8_t _inputMode;
    NSTimeInterval _modeFeedbackDeadline;
    NSTimer *_timer;
    BOOL _active, _committing, _settingsGesture;
    NSUInteger _modifiers;
    NSUInteger _pollAttempts;
    std::vector<cassotis::Key> _startupKeys;
    NSString *_startupText, *_startupContext;
    NSTimeInterval _startupStarted;
    BOOL _startupMayCommit;
}
- (instancetype)init {
    self=[super init]; if(self) {
        _engine=std::make_unique<cassotis::EngineClient>(); _panel=[[CassotisCandidatePanel alloc] init];
        _modePanel=[[CassotisInputModePanel alloc] init];
        __weak CassotisInputSession *weak=self;
        _panel.selection=^(NSInteger index){ [weak selectCandidate:index]; };
        _panel.deletion=^(NSInteger index){ [weak deleteCandidate:index]; };
    } return self;
}
- (void)dealloc { [_timer invalidate]; [_panel orderOut:nil]; [_modePanel dismiss]; }
- (CassotisCandidatePanel *)panel { return _panel; }
- (CassotisInputModePanel *)modePanel { return _modePanel; }
- (NSString *)preedit { return str(_result.preedit); }
- (NSDictionary<NSAttributedStringKey, id> *)markedTextAttributesForRange:(NSRange)range {
    NSUInteger length=self.preedit.length;
    if(range.length==0 || range.location>length || range.length>length-range.location) return @{};
    for(const auto &span:_result.warnings) {
        if(span.start>length || span.length==0 || span.length>length-span.start) continue;
        if(range.location>=span.start && NSMaxRange(range)<=span.start+span.length)
            return @{NSForegroundColorAttributeName:NSColor.systemRedColor,
                     NSUnderlineColorAttributeName:NSColor.systemRedColor};
    }
    return @{};
}
- (void)cancelModeFeedback {
    if(_modeFeedbackPending || _modePanel.visible) [_modePanel dismiss];
    _modeFeedbackPending=NO;
}
- (void)presentModeFeedback {
    if(!_modeFeedbackPending || !_modeKnown || !_active) return;
    if(!_result.preedit.empty() || NSProcessInfo.processInfo.systemUptime>_modeFeedbackDeadline) {
        [self cancelModeFeedback]; return;
    }
    id client=self.client;
    BOOL shown=[_modePanel showMode:_inputMode client:client];
    if(!shown) return;
    if(!_modeFeedbackPending || !_active || self.client!=client || !_result.preedit.empty()) {
        [_modePanel dismiss]; return;
    }
    _modeFeedbackPending=NO;
}
- (void)showInputMode:(uint8_t)mode {
    if(!_active) return;
    _inputMode=mode; _modeKnown=YES; _modeFeedbackPending=YES;
    _modeFeedbackDeadline=NSProcessInfo.processInfo.systemUptime+0.4;
    [self presentModeFeedback];
}
- (BOOL)ensureReady {
    if(_engine->connected()) return YES;
    if(!_engine->connect(utf8(CassotisSocketPath()))) { CassotisStartEngine(); return NO; }
    try {
        _engine->active(true);
        auto state=_engine->state(); _panel.completionKey=state.completionKey;
        _inputMode=state.mode; _modeKnown=YES;
        _modeFeedbackDeadline=NSProcessInfo.processInfo.systemUptime+0.4;
        return YES;
    }
    catch(const std::exception &e) { (void)e; _engine->disconnect(); return NO; }
}
- (BOOL)activateFromNotification:(id)client {
    // LaunchServices can activate an IMK controller for a background process
    // while another application is composing. It must not take ownership of
    // the shared session. Actual key events still use activate: directly.
    @try {
        NSString *foreground=NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier;
        NSString *bundle=[client respondsToSelector:@selector(bundleIdentifier)]?[client bundleIdentifier]:nil;
        if(bundle.length && foreground.length && ![bundle isEqual:foreground]) return NO;
    } @catch(NSException *error) { (void)error; }
    [self activate:client];
    return YES;
}
- (void)activate:(id)client {
    BOOL newActivation=!_active || self.client!=client;
    // Some clients activate the next IMK controller before deactivating the
    // old one. End the previous marked range before switching the shared core.
    if(activeSession && activeSession!=self) [activeSession deactivate];
    if(_active && self.client!=client) [self deactivate];
    activeSession=self;
    self.client=client; _active=YES; _modifiers=0; _settingsGesture=NO;
    if(newActivation) { _modeKnown=NO; _modeFeedbackPending=YES; }
    [self ensureReady]; [self presentModeFeedback];
    [_timer invalidate]; __weak CassotisInputSession *weak=self;
    _timer=[NSTimer timerWithTimeInterval:0.025 repeats:YES block:^(NSTimer *t){
        (void)t; [weak tick];
    }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (void)deactivate {
    [self cancelModeFeedback];
    [self commit]; _active=NO; [_timer invalidate]; _timer=nil; [_panel orderOut:nil];
    try { if(_engine->connected()) _engine->active(false); } catch(...) { _engine->disconnect(); }
    _engine->disconnect();
    self.client=nil;
    if(activeSession==self) activeSession=nil;
}
- (NSString *)surroundingText {
    @try {
        NSRange selected=[self.client selectedRange];
        if(selected.location==NSNotFound) return @"";
        NSUInteger start=selected.location>1024?selected.location-1024:0;
        NSAttributedString *prefix=[self.client attributedSubstringFromRange:NSMakeRange(start,selected.location-start)];
        NSString *text=prefix.string?:@"";
        if(text.length>1024) text=[text substringFromIndex:text.length-1024];
        if(text.length && CFStringIsSurrogateLowCharacter([text characterAtIndex:0])) text=[text substringFromIndex:1];
        return text;
    } @catch(NSException *e) { (void)e; return @""; }
}
- (void)syncSurrounding {
    if(!_result.preedit.empty()) return;
    NSString *text=[self surroundingText];
    _engine->surrounding(utf8(text),(int32_t)text.length);
}
- (void)clearStartup {
    _startupKeys.clear();_startupText=nil;_startupContext=nil;
    _startupStarted=0;_startupMayCommit=NO;
}
- (BOOL)queueStartupKey:(const cassotis::Key &)key {
    BOOL pending=!_startupKeys.empty();
    if(key.modifiers || key.release) return NO;
    if(pending && key.special==4) { [self cancel]; return YES; }
    if(pending && key.special==3 && !_startupMayCommit) { [self commit]; return YES; }
    BOOL letter=!key.special && key.text.size()==1 && key.text[0]>='a' && key.text[0]<='z';
    BOOL continuation=pending && !key.special && key.text.size()==1 &&
        ((key.text[0]>='0' && key.text[0]<='9') || key.text[0]=='\'');
    BOOL backspace=pending && key.special==1 && !_startupMayCommit;
    BOOL space=pending && key.special==5;
    if((!letter && !continuation && !backspace && !space) || _startupKeys.size()>=64) return NO;
    if(!pending) {
        id client=self.client;
        NSString *context=[self surroundingText];
        if(!_active || self.client!=client) return NO;
        _startupContext=context;_startupText=@"";
        _startupStarted=NSProcessInfo.processInfo.systemUptime;
    }
    if(backspace) {
        if(_startupText.length<=1) { [self cancel]; return YES; }
        _startupText=[_startupText substringToIndex:_startupText.length-1];
    } else {
        _startupText=[_startupText stringByAppendingString:space?@" ":str(key.text)];
        _startupMayCommit|=space || (continuation && key.text[0]!='\'');
    }
    _startupKeys.push_back(key);
    cassotis::Result preview;preview.handled=true;preview.preedit=utf8(_startupText);
    [self apply:preview];
    return YES;
}
- (void)replayStartup {
    // Readiness and the fallback timer can arrive together after a busy main
    // run loop. Prefer the ready helper; retain the bound while it is absent.
    if(![self ensureReady]) {
        if(NSProcessInfo.processInfo.systemUptime-_startupStarted>2) [self commit];
        return;
    }
    try {
        // Read context before the provisional marked range was inserted. Keep
        // that range visible until all already-consumed keys have been replayed.
        _engine->surrounding(utf8(_startupContext),(int32_t)_startupContext.length);
        cassotis::Result final;std::string committed;
        for(const auto &key:_startupKeys) {
            if(final.preedit.empty() && !committed.empty()) {
                NSString *context=[_startupContext stringByAppendingString:str(committed)];
                if(context.length>1024)context=[context substringFromIndex:context.length-1024];
                if(context.length && CFStringIsSurrogateLowCharacter([context characterAtIndex:0]))
                    context=[context substringFromIndex:1];
                _engine->surrounding(utf8(context),(int32_t)context.length);
            }
            final=_engine->key(key);committed+=final.commit;
            if(!final.handled) {
                // English mode passes plain characters through the engine.
                if(key.special==1) {
                    if(!committed.empty()) {
                        NSString *text=str(committed);
                        NSRange last=[text rangeOfComposedCharacterSequenceAtIndex:text.length-1];
                        committed=utf8([text substringToIndex:last.location]);
                    }
                } else committed+=key.special==5?" ":key.text;
            }
        }
        final.commit=committed;
        [self clearStartup];[self apply:final];
    } catch(...) { [self recover]; }
}
- (void)apply:(const cassotis::Result &)r {
    if(!r.preedit.empty()) [self cancelModeFeedback];
    _result=r;
    _pollAttempts=0;
    id client=self.client;
    @try {
        if(!r.commit.empty()) [client insertText:str(r.commit) replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
        if(self.client!=client || !_active) return;
        NSMutableAttributedString *marked=[[NSMutableAttributedString alloc] initWithString:str(r.preedit)
            attributes:@{NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)}];
        for(const auto &span:r.warnings) {
            if(span.start<=marked.length && span.length>0 && span.length<=marked.length-span.start)
                [marked addAttributes:[self markedTextAttributesForRange:NSMakeRange(span.start,span.length)]
                    range:NSMakeRange(span.start,span.length)];
        }
        [client setMarkedText:marked selectionRange:NSMakeRange(marked.length,0)
            replacementRange:NSMakeRange(NSNotFound,NSNotFound)];
        if(self.client==client && _active) [_panel showResult:r client:client];
    } @catch(NSException *e) {
        (void)e; [self clearStartup]; _engine->disconnect(); _result={}; [_panel orderOut:nil];
    }
}
- (void)recover {
    [self cancelModeFeedback];
    // The engine never writes to applications. After an uncertain reply, commit
    // only the last visible raw composition and let the current key pass through.
    NSString *raw=self.preedit; [self clearStartup]; _result={}; _engine->disconnect(); [_panel orderOut:nil];
    CassotisStopEngine();
    if(raw.length) @try { [self.client insertText:raw replacementRange:NSMakeRange(NSNotFound,NSNotFound)]; }
        @catch(NSException *e) { (void)e; }
}
- (void)tick {
    if(!_active) return;
    if(!_startupKeys.empty()) { [self replayStartup]; return; }
    if(!_engine->connected()) { [self ensureReady]; [self presentModeFeedback]; return; }
    [self presentModeFeedback];
    if(!_result.pending) return;
    try {
        if(++_pollAttempts>120) { _result.pending=false; return; }
        auto result=_engine->poll(); if(result.handled) [self apply:result];
    }
    catch(...) { [self recover]; }
}
- (void)cancelModifierGesture {
    _settingsGesture=NO;
    try { if(_engine->connected()) { cassotis::Key cancel; _engine->key(cancel); } }
    catch(...) { _engine->disconnect(); }
}
- (BOOL)handleEvent:(NSEvent *)event {
    if(!_active) return NO;
    // Ordinary releases do not change input state. Sending them as a new
    // generation would invalidate completion queued by the matching keyDown.
    // Modifier-only shortcuts are handled by flagsChanged below.
    if(event.type==NSEventTypeKeyUp) return NO;
    if(event.type==NSEventTypeKeyDown || event.type==NSEventTypeLeftMouseDown ||
       event.type==NSEventTypeRightMouseDown) [self cancelModeFeedback];
    if(event.type==NSEventTypeLeftMouseDown || event.type==NSEventTypeRightMouseDown) {
        if(_panel.visible && NSPointInRect(NSEvent.mouseLocation,_panel.frame)) return NO;
        [self commit]; [self cancelModifierGesture]; return NO;
    }
    BOOL release=event.type==NSEventTypeKeyUp;
    if(event.type==NSEventTypeFlagsChanged) {
        NSUInteger bit=0;
        switch(event.keyCode) {
            case kVK_Shift:case kVK_RightShift:bit=NSEventModifierFlagShift;break;
            case kVK_Control:case kVK_RightControl:bit=NSEventModifierFlagControl;break;
            case kVK_Option:case kVK_RightOption:bit=NSEventModifierFlagOption;break;
            case kVK_Command:case kVK_RightCommand:bit=NSEventModifierFlagCommand;break;
            default:_modifiers=event.modifierFlags;[self cancelModifierGesture];return NO;
        }
        release=!(event.modifierFlags&bit);
        if(release && !(_modifiers&bit)) { _modifiers=event.modifierFlags; return NO; }
        _modifiers=event.modifierFlags;
    }
    auto key=CassotisTranslateKey(event,release);
    if((key.modifiers&8) || (key.special==5 && (key.modifiers&2)) || event.keyCode==kVK_Function ||
       ((event.modifierFlags&NSEventModifierFlagFunction) && (!key.special || key.special==5))) {
        [self cancelModeFeedback];
        [self commit]; [self cancelModifierGesture]; return NO;
    }
    if(!_startupKeys.empty()) {
        if([self queueStartupKey:key]) return YES;
        [self commit];
    }
    if(![self ensureReady]) return [self queueStartupKey:key];
    try {
        auto state=_engine->state();
        // Match an explicitly configured Option chord against the unmodified
        // layout character. Otherwise leave Option text and dead keys to macOS.
        if((key.modifiers&4) && !key.special) {
            auto shortcutKey=key; shortcutKey.text=utf8(event.charactersIgnoringModifiers);
            auto vk=CassotisShortcutKey(shortcutKey); bool configured=false;
            for(const auto &shortcut:state.shortcuts)
                if(!shortcut.disabled && shortcut.key==vk && shortcut.modifiers==(key.modifiers&7)) configured=true;
            if(!configured) { [self commit]; [self cancelModifierGesture]; return NO; }
            key=shortcutKey;
            if(key.text.size()==1) key.text[0]=unshiftedNumber(key.text[0],key.modifiers);
        }
        if(event.type==NSEventTypeKeyDown && !key.special && key.text.empty()) {
            [self commit]; [self cancelModifierGesture]; return NO;
        }
        const auto &settings=state.shortcuts[4];
        uint16_t vk=CassotisShortcutKey(key);
        BOOL modifierOnly=settings.modifiers==0 && settings.key>=16 && settings.key<=18;
        if(release && _settingsGesture && settings.key==vk) {
            _settingsGesture=NO; [self commit]; [self showSettings]; return YES;
        }
        if(!release && vk!=settings.key) _settingsGesture=NO;
        auto shortcutModifiers=key.modifiers&7;
        if(modifierOnly) shortcutModifiers&=~(settings.key==16?1:settings.key==17?2:4);
        if(!release && !key.repeat && !settings.disabled && settings.key==vk && settings.modifiers==shortcutModifiers) {
            if(modifierOnly) { _settingsGesture=YES; return NO; }
            [self commit]; [self showSettings]; return YES;
        }
        if(!release && event.type==NSEventTypeKeyDown) [self syncSurrounding];
        id eventClient=self.client;
        auto result=_engine->key(key);
        if(result.handled || !result.commit.empty() || !result.preedit.empty()) [self apply:result];
        else if(event.type==NSEventTypeKeyDown) [self commit];
        // Read the authoritative new mode only for the configured mode key;
        // ordinary typing adds no state RPC or work to the input path.
        const auto &modeShortcut=state.shortcuts[0];
        if(_active && self.client==eventClient && _engine->connected() &&
           !modeShortcut.disabled && !key.repeat && vk==modeShortcut.key) {
            auto mode=_engine->state().mode;
            if(mode!=state.mode) [self showInputMode:mode];
        }
        return result.handled;
    } catch(...) { [self recover]; return NO; }
}
- (void)commit {
    if(_committing || _result.preedit.empty()) return;
    _committing=YES;
    // Space can confirm just one segment. The IMK commit barrier must flush
    // the whole marked range exactly once before handing focus to another app.
    @try {
        if(!_startupKeys.empty()) {
            // Focus changes and startup failures preserve the raw text in the
            // original client. Clear ownership before any reentrant callback.
            NSString *raw=_startupText;id client=self.client;
            [self clearStartup];_result={};[_panel orderOut:nil];
            @try { [client insertText:raw replacementRange:NSMakeRange(NSNotFound,NSNotFound)]; }
            @catch(NSException *e) { (void)e; }
            return;
        }
        try {
            for(int i=0;i<128 && !_result.preedit.empty();++i) {
                auto previous=_result.preedit; cassotis::Key k; k.special=5;
                auto result=_engine->key(k); [self apply:result];
                if(previous==_result.preedit) break;
            }
            if(!_result.preedit.empty()) [self recover];
        } catch(...) { [self recover]; }
    } @finally { _committing=NO; }
}
- (void)cancel {
    [self cancelModeFeedback];
    [self clearStartup];
    try { if(_engine->connected()) _engine->reset(); } catch(...) { _engine->disconnect(); }
    [self apply:cassotis::Result{}];
}
- (void)selectCandidate:(NSInteger)index {
    if(!_active || _result.preedit.empty() || ![self ensureReady]) return;
    try {
        cassotis::Key k;
        if(index==-1) { auto state=_engine->state(); if(state.completionKey==0) k.special=6; else k.text="`"; }
        else { if(index<0 || index>=NSInteger(_result.candidates.size()) || index>8) return; k.text=std::to_string(index+1); }
        [self apply:_engine->key(k)];
    } catch(...) { [self recover]; }
}
- (void)deleteCandidate:(NSInteger)index {
    if(!_active || index<0 || index>=NSInteger(_result.candidates.size()) || !_result.candidates[index].deletable) return;
    try {
        [self apply:_engine->removeCandidate(int32_t(index),_result.query,_result.candidates[index])];
    } catch(...) { [self recover]; }
}
- (void)toggle:(NSInteger)action {
    [activeSession commit];
    try {
        cassotis::EngineClient control;
        if(!control.connect(utf8(CassotisSocketPath()))) { CassotisStartEngine(); return; }
        auto s=control.state();
        switch(action) { case 0:s.mode^=1;break;case 1:s.dictionary^=1;break;
            case 2:s.flags^=1;break;case 3:s.flags^=2;break;case 4:s.flags^=4;break;default:return; }
        control.setState(s);
        if(action==0) [activeSession showInputMode:s.mode];
    } catch(...) { [self recover]; }
}
- (NSMenu *)modeMenuWithTarget:(id)target action:(SEL)action {
    NSMenu *menu=[[NSMenu alloc] initWithTitle:CassotisShortName()];
    menu.autoenablesItems=NO;
    try {
        cassotis::EngineClient control;
        if(!control.connect(utf8(CassotisSocketPath()))) {
            CassotisStartEngine(); throw std::runtime_error("engine unavailable");
        }
        auto state=control.state();
        NSArray *titles=@[state.mode==0?@"切换到英文":@"切换到中文",
            state.dictionary==0?@"切换到繁體中文":@"切换到简体中文",
            (state.flags&1)?@"切换到半角":@"切换到全角",
            (state.flags&2)?@"切换到英文标点":@"切换到中文标点",
            (state.flags&4)?@"关闭模糊拼音":@"开启模糊拼音"];
        for(NSUInteger i=0;i<titles.count;++i) {
            NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:titles[i] action:action keyEquivalent:@""];
            item.target=target; item.tag=i; [menu addItem:item];
        }
    } catch(...) {
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"正在连接输入引擎…" action:nil keyEquivalent:@""];
        item.enabled=NO; [menu addItem:item];
    }
    return menu;
}
- (void)showSettings {
    [activeSession cancelModeFeedback]; [activeSession commit];
    [CassotisSettingsController.shared showWindow:nil];
}
@end
