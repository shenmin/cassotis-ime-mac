#import "InputSourceRegistration.h"

static NSString *const CassotisInputSourceID=@"org.cassotis.inputmethod.Cassotis";

static NSArray *sources(void) {
    NSDictionary *filter=@{(__bridge NSString *)kTISPropertyInputSourceID:CassotisInputSourceID};
    return CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter,true))?:@[];
}

OSStatus CassotisRequestInputSourceEnablement(void) {
    NSURL *url=[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Input Methods/Cassotis.app"]];
    if(![[NSBundle bundleWithURL:url].bundleIdentifier isEqual:CassotisInputSourceID]) return fnfErr;
    OSStatus status=TISRegisterInputSource((__bridge CFURLRef)url);
    if(status!=noErr) return status;
    for(id item in sources()) {
        // Do not skip this based on a cached IsEnabled value: macOS can report
        // enabled while the user's approval is still absent.
        return TISEnableInputSource((__bridge TISInputSourceRef)item);
    }
    return fnfErr;
}

NSDictionary *CassotisInputSourceRegistrationState(void) {
    BOOL registered=NO,enabled=NO;
    for(id item in sources()) {
        registered=YES;
        TISInputSourceRef source=(__bridge TISInputSourceRef)item;
        CFBooleanRef active=(CFBooleanRef)TISGetInputSourceProperty(source,kTISPropertyInputSourceIsEnabled);
        CFBooleanRef selectable=(CFBooleanRef)TISGetInputSourceProperty(source,kTISPropertyInputSourceIsSelectCapable);
        enabled=active && selectable && CFBooleanGetValue(active) && CFBooleanGetValue(selectable);
    }
    // TIS alone can report success before the protected approval is persisted.
    // Read this macOS state, never write it. If it is unavailable, keep the
    // Settings fallback instead of claiming the source has been enabled.
    id approval=CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("AppleEnabledThirdPartyInputSources"),CFSTR("com.apple.inputsources")));
    BOOL approved=NO,approvalReadable=[approval isKindOfClass:NSArray.class];
    if(approvalReadable) for(id record in approval) {
        if([record isKindOfClass:NSDictionary.class] && [record[@"Bundle ID"] isEqual:CassotisInputSourceID]) approved=YES;
    }
    return @{@"registered":@(registered),@"tisEnabled":@(enabled),
             @"approvalReadable":@(approvalReadable),@"approved":@(approved),
             @"enabled":@(registered && enabled && approved)};
}
