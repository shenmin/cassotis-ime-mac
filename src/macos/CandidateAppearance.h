#pragma once
#import <AppKit/AppKit.h>
#include "EngineClient.hpp"

// IDs 0..2 retain the meaning of the original macOS preferences.
NSArray<NSString *> *CassotisCandidateThemeNames(void);
NSArray<NSNumber *> *CassotisCandidateFontSizes(void);
CGFloat CassotisCandidateFontSize(NSUserDefaults *defaults);
NSInteger CassotisCandidateTheme(NSUserDefaults *defaults);
NSString *CassotisDisplayVersion(void);
struct CassotisCandidateColors {
    NSColor *background, *border, *text, *muted, *weight, *user, *compound;
    NSColor *selection, *selectionBorder, *selectedText, *selectedUser, *selectedCompound, *selectedWeight;
    bool dark;
};
CassotisCandidateColors CassotisColors(NSInteger theme, NSAppearance *appearance);

// Shared by the nonactivating popup and the live settings preview.
NSView *CassotisCandidateView(const cassotis::Result &result, CGFloat fontSize, NSString *family,
    NSInteger theme, CGFloat maximumWidth, NSAppearance *appearance,
    id target, SEL selection, SEL deletion, NSUInteger revision, uint8_t completionKey=0);
