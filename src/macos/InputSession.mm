#import "InputSession.h"
#import "SettingsController.h"
#import "ProductName.h"
#import "RuntimeLog.h"
#import <InputMethodKit/InputMethodKit.h>
#import <Carbon/Carbon.h>
#import <os/log.h>
#include <algorithm>
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
// Per-application Chinese/English memory. The engine keeps one process-wide
// mode; the frontend remembers the mode the user last chose in each
// application and restores it when that application becomes active again.
// Stored in the input method's UserDefaults so it survives a restart of the
// frontend or the system. An absent switch means enabled, so an existing
// installation gets the behaviour without a migration step.
NSString *const CassotisInputModeByApplicationKey=@"InputModeByApplication";
NSString *const CassotisRememberInputModeKey=@"RememberInputModePerApplication";
BOOL CassotisRememberInputModeEnabled(void) {
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    if([defaults objectForKey:CassotisRememberInputModeKey]==nil) return YES;
    return [defaults boolForKey:CassotisRememberInputModeKey];
}
void CassotisSetRememberInputModeEnabled(BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:CassotisRememberInputModeKey];
}
static BOOL CassotisRememberedInputMode(NSString *bundle, uint8_t *mode) {
    if(!bundle.length) return NO;
    NSDictionary *table=[NSUserDefaults.standardUserDefaults dictionaryForKey:CassotisInputModeByApplicationKey];
    NSNumber *value=table[bundle];
    if(![value isKindOfClass:NSNumber.class]) return NO;
    NSInteger stored=value.integerValue;
    if(stored<0 || stored>1) return NO;
    *mode=(uint8_t)stored;
    return YES;
}
static void CassotisStoreRememberedInputMode(NSString *bundle, uint8_t mode) {
    if(!bundle.length) return;
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *table=[NSMutableDictionary dictionary];
    NSDictionary *existing=[defaults dictionaryForKey:CassotisInputModeByApplicationKey];
    if([existing isKindOfClass:NSDictionary.class]) [table addEntriesFromDictionary:existing];
    NSNumber *value=table[bundle];
    if([value isKindOfClass:NSNumber.class] && value.integerValue==(NSInteger)mode) return;
    table[bundle]=@(mode);
    [defaults setObject:table forKey:CassotisInputModeByApplicationKey];
}
void CassotisRememberInputModeForFrontmostApplication(uint8_t mode) {
    if(!CassotisRememberInputModeEnabled()) return;
    CassotisStoreRememberedInputMode(NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier,mode);
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
// IMK never delivers a key or click that the frontmost application consumed
// itself, so a chord such as Shift+Return in a terminal looks like a bare
// modifier tap. These Quartz counters still record that input, as counts and
// times only, and need no privacy permission. Scrolling is left out because
// trackpad momentum continues after the fingers lift.
static CassotisInputActivity systemInputActivity(NSTimeInterval now) {
    static const CGEventType inputs[]={kCGEventKeyDown,kCGEventLeftMouseDown,
        kCGEventRightMouseDown,kCGEventOtherMouseDown};
    const auto source=kCGEventSourceStateCombinedSessionState;
    auto counts=[&] {
        std::pair<uint32_t,uint32_t> n{0,CGEventSourceCounterForEventType(source,kCGEventFlagsChanged)};
        for(auto type:inputs) n.first+=CGEventSourceCounterForEventType(source,type);
        return n;
    };
    CassotisInputActivity a;
    // An event arriving between the reads would pair an old count with its new
    // time. Read again until the counts on both sides of the times agree.
    for(int attempt=0;attempt<3;++attempt) {
        const auto before=counts(); a.inputs=before.first; a.modifiers=before.second; a.lastInput=0;
        for(auto type:inputs)
            a.lastInput=std::max(a.lastInput,now-CGEventSourceSecondsSinceLastEventType(source,type));
        a.lastModifier=now-CGEventSourceSecondsSinceLastEventType(source,kCGEventFlagsChanged);
        if((a.steady=before==counts())) break;
    }
    return a;
}
CassotisInputActivity (*CassotisInputActivitySource)(NSTimeInterval)=systemInputActivity;
uint16_t CassotisPrecedingDigit(const CassotisDecimalInput &previous,
    const CassotisInputActivity &activity, NSRange selection) {
    if(previous.digit<'0' || previous.digit>'9' || !previous.activity.steady || !activity.steady ||
       activity.inputs-previous.activity.inputs!=1 || activity.modifiers!=previous.activity.modifiers ||
       selection.length || selection.location!=previous.expectedCaret) return 0;
    return previous.digit;
}
static NSRange clientSelection(id client) {
    @try { return [client selectedRange]; }
    @catch(NSException *error) { (void)error; return NSMakeRange(NSNotFound,0); }
}
// A synthetic event may carry no usable timestamp; judge it from when it is handled.
static NSTimeInterval eventTime(NSTimeInterval timestamp, NSTimeInterval now) {
    return timestamp>now-10 && timestamp<=now?timestamp:now;
}
// The counters time a modifier change a few milliseconds before its NSEvent
// timestamp. Any other modifier time belongs to a different change, which
// hides when this one was counted.
static NSTimeInterval countedTime(NSTimeInterval event, NSTimeInterval lastModifier, NSTimeInterval hidden) {
    return lastModifier<=event && lastModifier>=event-0.05?lastModifier:hidden;
}
CassotisModifierTap CassotisBeginModifierTap(const CassotisInputActivity &earlier, const CassotisInputActivity &a,
    NSTimeInterval pressed, NSTimeInterval now) {
    CassotisModifierTap tap; pressed=eventTime(pressed,now);
    // The press itself must appear in the counters. Otherwise they are
    // unusable, or the event did not pass through the window server.
    tap.watched=a.steady && a.modifiers && a.lastModifier>=pressed-0.05;
    // Whether input already counted here belongs to the hold is decided at
    // the release: a delayed handler may run after the release and the
    // keystroke that followed it. A hidden press is assumed to have been
    // counted early, so that input just before it is not ruled out.
    tap.pressed=countedTime(pressed,a.lastModifier,pressed-0.02); tap.handled=now;
    tap.inputs=a.inputs; tap.lastInput=a.lastInput;
    // An earlier sample without input since the press shows how many inputs
    // this one adds to it. Only the time of the last of them is known.
    tap.single=earlier.steady && earlier.lastInput<tap.pressed && a.inputs-earlier.inputs==1;
    return tap;
}
BOOL CassotisModifierTapInterrupted(const CassotisModifierTap &tap, const CassotisInputActivity &a,
    NSTimeInterval released, NSTimeInterval now) {
    if(!tap.watched) return NO;
    released=eventTime(released,now);
    const NSTimeInterval end=countedTime(released,a.lastModifier,released);
    // Input already counted when the press was handled interrupts the tap. A
    // handler delayed past the release may also have counted the keystroke
    // that followed, which hides the time of any input before it. Only an
    // earlier sample can show that this keystroke was the single input.
    if(tap.lastInput>=tap.pressed) return !(tap.single && tap.lastInput>end);
    // A press handled after the release had every input of the hold in its
    // baseline, so whatever was counted later followed the release.
    if(tap.handled>=released) return NO;
    uint32_t inputs=a.inputs-tap.inputs;
    // One input after the release is the next keystroke, counted before this
    // handler ran. A count that may not match its time cannot show that.
    return inputs && !(inputs==1 && a.steady && a.lastInput>end);
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
    BOOL _active, _committing, _settingsGesture, _restorePending;
    NSUInteger _modifiers;
    CassotisModifierTap _tap;
    CassotisInputActivity _seen;
    CassotisDecimalInput _decimalInput;
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
    // Reached only when the user changed the mode, never when an application
    // inherits the current one, so this is the one place a per-application
    // memory may be written.
    _restorePending=NO;
    if(CassotisRememberInputModeEnabled())
        CassotisStoreRememberedInputMode([self applicationIdentifier],mode);
    [self presentModeFeedback];
}
// The client owns the application identity; the workspace is only a fallback
// for hosts whose text view does not expose one (some WebKit and custom
// views).
- (NSString *)applicationIdentifier {
    NSString *bundle=nil;
    @try {
        if([self.client respondsToSelector:@selector(bundleIdentifier)])
            bundle=[self.client bundleIdentifier];
    } @catch(NSException *error) { (void)error; }
    if(!bundle.length) bundle=NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier;
    return bundle;
}
// An application the user never switched in keeps whatever mode is active;
// only a mode chosen while that application was frontmost is remembered and
// restored here. Runs once per activation, as soon as the engine is ready.
- (void)restoreRememberedInputModeIfPending {
    if(!_restorePending || !_engine->connected()) return;
    _restorePending=NO;
    if(!CassotisRememberInputModeEnabled()) return;
    uint8_t remembered=0;
    if(!CassotisRememberedInputMode([self applicationIdentifier],&remembered)) return;
    try {
        auto state=_engine->state(false);
        if(state.mode==remembered) return;
        state.mode=remembered;
        _engine->setState(state);
        _inputMode=remembered;
    } catch(...) { /* engine not reachable: keep the current mode */ }
}
- (BOOL)ensureReady {
    if(_engine->connected()) return YES;
    if(!_engine->connect(utf8(CassotisSocketPath()))) { CassotisStartEngine(); return NO; }
    try {
        _engine->active(true);
        auto state=_engine->state(false); _panel.completionKey=state.completionKey;
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
    if(newActivation) _decimalInput={};
    // Some clients activate the next IMK controller before deactivating the
    // old one. End the previous marked range before switching the shared core.
    if(activeSession && activeSession!=self) [activeSession deactivate];
    if(_active && self.client!=client) [self deactivate];
    activeSession=self;
    self.client=client; _active=YES; _modifiers=0; _tap={}; _settingsGesture=NO;
    if(newActivation) { _modeKnown=NO; _modeFeedbackPending=YES; _restorePending=YES; }
    [self ensureReady]; [self restoreRememberedInputModeIfPending]; [self presentModeFeedback];
    [_timer invalidate]; __weak CassotisInputSession *weak=self;
    _timer=[NSTimer timerWithTimeInterval:0.025 repeats:YES block:^(NSTimer *t){
        (void)t; [weak tick];
    }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (void)deactivate {
    _decimalInput={};
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
        if(selected.location==NSNotFound) return nil;
        if(selected.location==0) return @"";
        NSUInteger start=selected.location>1024?selected.location-1024:0;
        NSAttributedString *prefix=[self.client attributedSubstringFromRange:NSMakeRange(start,selected.location-start)];
        if(!prefix) return nil;
        NSString *text=prefix.string;
        if(text.length>1024) text=[text substringFromIndex:text.length-1024];
        if(text.length && CFStringIsSurrogateLowCharacter([text characterAtIndex:0])) text=[text substringFromIndex:1];
        return text;
    } @catch(NSException *e) { (void)e; return nil; }
}
- (void)syncSurrounding {
    if(!_result.preedit.empty()) return;
    NSString *text=[self surroundingText];
    _engine->surrounding(utf8(text),(int32_t)text.length,text!=nil);
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
    // Restore before replaying buffered keys so they are interpreted with the
    // mode this application last used.
    [self restoreRememberedInputModeIfPending];
    try {
        // Read context before the provisional marked range was inserted. Keep
        // that range visible until all already-consumed keys have been replayed.
        _engine->surrounding(utf8(_startupContext),(int32_t)_startupContext.length,_startupContext!=nil);
        cassotis::Result final;std::string committed;
        for(const auto &key:_startupKeys) {
            if(final.preedit.empty() && !committed.empty()) {
                NSString *context=[_startupContext stringByAppendingString:str(committed)];
                if(context.length>1024)context=[context substringFromIndex:context.length-1024];
                if(context.length && CFStringIsSurrogateLowCharacter([context characterAtIndex:0]))
                    context=[context substringFromIndex:1];
                _engine->surrounding(utf8(context),(int32_t)context.length,_startupContext!=nil);
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
    _decimalInput={};
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
    if(!_engine->connected()) { [self ensureReady]; [self restoreRememberedInputModeIfPending]; [self presentModeFeedback]; return; }
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
- (void)watchModifierTap:(NSEvent *)event release:(BOOL)release {
    const NSUInteger held=_modifiers&(NSEventModifierFlagShift|NSEventModifierFlagControl|
        NSEventModifierFlagOption|NSEventModifierFlagCommand);
    NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    auto activity=CassotisInputActivitySource(now);
    // Keep the earliest baseline while any modifier remains held.
    if(!release && !held) _tap=CassotisBeginModifierTap(_seen,activity,event.timestamp,now);
    _seen=activity;
    if(!release) return;
    BOOL interrupted=CassotisModifierTapInterrupted(_tap,activity,event.timestamp,now);
    // Opt-in diagnostics record counts and timings, never input.
    if(getenv("CASSOTIS_TRACE_INPUT"))
        os_log(OS_LOG_DEFAULT,"Cassotis modifier-tap watched=%d interrupted=%d inputs=%u steady=%d lag=%.1fms skew=%.1fms",
            _tap.watched,interrupted,activity.inputs-_tap.inputs,activity.steady,(now-event.timestamp)*1000,
            (activity.lastModifier-event.timestamp)*1000);
    // The release still reaches the engine below to end its pending shortcut.
    if(interrupted) [self cancelModifierGesture];
}
- (BOOL)handleEvent:(NSEvent *)event {
    if(!_active) return NO;
    // Ordinary releases preserve pending completion and the preceding digit.
    // Modifier-only shortcuts are handled by flagsChanged below.
    if(event.type==NSEventTypeKeyUp) return NO;
    const auto preceding=_decimalInput;
    _decimalInput={};
    // IMK also delivers other NSEvent types here, such as mouse drags. Reading
    // keyCode from a non-key event raises NSInternalInconsistencyException and
    // breaks the input connection, so filter by type first.
    if(event.type!=NSEventTypeKeyDown &&
       event.type!=NSEventTypeFlagsChanged && event.type!=NSEventTypeLeftMouseDown &&
       event.type!=NSEventTypeRightMouseDown) return NO;
    // A modifier press handled late compares the counters with those read
    // for the event before it.
    if(event.type!=NSEventTypeFlagsChanged)
        _seen=CassotisInputActivitySource(NSProcessInfo.processInfo.systemUptime);
    if(event.type==NSEventTypeKeyDown || event.type==NSEventTypeLeftMouseDown ||
       event.type==NSEventTypeRightMouseDown) [self cancelModeFeedback];
    if(event.type==NSEventTypeLeftMouseDown || event.type==NSEventTypeRightMouseDown) {
        if(_panel.visible && NSPointInRect(NSEvent.mouseLocation,_panel.frame)) return NO;
        [self commit]; [self cancelModifierGesture]; return NO;
    }
    BOOL release=NO;
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
        [self watchModifierTap:event release:release];
        _modifiers=event.modifierFlags;
    }
    auto key=CassotisTranslateKey(event,release);
    const auto selection=clientSelection(self.client);
    if(event.type==NSEventTypeKeyDown && !(key.modifiers&15) && _result.preedit.empty())
        key.precedingDigit=CassotisPrecedingDigit(preceding,_seen,selection);
    if((key.modifiers&8) || (key.special==5 && (key.modifiers&2)) || event.keyCode==kVK_Function ||
       ((event.modifierFlags&NSEventModifierFlagFunction) && (!key.special || key.special==5))) {
        [self cancelModeFeedback];
        [self commit]; [self cancelModifierGesture]; return NO;
    }
    if(!_startupKeys.empty()) {
        if([self queueStartupKey:key]) return YES;
        [self commit];
    }
    id eventClient=self.client;
    const bool plainDigit=event.type==NSEventTypeKeyDown && !(key.modifiers&15) &&
        key.text.size()==1 && key.text[0]>='0' && key.text[0]<='9' && _result.preedit.empty();
    auto rememberDigit=[&] {
        if(!plainDigit || !_active || self.client!=eventClient) return;
        _decimalInput.digit=key.text[0];
        _decimalInput.activity=_seen;
        _decimalInput.expectedCaret=selection.location==NSNotFound?NSNotFound:selection.location+1;
    };
    if(![self ensureReady]) {
        BOOL queued=[self queueStartupKey:key];
        // Standalone digits pass through while the helper starts. Preserve the
        // same evidence as the ready path: it may connect before the next period.
        if(!queued) rememberDigit();
        return queued;
    }
    // The engine can become ready here rather than in tick, so a key arriving
    // before the next timer callback must not be read in the mode the previous
    // application left behind.
    [self restoreRememberedInputModeIfPending];
    try {
        auto state=_engine->state(false);
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
        auto result=_engine->key(key);
        if(result.handled || !result.commit.empty() || !result.preedit.empty()) [self apply:result];
        else if(event.type==NSEventTypeKeyDown) [self commit];
        if(plainDigit && result.preedit.empty() &&
           (!result.handled || result.commit==key.text ||
            result.commit==utf8([NSString stringWithFormat:@"%C",(unichar)(0xff10+key.text[0]-'0')])))
            rememberDigit();
        // Read the authoritative new mode only for the configured mode key;
        // ordinary typing adds no state RPC or work to the input path.
        const auto &modeShortcut=state.shortcuts[0];
        if(_active && self.client==eventClient && _engine->connected() &&
           !modeShortcut.disabled && !key.repeat && vk==modeShortcut.key) {
            auto mode=_engine->state(false).mode;
            if(mode!=state.mode) [self showInputMode:mode];
        }
        return result.handled;
    } catch(...) { [self recover]; return NO; }
}
- (void)commit {
    _decimalInput={};
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
    _decimalInput={};
    [self cancelModeFeedback];
    [self clearStartup];
    try { if(_engine->connected()) _engine->reset(); } catch(...) { _engine->disconnect(); }
    [self apply:cassotis::Result{}];
}
- (void)candidateAction:(NSInteger)tag remove:(BOOL)remove {
    if(!_active || tag<0 || _result.preedit.empty() || !_engine->connected()) return;
    int32_t page=_result.page, index=int32_t(tag);
    if(tag>=16) { page=int32_t(tag/16)-1; index=int32_t(tag%16); }
    if(index<0 || index>=9) return;
    const cassotis::Candidate *candidate=nullptr;
    if(page==_result.page && index<int32_t(_result.candidates.size())) candidate=&_result.candidates[index];
    else for(const auto &row:_result.candidatePages)
        if(row.page==page && index<int32_t(row.candidates.size())) candidate=&row.candidates[index];
    if(!candidate || (remove && !candidate->deletable)) return;
    try {
        [self apply:_engine->candidateAction(_result.candidateRevision,page,index,remove,_result.query,*candidate)];
    } catch(...) { [self recover]; }
}
- (void)selectCandidate:(NSInteger)index {
    _decimalInput={};
    if(index==-2) {
        if(!_active || _result.rawInput.empty() || _result.preedit.empty() || !_engine->connected()) return;
        cassotis::Candidate expected; expected.text=_result.rawInput;
        try { [self apply:_engine->candidateAction(_result.candidateRevision,0,-1,false,_result.query,expected)]; }
        catch(...) { [self recover]; }
        return;
    }
    if(index!=-1) { [self candidateAction:index remove:NO]; return; }
    if(!_active || _result.preedit.empty() || !_engine->connected()) return;
    try {
        cassotis::Key k; auto state=_engine->state(false);
        if(state.completionKey==0) k.special=6; else k.text="`";
        [self apply:_engine->key(k)];
    } catch(...) { [self recover]; }
}
- (void)deleteCandidate:(NSInteger)index {
    _decimalInput={}; [self candidateAction:index remove:YES]; }
- (void)toggle:(NSInteger)action {
    _decimalInput={};
    [activeSession commit];
    try {
        cassotis::EngineClient control;
        if(!control.connect(utf8(CassotisSocketPath()))) { CassotisStartEngine(); return; }
        auto s=control.state(false);
        switch(action) { case 0:s.mode^=1;break;case 1:s.dictionary^=1;break;
            case 2:s.flags^=1;break;case 3:s.flags^=2;break;case 4:s.flags^=4;break;default:return; }
        control.setState(s);
        if(action==0) {
            if(activeSession) [activeSession showInputMode:s.mode];
            else CassotisRememberInputModeForFrontmostApplication(s.mode);
        }
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
        auto state=control.state(false);
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
    _decimalInput={};
    [activeSession cancelModeFeedback]; [activeSession commit];
    [CassotisSettingsController.shared showWindow:nil];
}
@end
