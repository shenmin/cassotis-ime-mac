#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

// Request from the foreground installer so macOS can identify the application
// asking the user to enable this input method.
OSStatus CassotisRequestInputSourceEnablement(void);
NSDictionary *CassotisInputSourceRegistrationState(void);
