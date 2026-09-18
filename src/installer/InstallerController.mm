#import "InstallerController.h"
#import "InputSourceRegistration.h"
#import "../macos/ProductName.h"

@implementation CassotisInstallerController {
    NSURL *_payload;
    NSTextField *_heading, *_message, *_steps;
    NSButton *_primary, *_secondary, *_uninstall;
    NSProgressIndicator *_progress;
    BOOL _working, _succeeded, _removing, _enabling, _inputSourceEnabled;
    NSUInteger _enablementGeneration, _enabledSamples;
    NSTimeInterval _enablementDeadline;
    NSString *_output;
}
- (instancetype)initWithPayloadURL:(NSURL *)payload {
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,600,470)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self=[super initWithWindow:window]; if(!self) return nil;
    _payload=payload;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[payload URLByAppendingPathComponent:@"Cassotis.app/Contents/Info.plist"]];
    NSString *version=info[@"CFBundleShortVersionString"]?:@"";
    window.title=[NSString stringWithFormat:@"%@ (v%@) - 安装器",CassotisProductName(),version];
    window.delegate=self; window.releasedWhenClosed=NO; [window center];
    NSView *root=window.contentView;
    NSImage *logo=[[NSImage alloc] initWithContentsOfURL:[payload URLByAppendingPathComponent:@"Cassotis.app/Contents/Resources/Cassotis.png"]];
    NSImageView *icon=[NSImageView imageViewWithImage:logo?:NSApp.applicationIconImage];
    icon.imageScaling=NSImageScaleProportionallyUpOrDown;
    _heading=[NSTextField labelWithString:@"言泉输入法安装器"];
    _heading.font=[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold];
    _heading.accessibilityIdentifier=@"installer-heading";
    NSTextField *subtitle=[NSTextField labelWithString:[NSString stringWithFormat:@"%@ · v%@",CassotisProductName(),version]];
    subtitle.textColor=NSColor.secondaryLabelColor;
    _message=[NSTextField wrappingLabelWithString:@"此程序用于安装、更新或卸载言泉输入法。"];
    _message.font=[NSFont systemFontOfSize:14]; _message.accessibilityIdentifier=@"installer-message";
    _steps=[NSTextField wrappingLabelWithString:@"点击“安装”，将输入法安装到当前用户账户并请求启用。\n\n如果 macOS 弹出确认，请允许使用言泉输入法。\n\n升级会保留设置和学习记录，不改变当前选用的输入法。"];
    _steps.font=[NSFont systemFontOfSize:13]; _steps.textColor=NSColor.secondaryLabelColor;
    _steps.accessibilityIdentifier=@"installer-steps";
    _progress=[[NSProgressIndicator alloc] init]; _progress.style=NSProgressIndicatorStyleBar;
    _progress.indeterminate=YES; _progress.displayedWhenStopped=NO;
    _primary=[NSButton buttonWithTitle:@"安装" target:self action:@selector(install:)];
    _primary.keyEquivalent=@"\r"; _primary.accessibilityIdentifier=@"installer-primary";
    _secondary=[NSButton buttonWithTitle:@"退出" target:self action:@selector(quit:)];
    _secondary.accessibilityIdentifier=@"installer-secondary";
    _uninstall=[NSButton buttonWithTitle:@"卸载…" target:self action:@selector(uninstall:)];
    _uninstall.bordered=NO; _uninstall.contentTintColor=NSColor.secondaryLabelColor;
    _uninstall.accessibilityIdentifier=@"installer-uninstall";
    NSString *installed=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Input Methods/Cassotis.app"];
    if([NSFileManager.defaultManager fileExistsAtPath:installed]) _primary.title=@"安装 / 更新";
    else _uninstall.hidden=YES;
    for(NSView *view in @[icon,_heading,subtitle,_message,_steps,_progress,_primary,_secondary,_uninstall]) {
        [root addSubview:view]; view.translatesAutoresizingMaskIntoConstraints=NO;
    }
    [NSLayoutConstraint activateConstraints:@[[icon.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32],
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:30], [icon.widthAnchor constraintEqualToConstant:64],
        [icon.heightAnchor constraintEqualToConstant:64], [_heading.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:20],
        [_heading.topAnchor constraintEqualToAnchor:icon.topAnchor constant:2],
        [subtitle.leadingAnchor constraintEqualToAnchor:_heading.leadingAnchor], [subtitle.topAnchor constraintEqualToAnchor:_heading.bottomAnchor constant:8],
        [_message.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32], [_message.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-32],
        [_message.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:32],
        [_steps.leadingAnchor constraintEqualToAnchor:_message.leadingAnchor], [_steps.trailingAnchor constraintEqualToAnchor:_message.trailingAnchor],
        [_steps.topAnchor constraintEqualToAnchor:_message.bottomAnchor constant:22],
        [_progress.leadingAnchor constraintEqualToAnchor:_message.leadingAnchor], [_progress.trailingAnchor constraintEqualToAnchor:_message.trailingAnchor],
        [_progress.bottomAnchor constraintEqualToAnchor:_primary.topAnchor constant:-24],
        [_primary.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-32], [_primary.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-26],
        [_primary.widthAnchor constraintGreaterThanOrEqualToConstant:108],
        [_secondary.trailingAnchor constraintEqualToAnchor:_primary.leadingAnchor constant:-12], [_secondary.centerYAnchor constraintEqualToAnchor:_primary.centerYAnchor],
        [_uninstall.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:28], [_uninstall.centerYAnchor constraintEqualToAnchor:_primary.centerYAnchor]]];
    return self;
}
- (BOOL)working { return _working; }
- (BOOL)succeeded { return _succeeded; }
- (BOOL)enabling { return _enabling; }
- (BOOL)inputSourceEnabled { return _inputSourceEnabled; }
- (void)windowWillClose:(NSNotification *)notification {
    (void)notification; _enabling=NO; ++_enablementGeneration;
}
- (BOOL)windowShouldClose:(NSWindow *)window {
    (void)window;
    if(_working) { NSBeep(); return NO; }
    return YES;
}
- (void)quit:(id)sender { (void)sender; if(!_working) [NSApp terminate:nil]; }
- (void)openSettings:(id)sender {
    (void)sender;
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.Keyboard-Settings.extension"]];
}
- (void)showLog:(id)sender {
    (void)sender;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"安装日志";
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,500,240)]; scroll.hasVerticalScroller=YES;
    NSTextView *text=[[NSTextView alloc] initWithFrame:scroll.bounds]; text.editable=NO;
    text.font=[NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular]; text.string=_output?:@"";
    text.autoresizingMask=NSViewWidthSizable; text.textContainer.widthTracksTextView=YES; scroll.documentView=text;
    alert.accessoryView=scroll; [alert addButtonWithTitle:@"关闭"]; [alert addButtonWithTitle:@"复制日志"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response==NSAlertSecondButtonReturn) { [NSPasteboard.generalPasteboard clearContents];
            [NSPasteboard.generalPasteboard setString:self->_output?:@"" forType:NSPasteboardTypeString]; }
    }];
}
- (void)runOperation:(BOOL)remove {
    if(_working || _enabling) return;
    _working=YES; _succeeded=NO; _removing=remove;
    _primary.enabled=NO; _secondary.enabled=NO; _uninstall.hidden=YES;
    _heading.stringValue=remove?@"正在卸载…":@"正在安装…";
    _message.stringValue=remove?@"正在移出输入法应用，设置和学习记录会保留。":@"正在安装输入法、词库和本地模型，请稍候。";
    _steps.stringValue=@""; [_progress startAnimation:nil];
    NSURL *script=[_payload URLByAppendingPathComponent:remove?@"scripts/uninstall.sh":@"scripts/install.sh"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSTask *task=[[NSTask alloc] init]; task.executableURL=[NSURL fileURLWithPath:@"/bin/bash"];
        task.arguments=remove?@[script.path,@"--require-disabled"]:@[script.path]; task.currentDirectoryURL=self->_payload;
        NSMutableDictionary *environment=[NSProcessInfo.processInfo.environment mutableCopy];
        for(NSString *key in [environment.allKeys copy]) if([key hasPrefix:@"CASSOTIS_"]) [environment removeObjectForKey:key];
        // GUI launches need only system tools. No shell startup files, compiler or Python.
        environment[@"PATH"]=@"/usr/bin:/bin:/usr/sbin:/sbin"; task.environment=environment;
        NSPipe *pipe=[NSPipe pipe]; task.standardOutput=pipe; task.standardError=pipe;
        task.standardInput=NSFileHandle.fileHandleWithNullDevice;
        NSError *error=nil; BOOL launched=[task launchAndReturnError:&error]; NSString *output; int status=126;
        if(launched) {
            NSData *data=[pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit];
            output=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]?:@"无法读取安装日志。";
            status=task.terminationStatus;
        } else output=error.localizedDescription?:@"无法启动安装程序。";
        dispatch_async(dispatch_get_main_queue(),^{ [self finished:status output:output]; });
    });
}
- (void)finished:(int)status output:(NSString *)output {
    BOOL ok=status==0;
    _working=NO; _succeeded=ok; _output=output; [_progress stopAnimation:nil];
    _primary.enabled=YES; _secondary.enabled=YES;
    if(_removing && status==3) {
        _heading.stringValue=@"先移除输入源";
        _message.stringValue=@"言泉输入法仍在系统输入源列表中，请先移除后再卸载。";
        _steps.stringValue=@"打开键盘设置，进入“文字输入 → 编辑”。\n\n选中言泉输入法，点击“−”移除。\n\n回到此窗口，点击“重试卸载”。";
        _primary.title=@"打开键盘设置"; _primary.action=@selector(openSettings:);
        _secondary.title=@"重试卸载"; _secondary.action=@selector(retry:);
    } else if(ok && !_removing) {
        [self beginEnablement];
    } else if(ok) {
        _heading.stringValue=@"已卸载";
        _message.stringValue=@"应用已移出输入法目录，设置和学习记录已保留。";
        _steps.stringValue=@"重新安装后，可继续使用原来的设置和学习记录。";
        _primary.title=@"完成"; _primary.action=@selector(quit:);
        _secondary.title=@"完成"; _secondary.action=@selector(quit:);
        _secondary.hidden=YES;
    } else {
        _heading.stringValue=_removing?@"卸载未完成":@"安装未完成";
        _message.stringValue=@"请查看安装日志中的原因，处理后重试。";
        _steps.stringValue=@"如果是磁盘空间不足，请先释放空间。若仍无法完成，可复制日志用于反馈。";
        _primary.title=@"重试"; _primary.action=@selector(retry:);
        _secondary.title=@"查看日志…"; _secondary.action=@selector(showLog:);
    }
}
- (OSStatus)requestInputSourceEnablement {
    return CassotisRequestInputSourceEnablement();
}
- (NSTimeInterval)enablementWaitLimit { return 45; }
- (void)readInputSourceState:(void (^)(NSDictionary *))completion {
    // The TIS snapshot belongs to its process. Use a new process for each read;
    // success from the enabling process can be just an unapproved cache entry.
    NSURL *executable=NSBundle.mainBundle.executableURL;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSTask *task=[[NSTask alloc] init]; task.executableURL=executable;
        task.arguments=@[@"--input-source-status"];
        NSPipe *pipe=[NSPipe pipe]; task.standardOutput=pipe;
        task.standardError=NSFileHandle.fileHandleWithNullDevice;
        task.standardInput=NSFileHandle.fileHandleWithNullDevice;
        NSDictionary *state=nil;
        if([task launchAndReturnError:nil]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
                if(task.running) [task terminate];
            });
            NSData *data=[pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit];
            id decoded=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if(task.terminationStatus==0 && [decoded isKindOfClass:NSDictionary.class]) state=decoded;
        }
        dispatch_async(dispatch_get_main_queue(),^{ completion(state); });
    });
}
- (void)finishEnablement:(BOOL)enabled {
    _enabling=NO; _inputSourceEnabled=enabled; [_progress stopAnimation:nil];
    _heading.stringValue=enabled?@"安装完成":@"已安装，尚未启用";
    _message.stringValue=enabled?@"言泉输入法已添加到系统输入菜单，可以直接选用。":@"应用已安装，macOS 尚未确认启用言泉输入法。";
    _steps.stringValue=enabled?@"从菜单栏的输入菜单选择“言泉输入法”，即可开始输入。\n\n输入 nihao，再按空格，可试打“你好”。\n\n原有设置和学习记录已保留。":
        @"如有系统确认窗口，请允许使用言泉输入法。\n\n也可点击“重试启用”，再次请求系统启用。\n\n若仍未成功，打开键盘设置，在“文字输入 → 编辑 → + → 中文（简体）”中添加言泉输入法。";
    _primary.enabled=YES; _primary.title=enabled?@"完成":@"重试启用";
    _primary.action=enabled?@selector(quit:):@selector(retryEnablement:);
    _secondary.enabled=YES; _secondary.hidden=NO; _secondary.title=@"打开键盘设置";
    _secondary.action=@selector(openSettings:);
}
- (void)pollEnablement:(NSUInteger)generation {
    __weak CassotisInstallerController *weakSelf=self;
    [self readInputSourceState:^(NSDictionary *state) {
        CassotisInstallerController *owner=weakSelf;
        if(!owner || !owner->_enabling || generation!=owner->_enablementGeneration) return;
        BOOL enabled=[state[@"enabled"] isEqual:@YES];
        owner->_enabledSamples=enabled?owner->_enabledSamples+1:0;
        if(owner->_enabledSamples>=2 || NSProcessInfo.processInfo.systemUptime>=owner->_enablementDeadline) {
            owner->_output=[owner->_output stringByAppendingFormat:@"\nInput source verification: %@\n",state?:@{}];
            [owner finishEnablement:owner->_enabledSamples>=2];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                CassotisInstallerController *current=weakSelf;
                if(current && current->_enabling && generation==current->_enablementGeneration) [current pollEnablement:generation];
            });
        }
    }];
}
- (void)beginEnablement {
    if(_working || _enabling) return;
    _enabling=YES; _inputSourceEnabled=NO; _enabledSamples=0; ++_enablementGeneration;
    _heading.stringValue=@"正在启用…";
    _message.stringValue=@"正在将言泉输入法添加到系统输入菜单。";
    _steps.stringValue=@"如果 macOS 弹出确认，请允许使用言泉输入法。\n\n正在等待系统确认，完成后即可从菜单栏选用。\n\n也可以关闭此窗口，稍后在键盘设置中启用。";
    _primary.enabled=YES; _primary.title=@"完成"; _primary.action=@selector(quit:);
    _secondary.enabled=YES; _secondary.hidden=NO; _secondary.title=@"打开键盘设置";
    _secondary.action=@selector(openSettings:); [_progress startAnimation:nil];
    _enablementDeadline=NSProcessInfo.processInfo.systemUptime+[self enablementWaitLimit];
    OSStatus status=[self requestInputSourceEnablement];
    _output=[_output stringByAppendingFormat:@"\nInput source enable request: %d\n",int(status)];
    if(status!=noErr) { [self finishEnablement:NO]; return; }
    [self pollEnablement:_enablementGeneration];
}
- (void)retryEnablement:(id)sender { (void)sender; [self beginEnablement]; }
- (void)install:(id)sender { (void)sender; [self runOperation:NO]; }
- (void)retry:(id)sender { (void)sender; [self runOperation:_removing]; }
- (void)uninstall:(id)sender {
    (void)sender;
    NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"卸载言泉输入法？";
    alert.informativeText=@"请先在“系统设置 → 键盘 → 文字输入 → 编辑”中移除言泉输入法，再进行卸载。设置和学习记录会保留。";
    [alert addButtonWithTitle:@"取消"]; [alert addButtonWithTitle:@"打开键盘设置"]; [alert addButtonWithTitle:@"卸载"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response==NSAlertSecondButtonReturn) [self openSettings:nil];
        if(response==NSAlertThirdButtonReturn) [self runOperation:YES];
    }];
}
@end
