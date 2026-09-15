#pragma once
#import <AppKit/AppKit.h>
#include "EngineClient.hpp"

NSString *CassotisShortcutDescription(const cassotis::Shortcut &shortcut);
NSString *CassotisShortcutValidationError(const cassotis::Shortcut &shortcut);

@interface CassotisShortcutRecorder : NSControl
@property(nonatomic) cassotis::Shortcut shortcut;
@property(nonatomic, readonly) NSString *displayString;
@property(nonatomic, readonly) BOOL recording;
@property(nonatomic, copy) void (^validationMessage)(NSString *message);
- (void)beginRecording;
- (void)cancelRecording;
@end
