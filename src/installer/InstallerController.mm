#import "InstallerController.h"
#import "../macos/ProductName.h"

@implementation CassotisInstallerController {
    NSURL *_payload;
    NSTextField *_heading, *_message, *_steps;
    NSButton *_primary, *_secondary, *_uninstall;
    NSProgressIndicator *_progress;
    BOOL _working, _succeeded, _removing;
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
    window.title=[NSString stringWithFormat:@"%@ (v%@) - 安装",CassotisProductName(),version];
    window.delegate=self; window.releasedWhenClosed=NO; [window center];
    NSView *root=window.contentView;
    NSImage *logo=[[NSImage alloc] initWithContentsOfURL:[payload URLByAppendingPathComponent:@"Cassotis.app/Contents/Resources/Cassotis.png"]];
    NSImageView *icon=[NSImageView imageViewWithImage:logo?:NSApp.applicationIconImage];
    icon.imageScaling=NSImageScaleProportionallyUpOrDown;
    _heading=[NSTextField labelWithString:@"安装言泉输入法"];
    _heading.font=[NSFont systemFontOfSize:26 weight:NSFontWeightSemibold];
    _heading.accessibilityIdentifier=@"installer-heading";
    NSTextField *subtitle=[NSTextField labelWithString:[NSString stringWithFormat:@"%@ · v%@",CassotisProductName(),version]];
    subtitle.textColor=NSColor.secondaryLabelColor;
    _message=[NSTextField wrappingLabelWithString:@"为中文输入而生，词库与模型全部在本机运行。"];
    _message.font=[NSFont systemFontOfSize:14]; _message.accessibilityIdentifier=@"installer-message";
    _steps=[NSTextField wrappingLabelWithString:@"全拼与六种双拼，支持简体和繁体中文。\n\n安装到当前用户，升级会保留设置和学习记录。\n\n安装完成后，在系统设置中添加言泉输入法即可使用。"];
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
    if(_working) return;
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
    } else if(ok) {
        _heading.stringValue=_removing?@"已卸载":@"安装完成";
        _message.stringValue=_removing?@"应用已移出输入法目录，设置和学习记录已保留。":@"在 macOS 中添加言泉输入法；如果已添加，直接从输入菜单选用。";
        _steps.stringValue=_removing?@"重新安装后，可继续使用原来的设置和学习记录。":
            @"1. 点击“打开键盘设置”，进入“文字输入 → 编辑”。\n\n2. 点击“+”，选择“中文（简体）→ 言泉输入法 → 添加”。\n\n3. 从菜单栏的输入菜单选择言泉输入法，彩色言泉 logo 即表示已选用。";
        _primary.title=_removing?@"完成":@"打开键盘设置";
        _primary.action=_removing?@selector(quit:):@selector(openSettings:);
        _secondary.title=@"完成"; _secondary.action=@selector(quit:);
        _secondary.hidden=_removing;
    } else {
        _heading.stringValue=_removing?@"卸载未完成":@"安装未完成";
        _message.stringValue=@"请查看安装日志中的原因，处理后重试。";
        _steps.stringValue=@"如果是磁盘空间不足，请先释放空间。若仍无法完成，可复制日志用于反馈。";
        _primary.title=@"重试"; _primary.action=@selector(retry:);
        _secondary.title=@"查看日志…"; _secondary.action=@selector(showLog:);
    }
}
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
