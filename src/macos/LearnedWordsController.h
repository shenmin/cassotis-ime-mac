#pragma once
#import <AppKit/AppKit.h>

@interface CassotisLearnedWordsController : NSWindowController
- (void)showForWindow:(NSWindow *)parent;
- (void)exportForWindow:(NSWindow *)parent completion:(void (^)(NSString *message))completion;
@end
