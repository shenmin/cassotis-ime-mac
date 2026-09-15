#import <AppKit/AppKit.h>
#include "EngineClient.hpp"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *CassotisSocketPath(void);
FOUNDATION_EXPORT void CassotisStartEngine(void);
FOUNDATION_EXPORT void CassotisStopEngine(void);
cassotis::Key CassotisTranslateKey(NSEvent *event, BOOL release);
uint16_t CassotisShortcutKey(const cassotis::Key &key);
BOOL CassotisClientCaretRect(id client, NSRect *rect);
NSRect CassotisPanelFrameAtCaret(NSRect caret, NSSize size, NSRect visible);

@interface CassotisInputModePanel : NSPanel
- (BOOL)showMode:(uint8_t)mode client:(id)client;
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
