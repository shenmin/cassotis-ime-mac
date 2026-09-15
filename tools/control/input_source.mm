#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>
#include <libproc.h>
#include <signal.h>
#include <iostream>
#include <vector>

int main(int argc,const char **argv) {
    @autoreleasepool {
        if(argc<2) return 2;
        NSString *command=[NSString stringWithUTF8String:argv[1]];
        if([command isEqual:@"current"]) {
            TISInputSourceRef current=TISCopyCurrentKeyboardInputSource();
            NSString *identifier=(__bridge NSString *)TISGetInputSourceProperty(current,kTISPropertyInputSourceID);
            std::cout<<(identifier.UTF8String?:"")<<std::endl;CFRelease(current);return 0;
        }
        if([command isEqual:@"prepare-update"]) {
            TISInputSourceRef current=TISCopyCurrentKeyboardInputSource();
            NSString *bundle=(__bridge NSString *)TISGetInputSourceProperty(current,kTISPropertyBundleID);
            if([bundle isEqual:@"org.cassotis.inputmethod.Cassotis"]) {
                TISInputSourceRef ascii=TISCopyCurrentASCIICapableKeyboardInputSource();
                OSStatus status=ascii?TISSelectInputSource(ascii):paramErr;
                if(ascii)CFRelease(ascii);if(status){CFRelease(current);return 1;}
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
            }
            CFRelease(current);
            NSString *installed=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Input Methods/Cassotis.app"];
            for(NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:@"org.cassotis.inputmethod.Cassotis"])
                if([app.bundleURL.path isEqual:installed]) [app terminate];
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
            // Only this user's executable files inside the installed Cassotis
            // bundle are eligible. Benchmarks and other input methods stay live.
            int bytes=proc_listpids(PROC_UID_ONLY,getuid(),nullptr,0);
            std::vector<pid_t> pids(size_t(bytes/sizeof(pid_t)+32));
            bytes=proc_listpids(PROC_UID_ONLY,getuid(),pids.data(),int(pids.size()*sizeof(pid_t)));
            NSString *prefix=[installed stringByAppendingString:@"/Contents/MacOS/"];
            for(int i=0;i<bytes/int(sizeof(pid_t));++i) {
                char path[PROC_PIDPATHINFO_MAXSIZE]={};
                if(proc_pidpath(pids[i],path,sizeof(path))<=0)continue;
                NSString *executable=[NSString stringWithUTF8String:path];
                if([executable isEqual:[prefix stringByAppendingString:@"Cassotis"]] ||
                   [executable isEqual:[prefix stringByAppendingString:@"cassotis-engine"]]) kill(pids[i],SIGTERM);
            }
            [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
            return 0;
        }
        BOOL registrationOnly=[command isEqual:@"register-only"];
        if([command isEqual:@"register"] || registrationOnly) {
            if(argc!=3) return 2;
            NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]];
            OSStatus status=TISRegisterInputSource((__bridge CFURLRef)url);
            std::cout<<"TISRegisterInputSource="<<status<<std::endl;
            if(status) return 1;
            // Installation registers the bundle; System Settings owns user
            // enablement. On newer macOS, TIS can report success after a denied
            // preference write while still changing the input menu's ordering.
            if(registrationOnly) return 0;
        }
        NSDictionary *filter=[command isEqual:@"select-id"] && argc==3?
            @{(__bridge NSString *)kTISPropertyInputSourceID:[NSString stringWithUTF8String:argv[2]]}:
            @{(__bridge NSString *)kTISPropertyBundleID:@"org.cassotis.inputmethod.Cassotis"};
        NSArray *sources=CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter,true));
        for(id item in sources) {
            TISInputSourceRef source=(__bridge TISInputSourceRef)item;
            NSString *identifier=(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceID);
            BOOL enabled=CFBooleanGetValue((CFBooleanRef)TISGetInputSourceProperty(source,kTISPropertyInputSourceIsEnabled));
            BOOL selectable=CFBooleanGetValue((CFBooleanRef)TISGetInputSourceProperty(source,kTISPropertyInputSourceIsSelectCapable));
            NSString *type=(__bridge NSString *)TISGetInputSourceProperty(source,kTISPropertyInputSourceType);
            std::cout<<identifier.UTF8String<<" enabled="<<enabled<<" selectable="<<selectable<<" type="<<type.UTF8String<<std::endl;
            if([command isEqual:@"enable"] || [command isEqual:@"register"]) {
                OSStatus status=TISEnableInputSource(source);if(status) return 1;
            }
            if([command isEqual:@"select"] || [command isEqual:@"select-id"]) { OSStatus status=TISSelectInputSource(source);if(status) return 1; }
            if([command isEqual:@"disable"]) { OSStatus status=TISDisableInputSource(source);if(status) return 1; }
        }
        return sources.count?0:1;
    }
}
