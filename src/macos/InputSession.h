#import <AppKit/AppKit.h>
#include "EngineClient.hpp"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *CassotisSocketPath(void);
FOUNDATION_EXPORT void CassotisStartEngine(void);
FOUNDATION_EXPORT void CassotisStopEngine(void);
// The engine keeps one process-wide Chinese/English mode. The frontend
// remembers the mode the user last chose in each application and restores it
// when that application becomes active again. Preferences live in the input
// method's UserDefaults; absent means enabled, so existing installations get
// the behaviour without a migration step.
FOUNDATION_EXPORT NSString *const CassotisInputModeByApplicationKey;
FOUNDATION_EXPORT NSString *const CassotisRememberInputModeKey;
FOUNDATION_EXPORT BOOL CassotisRememberInputModeEnabled(void);
FOUNDATION_EXPORT void CassotisSetRememberInputModeEnabled(BOOL enabled);
FOUNDATION_EXPORT NSString *const CassotisInputModeHintKey;
FOUNDATION_EXPORT BOOL CassotisInputModeHintEnabled(void);
FOUNDATION_EXPORT void CassotisSetInputModeHintEnabled(BOOL enabled);
// Called on the main thread by the system input-source notification observer.
FOUNDATION_EXPORT void CassotisInputSourceDidChange(void);
// Records the mode for the application that is frontmost right now; used by
// switch paths that run without an active input session.
FOUNDATION_EXPORT void CassotisRememberInputModeForFrontmostApplication(uint8_t mode);
cassotis::Key CassotisTranslateKey(NSEvent *event, BOOL release);
uint16_t CassotisShortcutKey(const cassotis::Key &key);
// System-wide counts and latest times of key and mouse-button presses (inputs)
// and of modifier changes. Times are in system uptime, like NSEvent timestamps.
// steady is NO when events kept arriving between the reads, so that a count
// may not match its time.
struct CassotisInputActivity {
    uint32_t inputs=0, modifiers=0;
    NSTimeInterval lastInput=0, lastModifier=0;
    BOOL steady=YES;
};
// Tracks only a digit delivered by this session. Caret and global counters
// reject intervening input even when the application consumed it before IMK.
struct CassotisDecimalInput {
    uint16_t digit=0;
    NSUInteger expectedCaret=NSNotFound;
    CassotisInputActivity activity;
};
uint16_t CassotisPrecedingDigit(const CassotisDecimalInput &previous,
    const CassotisInputActivity &activity, NSRange selection);
struct CassotisModifierTap {
    BOOL watched=NO, single=NO; uint32_t inputs=0;
    NSTimeInterval pressed=0, handled=0, lastInput=0;
};
extern CassotisInputActivity (*CassotisInputActivitySource)(NSTimeInterval now);
// earlier is the newest sample read before this modifier event was handled.
// A sample never read is all zeros, which is what the counters were at login.
CassotisModifierTap CassotisBeginModifierTap(const CassotisInputActivity &earlier,
    const CassotisInputActivity &activity, NSTimeInterval pressed, NSTimeInterval now);
BOOL CassotisModifierTapInterrupted(const CassotisModifierTap &tap, const CassotisInputActivity &activity,
    NSTimeInterval released, NSTimeInterval now);
BOOL CassotisClientCaretRect(id client, NSRect *rect);
NSRect CassotisPanelFrameAtCaret(NSRect caret, NSSize size, NSRect visible);
NSRect CassotisInputModeFrameAtCaret(NSRect caret, NSSize size, NSRect visible,
    NSArray<NSValue *> *accessories, NSRect current);

@interface CassotisInputModePanel : NSPanel
- (BOOL)showMode:(uint8_t)mode client:(id)client;
- (BOOL)showMode:(uint8_t)mode client:(id)client hold:(NSTimeInterval)hold;
- (void)dismiss;
@end

@interface CassotisCandidatePanel : NSPanel
@property(nonatomic) uint8_t completionKey;
@property(nonatomic, copy, nullable) void (^selection)(NSInteger index);
@property(nonatomic, copy, nullable) void (^deletion)(NSInteger index);
- (void)showResult:(const cassotis::Result &)result client:(id)client;
@end

@interface CassotisInputSession : NSObject
@property(nonatomic, strong, nullable) id client;
@property(nonatomic, readonly) NSString *preedit;
@property(nonatomic, readonly) CassotisCandidatePanel *panel;
@property(nonatomic, readonly) CassotisInputModePanel *modePanel;
- (void)activate:(id)client;
- (BOOL)activateFromNotification:(id)client;
- (NSDictionary<NSAttributedStringKey, id> *)markedTextAttributesForRange:(NSRange)range;
- (void)deactivate;
- (BOOL)handleEvent:(NSEvent *)event;
- (void)commit;
- (void)cancel;
- (void)selectCandidate:(NSInteger)index;
- (void)deleteCandidate:(NSInteger)index;
- (void)showSettings;
- (void)toggle:(NSInteger)action;
- (NSMenu *)modeMenuWithTarget:(id)target action:(SEL)action;
@end
NS_ASSUME_NONNULL_END
