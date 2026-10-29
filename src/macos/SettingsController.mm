#import "SettingsController.h"
#import "ProductName.h"
#import "InputSession.h"
#import "CandidateAppearance.h"
#import "ShortcutRecorder.h"
#import "RuntimeLog.h"
#import "CustomPhraseEditor.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface CassotisSettingsDocument : NSView
@end
@implementation CassotisSettingsDocument
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)rect { [NSColor.windowBackgroundColor setFill]; NSRectFill(rect); }
@end

@interface CassotisWebsiteButton : NSButton
@end
@implementation CassotisWebsiteButton
- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}
@end

// IMK has no Edit menu; retain normal editing shortcuts in settings fields.
static BOOL CassotisSettingsFieldKey(NSControl *control,NSEvent *event) {
    NSTextView *editor=(NSTextView *)control.currentEditor;
    NSUInteger flags=event.modifierFlags&(NSEventModifierFlagCommand|NSEventModifierFlagControl|
        NSEventModifierFlagOption|NSEventModifierFlagShift);
    if([editor isKindOfClass:NSTextView.class] && control.window.firstResponder==editor &&
       (flags==NSEventModifierFlagCommand || flags==(NSEventModifierFlagCommand|NSEventModifierFlagShift))) {
        NSString *key=event.charactersIgnoringModifiers.lowercaseString;
        if([key isEqual:@"z"]) {
            if(flags&NSEventModifierFlagShift) { if(editor.undoManager.canRedo) [editor.undoManager redo]; }
            else if(editor.undoManager.canUndo) [editor.undoManager undo];
            return YES;
        }
        if(flags==NSEventModifierFlagCommand) {
            if([key isEqual:@"a"]) { [editor selectAll:control]; return YES; }
            if([key isEqual:@"c"]) { [editor copy:control]; return YES; }
            if([key isEqual:@"x"]) { [editor cut:control]; return YES; }
            if([key isEqual:@"v"]) { [editor paste:control]; return YES; }
        }
    }
    return NO;
}
@interface CassotisFontComboBox : NSComboBox
@end
@implementation CassotisFontComboBox
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return CassotisSettingsFieldKey(self,event) || [super performKeyEquivalent:event];
}
@end
@interface CassotisSettingsTextField : NSTextField
@end
@implementation CassotisSettingsTextField
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return CassotisSettingsFieldKey(self,event) || [super performKeyEquivalent:event];
}
@end

@interface CassotisSettingsController () <NSTableViewDataSource,NSTableViewDelegate,NSWindowDelegate,NSComboBoxDelegate,NSComboBoxDataSource>
@end
@implementation CassotisSettingsController {
    NSPopUpButton *_scheme, *_dictionary, *_pageKeys, *_completionKey, *_pageSize, *_theme, *_punctuationPreset;
    NSSlider *_fontSize;
    NSTextField *_fontSizeLabel, *_status, *_punctuationSymbols;
    NSButton *_fullWidth, *_punctuation, *_decimalPeriod, *_fuzzy, *_retry, *_resetAppearance, *_logging, *_debugMode, *_expandCandidates, *_rememberMode, *_autoEnglish;
    NSButton *_importWords, *_clearLearning, *_modeHint;
    BOOL _importing;
    NSComboBox *_fontFamily;
    NSArray<NSString *> *_fontFamilies;
    NSMutableArray<NSButton *> *_rules, *_shortcutEnabled;
    NSMutableArray<CassotisShortcutRecorder *> *_shortcuts;
    NSScrollView *_scroll;
    NSTableView *_navigation;
    NSMutableArray<NSView *> *_sections;
    NSView *_preview;
    NSLayoutConstraint *_previewHeight, *_endPadding;
    NSArray<NSString *> *_sectionNames;
    BOOL _loading, _ready, _saving, _navigating, _fontPopupOpen, _fontPicked;
    NSTimer *_loadTimer;
    NSUInteger _loadAttempts;
    cassotis::State _state;
    CassotisCustomPhraseEditor *_customPhrases;
}
+ (instancetype)shared { static CassotisSettingsController *v; static dispatch_once_t once; dispatch_once(&once,^{v=[[self alloc] init];}); return v; }
- (NSPopUpButton *)popup:(NSArray<NSString *> *)titles identifier:(NSString *)identifier {
    NSPopUpButton *p=[[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [p addItemsWithTitles:titles]; p.target=self; p.action=@selector(changed:); p.accessibilityIdentifier=identifier;
    [p.widthAnchor constraintEqualToConstant:220].active=YES;
    return p;
}
- (NSButton *)check:(NSString *)title identifier:(NSString *)identifier {
    NSButton *b=[NSButton checkboxWithTitle:title target:self action:@selector(changed:)]; b.accessibilityIdentifier=identifier; return b;
}
- (NSTextField *)hint:(NSString *)text {
    NSTextField *label=[NSTextField wrappingLabelWithString:text];
    label.font=[NSFont systemFontOfSize:12]; label.textColor=NSColor.secondaryLabelColor; return label;
}
- (NSView *)row:(NSString *)title control:(NSView *)control {
    NSView *row=[[NSView alloc] init]; NSTextField *label=[NSTextField labelWithString:title];
    label.font=[NSFont systemFontOfSize:13]; control.accessibilityLabel=title;
    [row addSubview:label]; [row addSubview:control];
    label.translatesAutoresizingMaskIntoConstraints=NO; control.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[[label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:control.leadingAnchor constant:-12],
        [control.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintGreaterThanOrEqualToAnchor:control.heightAnchor constant:12],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:38]]];
    return row;
}
- (NSView *)card:(NSArray<NSView *> *)views {
    NSBox *box=[[NSBox alloc] init]; box.boxType=NSBoxCustom; box.titlePosition=NSNoTitle;
    box.fillColor=NSColor.controlBackgroundColor; box.borderColor=NSColor.separatorColor;
    box.cornerRadius=10; box.borderWidth=0.5; box.contentViewMargins=NSZeroSize;
    NSStackView *stack=[NSStackView stackViewWithViews:views]; stack.orientation=NSUserInterfaceLayoutOrientationVertical;
    stack.alignment=NSLayoutAttributeLeading; stack.spacing=8;
    [box.contentView addSubview:stack]; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:box.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:box.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:box.contentView.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:box.contentView.bottomAnchor constant:-12]]];
    for(NSView *view in views) [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
    return box;
}
- (NSView *)section:(NSString *)title views:(NSArray<NSView *> *)views {
    NSTextField *heading=[NSTextField labelWithString:title]; heading.font=[NSFont systemFontOfSize:23 weight:NSFontWeightBold];
    NSMutableArray *items=[NSMutableArray arrayWithObject:heading]; [items addObjectsFromArray:views];
    NSStackView *section=[NSStackView stackViewWithViews:items]; section.orientation=NSUserInterfaceLayoutOrientationVertical;
    section.alignment=NSLayoutAttributeLeading; section.spacing=16;
    for(NSView *view in items) [view.widthAnchor constraintEqualToAnchor:section.widthAnchor].active=YES;
    section.accessibilityIdentifier=[NSString stringWithFormat:@"settings-section-%lu",(unsigned long)_sections.count];
    [_sections addObject:section]; return section;
}
- (instancetype)init {
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,660)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self=[super initWithWindow:window]; if(!self) return nil;
    NSString *version=CassotisDisplayVersion();
    window.title=version.length?[NSString stringWithFormat:@"%@ (v%@) - 设置",CassotisProductName(),version]:[CassotisProductName() stringByAppendingString:@" - 设置"];
    window.minSize=NSMakeSize(760,540); window.releasedWhenClosed=NO; window.delegate=self;
    window.autorecalculatesKeyViewLoop=YES; [window center];
    _sections=[NSMutableArray array]; _sectionNames=@[@"常规",@"外观",@"模糊拼音",@"快捷键",@"自定义短语",@"高级"];
    NSView *root=[[CassotisSettingsDocument alloc] init]; window.contentView=root;
    NSVisualEffectView *sidebar=[[NSVisualEffectView alloc] init]; sidebar.material=NSVisualEffectMaterialSidebar;
    sidebar.blendingMode=NSVisualEffectBlendingModeBehindWindow; sidebar.state=NSVisualEffectStateFollowsWindowActiveState;
    NSScrollView *navigationScroll=[[NSScrollView alloc] init]; navigationScroll.drawsBackground=NO;
    _navigation=[[NSTableView alloc] init]; _navigation.headerView=nil; _navigation.rowHeight=36;
    _navigation.backgroundColor=NSColor.clearColor; _navigation.selectionHighlightStyle=NSTableViewSelectionHighlightStyleSourceList;
    _navigation.style=NSTableViewStyleSourceList; _navigation.allowsEmptySelection=NO;
    _navigation.delegate=self; _navigation.dataSource=self; _navigation.accessibilityIdentifier=@"settings-navigation";
    _navigation.columnAutoresizingStyle=NSTableViewLastColumnOnlyAutoresizingStyle;
    NSTableColumn *column=[[NSTableColumn alloc] initWithIdentifier:@"section"]; column.minWidth=100; column.width=130;
    [_navigation addTableColumn:column]; navigationScroll.documentView=_navigation;
    NSTextField *brand=[NSTextField labelWithString:CassotisShortName()]; brand.font=[NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    NSButton *website=[[CassotisWebsiteButton alloc] initWithFrame:NSZeroRect];
    website.title=[CassotisWebsiteURL().host stringByAppendingString:CassotisWebsiteURL().path];
    website.target=self; website.action=@selector(openWebsite:);
    website.bordered=NO; website.alignment=NSTextAlignmentLeft;
    website.font=[NSFont systemFontOfSize:12]; website.toolTip=CassotisWebsiteURL().absoluteString;
    website.attributedTitle=[[NSAttributedString alloc] initWithString:website.title
        attributes:@{NSFontAttributeName:website.font, NSForegroundColorAttributeName:NSColor.linkColor,
            NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)}];
    website.accessibilityIdentifier=@"settings-website"; website.accessibilityLabel=@"言泉输入法官网";
    website.accessibilityRole=NSAccessibilityLinkRole; website.accessibilityURL=CassotisWebsiteURL();
    website.accessibilityHelp=CassotisWebsiteURL().absoluteString;
    [root addSubview:sidebar]; [sidebar addSubview:brand]; [sidebar addSubview:navigationScroll]; [sidebar addSubview:website];
    _scroll=[[NSScrollView alloc] init]; _scroll.hasVerticalScroller=YES; _scroll.autohidesScrollers=YES;
    _scroll.drawsBackground=NO; _scroll.accessibilityIdentifier=@"settings-scroll";
    CassotisSettingsDocument *document=[[CassotisSettingsDocument alloc] init]; document.translatesAutoresizingMaskIntoConstraints=NO;
    _scroll.documentView=document; [root addSubview:_scroll];
    _status=[self hint:@"所有词库学习和模型推理均在本机进行。"];
    _status.accessibilityIdentifier=@"settings-status";
    _retry=[NSButton buttonWithTitle:@"重试" target:self action:@selector(retry:)];
    _retry.bezelStyle=NSBezelStyleRounded; _retry.accessibilityIdentifier=@"settings-retry";
    NSButton *close=[NSButton buttonWithTitle:@"关闭" target:window action:@selector(performClose:)];
    NSView *footer=[[NSView alloc] init]; [root addSubview:footer];
    [footer addSubview:_status]; [footer addSubview:_retry]; [footer addSubview:close];
    for(NSView *v in @[sidebar,brand,navigationScroll,website,_scroll,footer,_status,_retry,close]) v.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[[sidebar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:172], [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [brand.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:20],
        [brand.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:24],
        [navigationScroll.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:8],
        [navigationScroll.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-8],
        [navigationScroll.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:20],
        [navigationScroll.bottomAnchor constraintEqualToAnchor:website.topAnchor constant:-16],
        [website.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
        [website.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:-20],
        [website.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor constant:-20],
        [_scroll.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor], [_scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [_scroll.topAnchor constraintEqualToAnchor:root.topAnchor], [_scroll.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor], [footer.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:root.bottomAnchor], [footer.heightAnchor constraintEqualToConstant:64],
        [close.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-24],
        [_retry.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-8], [_retry.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [_retry.widthAnchor constraintEqualToConstant:76],
        [close.widthAnchor constraintEqualToConstant:76],
        [close.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [_status.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:24],
        [_status.trailingAnchor constraintEqualToAnchor:_retry.leadingAnchor constant:-12], [_status.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [document.widthAnchor constraintEqualToAnchor:_scroll.contentView.widthAnchor]]];

    _scheme=[self popup:@[@"全拼",@"微软双拼",@"小鹤双拼",@"自然码双拼",@"搜狗双拼",@"紫光双拼",@"拼音加加"] identifier:@"pinyin-scheme"];
    _dictionary=[self popup:@[@"简体中文",@"繁體中文"] identifier:@"dictionary"];
    _fullWidth=[self check:@"使用全角输入" identifier:@"full-width"];
    _punctuation=[self check:@"使用中文标点" identifier:@"chinese-punctuation"];
    _decimalPeriod=[self check:@"连续输入数字后，句号使用小数点" identifier:@"decimal-period-after-digit"];
    _autoEnglish=[self check:@"识别英文单词，空格上屏" identifier:@"auto-english"];
    _autoEnglish.toolTip=@"中文全拼、半角输入时生效；保留大小写，中文候选编号不变。";
    _punctuationSymbols=[[CassotisSettingsTextField alloc] init]; _punctuationSymbols.delegate=self;
    _punctuationSymbols.accessibilityIdentifier=@"punctuation-ascii-symbols";
    _punctuationSymbols.placeholderString=@"留空使用标准中文标点";
    [_punctuationSymbols.widthAnchor constraintEqualToConstant:240].active=YES;
    _punctuationSymbols.target=self; _punctuationSymbols.action=@selector(punctuationCommitted:);
    _punctuationPreset=[self popup:@[@"Markdown 预设",@"标准中文标点",@"自定义"] identifier:@"punctuation-preset"];
    _punctuationPreset.action=@selector(punctuationPresetChanged:);
    // A frontend preference, not engine state: it gates behaviour that lives
    // entirely in the input method process, so it stays editable when the
    // engine is unavailable and is never sent over IPC.
    _rememberMode=[self check:@"按应用记住中英文状态" identifier:@"remember-input-mode"];
    _rememberMode.action=@selector(rememberModeChanged:);
    [self section:@"常规" views:@[[self card:@[[self row:@"语言" control:_dictionary],[self row:@"拼音方案" control:_scheme],_autoEnglish,_fullWidth,_rememberMode]],
        [self card:@[_punctuation,_decimalPeriod,[self row:@"保持半角的符号" control:_punctuationSymbols],[self row:@"标点预设" control:_punctuationPreset]]],
        [self hint:@"按 Space 或数字键选词，Enter 提交拼音原文，Esc 取消输入。单独按下并释放 Shift 切换中英文；开启「按应用记住中英文状态」后，每个应用各自保留上次的选择。"]]];

    _theme=[self popup:CassotisCandidateThemeNames() identifier:@"candidate-theme"];
    _theme.action=@selector(appearanceChanged:);
    _pageSize=[self popup:@[@"3 项",@"4 项",@"5 项",@"6 项",@"7 项",@"8 项",@"9 项"] identifier:@"candidate-page-size"];
    _expandCandidates=[self check:@"翻页时展开为三行候选" identifier:@"candidate-expand-on-paging"];
    _modeHint=[self check:@"在光标旁提示中英文状态" identifier:@"input-mode-hint"];
    _modeHint.action=@selector(modeHintChanged:);
    _fontFamilies=[NSFontManager.sharedFontManager.availableFontFamilies sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    _fontFamily=[[CassotisFontComboBox alloc] init]; _fontFamily.usesDataSource=YES; _fontFamily.dataSource=self; _fontFamily.completes=YES;
    [_fontFamily.widthAnchor constraintEqualToConstant:220].active=YES;
    _fontFamily.delegate=self; _fontFamily.accessibilityIdentifier=@"candidate-font-family";
    _fontFamily.target=self; _fontFamily.action=@selector(fontCommitted:);
    _fontSize=[NSSlider sliderWithValue:1 minValue:0 maxValue:CassotisCandidateFontSizes().count-1 target:self action:@selector(appearanceChanged:)];
    _fontSize.numberOfTickMarks=CassotisCandidateFontSizes().count; _fontSize.allowsTickMarkValuesOnly=YES;
    _fontSize.continuous=YES; _fontSize.accessibilityIdentifier=@"candidate-font-size"; _fontSize.accessibilityLabel=@"候选字号";
    [_fontSize.widthAnchor constraintEqualToConstant:220].active=YES;
    _fontSizeLabel=[self hint:@"14 点（默认）"];
    NSStackView *sizeControls=[NSStackView stackViewWithViews:@[_fontSize,_fontSizeLabel]];
    sizeControls.orientation=NSUserInterfaceLayoutOrientationVertical; sizeControls.alignment=NSLayoutAttributeLeading; sizeControls.spacing=4;
    _preview=[[NSView alloc] init]; _preview.accessibilityIdentifier=@"candidate-preview";
    _previewHeight=[_preview.heightAnchor constraintEqualToConstant:90]; _previewHeight.active=YES;
    NSButton *resetAppearance=[NSButton buttonWithTitle:@"恢复默认外观" target:self action:@selector(resetAppearance:)];
    _resetAppearance=resetAppearance;
    [self section:@"外观" views:@[[self card:@[[self row:@"候选字体" control:_fontFamily],[self row:@"大小" control:sizeControls],
        [self row:@"配色" control:_theme],[self row:@"每页候选" control:_pageSize],_expandCandidates,_modeHint,
        [self hint:@"切换到言泉或切换中英文时显示当前状态；英文模式下进入输入框也会提示。"]]],
        [self hint:@"预览"],_preview,[self row:@"" control:resetAppearance]]];

    _fuzzy=[self check:@"启用模糊拼音" identifier:@"fuzzy-pinyin"]; _rules=[NSMutableArray array];
    for(NSString *rule in @[@"z / zh",@"c / ch",@"s / sh",@"l / n",@"f / h",@"r / l",@"an / ang",@"en / eng",@"in / ing",@"ian / iang",@"uan / uang"])
        [_rules addObject:[self check:rule identifier:[@"fuzzy-" stringByAppendingString:rule]]];
    NSMutableArray *ruleRows=[NSMutableArray array];
    for(NSUInteger i=0;i<_rules.count;i+=3) {
        NSMutableArray *row=[NSMutableArray array];
        for(NSUInteger j=i;j<MIN(i+3,_rules.count);++j) [row addObject:_rules[j]];
        while(row.count<3) [row addObject:NSGridCell.emptyContentView]; [ruleRows addObject:row];
    }
    NSGridView *rules=[NSGridView gridViewWithViews:ruleRows]; rules.rowSpacing=16; rules.columnSpacing=30;
    [self section:@"模糊拼音" views:@[[self card:@[_fuzzy,rules]],
        [self hint:@"选择需要互相匹配的声母或韵母。关闭模糊拼音后，已选规则会保留。"]]];

    _shortcutEnabled=[NSMutableArray array]; _shortcuts=[NSMutableArray array]; NSMutableArray *shortcutRows=[NSMutableArray array];
    NSArray *actions=@[@"中英文状态切换",@"中英文标点切换",@"简繁体切换",@"全角/半角切换",@"打开设置"];
    for(NSUInteger i=0;i<actions.count;++i) {
        NSButton *enabled=[self check:actions[i] identifier:[NSString stringWithFormat:@"shortcut-enabled-%lu",(unsigned long)i]];
        enabled.tag=i; enabled.action=@selector(shortcutEnabledChanged:); [_shortcutEnabled addObject:enabled];
        CassotisShortcutRecorder *recorder=[[CassotisShortcutRecorder alloc] init]; recorder.target=self; recorder.action=@selector(changed:);
        recorder.allowsCapsLock=i==0;
        recorder.accessibilityIdentifier=[NSString stringWithFormat:@"shortcut-%lu",(unsigned long)i]; recorder.accessibilityLabel=actions[i];
        [recorder.widthAnchor constraintEqualToConstant:220].active=YES;
        __weak CassotisSettingsController *weak=self;
        recorder.validationMessage=^(NSString *message){
            CassotisSettingsController *controller=weak;
            if(controller) controller->_status.stringValue=message;
        };
        [_shortcuts addObject:recorder];
        NSStackView *row=[NSStackView stackViewWithViews:@[enabled,recorder]];
        row.orientation=NSUserInterfaceLayoutOrientationHorizontal; row.distribution=NSStackViewDistributionFill; row.spacing=12;
        [enabled setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [shortcutRows addObject:row];
    }
    _pageKeys=[self popup:@[@"− / =",@"[ / ]",@", / .",@"Shift + Tab / Tab"] identifier:@"candidate-page-keys"];
    _completionKey=[self popup:@[@"Tab",@"反引号 `"] identifier:@"completion-key"];
    [self section:@"快捷键" views:@[[self card:shortcutRows],
        [self hint:@"点击快捷键后直接按键。按住 Ctrl、Option 或 Shift 时会立即显示；单独的 Shift 在松开时完成录制。Esc 取消。"],
        [self hint:@"中英文切换也可录制 Caps Lock。有未上屏的内容时，先提交原始字母再切换。请先在“系统设置 → 键盘 → 文字输入 → 编辑”中关闭“使用大写锁定键切换输入法”，避免切到 ABC。选择此键后，在言泉内按住 Shift 输入大写；暂不区分短按和长按。"],
        [self card:@[[self row:@"候选翻页" control:_pageKeys],[self row:@"一键补全" control:_completionKey]]],
        [self hint:@"Command、Ctrl + Space 和 Fn 系统组合键由 macOS 管理。系统输入源切换键可在“系统设置 → 键盘”中调整。"]]];

    _customPhrases=[[CassotisCustomPhraseEditor alloc] init];
    __weak CassotisSettingsController *weakController=self;
    _customPhrases.savePhrases=^BOOL(const std::vector<cassotis::CustomPhrase> &phrases) {
        CassotisSettingsController *controller=weakController;
        if(!controller || !controller->_ready) return NO;
        try {
            cassotis::EngineClient engine;
            if(!engine.connect(CassotisSocketPath().UTF8String)) throw std::runtime_error("引擎暂不可用，短语尚未保存。");
            auto state=engine.state(); state.customPhrases=phrases;
            engine.setState(state); controller->_state=state;
            controller->_status.stringValue=@"自定义短语已保存。"; return YES;
        } catch(const std::exception &e) { controller->_status.stringValue=[NSString stringWithUTF8String:e.what()]; return NO; }
    };
    [self section:@"自定义短语" views:@[[self card:@[_customPhrases]],
        [self hint:@"例如 cx → 春眠不觉晓，处处闻啼鸟。缩写不区分大小写，双拼按实际按键匹配；数字候选与空格选词保持不变。可与 Windows 版互相导入、导出。"]]];

    NSButton *logs=[NSButton buttonWithTitle:@"打开日志文件夹" target:self action:@selector(openLogs:)];
    _logging=[self check:@"启用日志" identifier:@"logging-enabled"];
    _logging.action=@selector(loggingChanged:);
    _debugMode=[self check:@"启用调试模式" identifier:@"debug-mode"];
    NSButton *config=[NSButton buttonWithTitle:@"打开配置文件夹" target:self action:@selector(openConfig:)];
    _clearLearning=[NSButton buttonWithTitle:@"清除学习记录…" target:self action:@selector(clear:)];
    _clearLearning.accessibilityIdentifier=@"clear-learning";
    _importWords=[NSButton buttonWithTitle:@"导入输入频次…" target:self action:@selector(importWords:)];
    _importWords.accessibilityIdentifier=@"import-word-frequencies";
    [self section:@"高级" views:@[[self card:@[_logging,
        [self hint:@"默认关闭。开启后记录启动和运行诊断，开关立即生效并自动保存，不中断输入。关闭后停止写入，已有日志保留。每份日志最多 2 MB，保留上一份记录。"],
        [self row:@"运行日志" control:logs]]],
        [self card:@[_debugMode,[self hint:@"在候选栏右下角显示参与排序的上文及其来源。默认关闭，用于排查选词问题；此开关不启用日志。"]]],
        [self card:@[[self row:@"配置工具" control:config],[self row:@"导入选词习惯" control:_importWords],[self row:@"用户词语与学习" control:_clearLearning]]],
        [self hint:@"所有词库学习和模型推理均在本机进行。可以导入其他输入法导出的词语和使用次数。清除学习记录会同时删除导入的频次，不会更改设置、自定义短语或基础词库。"]]];

    NSView *padding=[[NSView alloc] init]; _endPadding=[padding.heightAnchor constraintEqualToConstant:300]; _endPadding.active=YES;
    NSMutableArray *contents=[_sections mutableCopy]; [contents addObject:padding];
    NSStackView *stack=[NSStackView stackViewWithViews:contents]; stack.orientation=NSUserInterfaceLayoutOrientationVertical;
    stack.alignment=NSLayoutAttributeLeading; stack.spacing=36; [document addSubview:stack]; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-24]]];
    for(NSView *section in contents) [section.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(textEditing:) name:NSControlTextDidBeginEditingNotification object:nil];
    _scroll.contentView.postsBoundsChangedNotifications=YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(scrolled:) name:NSViewBoundsDidChangeNotification object:_scroll.contentView];
    [_navigation selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    return self;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { (void)tableView; return _sectionNames.count; }
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView; (void)column;
    NSTableCellView *cell=[[NSTableCellView alloc] init];
    NSTextField *label=[NSTextField labelWithString:_sectionNames[row]]; label.font=[NSFont systemFontOfSize:13];
    NSArray *symbols=@[@"keyboard",@"paintpalette",@"character.textbox",@"command",@"doc.text",@"slider.horizontal.3"];
    NSImageView *icon=[NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbols[row] accessibilityDescription:nil]];
    cell.textField=label; cell.imageView=icon; [cell addSubview:icon]; [cell addSubview:label];
    icon.translatesAutoresizingMaskIntoConstraints=NO; label.translatesAutoresizingMaskIntoConstraints=NO;
    [NSLayoutConstraint activateConstraints:@[[icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4],
        [icon.widthAnchor constraintEqualToConstant:18],[icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],[label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:cell.trailingAnchor constant:-4]]];
    return cell;
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    if(_navigating || _navigation.selectedRow<0 || _navigation.selectedRow>=(NSInteger)_sections.count) return;
    [self.window.contentView layoutSubtreeIfNeeded];
    NSView *section=_sections[_navigation.selectedRow]; NSRect rect=[section convertRect:section.bounds toView:_scroll.documentView];
    _navigating=YES;
    [_scroll.contentView scrollToPoint:NSMakePoint(0,MAX(0,rect.origin.y-24))]; [_scroll reflectScrolledClipView:_scroll.contentView];
    _navigating=NO;
}
- (void)scrolled:(NSNotification *)notification {
    (void)notification; if(_navigating || !_sections.count) return;
    CGFloat top=_scroll.contentView.bounds.origin.y+32; NSInteger selected=0;
    for(NSUInteger i=0;i<_sections.count;++i) {
        NSView *section=_sections[i];
        if([section convertRect:section.bounds toView:_scroll.documentView].origin.y<=top) selected=i;
    }
    _navigating=YES; [_navigation selectRowIndexes:[NSIndexSet indexSetWithIndex:selected] byExtendingSelection:NO]; _navigating=NO;
}
- (void)windowDidResize:(NSNotification *)notification {
    (void)notification; [self updatePreview];
    [self.window.contentView layoutSubtreeIfNeeded];
    [_navigation sizeLastColumnToFit];
    _endPadding.constant=MAX(0,_scroll.contentView.bounds.size.height-_sections.lastObject.frame.size.height-48);
}
- (void)textEditing:(NSNotification *)notification {
    NSControl *control=notification.object;
    if(control.window!=self.window) return;
    NSText *editor=[control currentEditor];
    if([editor isKindOfClass:NSTextView.class])
        ((NSTextView *)editor).inputContext.allowedInputSourceLocales=@[NSAllRomanInputSourcesLocaleIdentifier];
}
- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox { (void)comboBox; return _fontFamilies.count; }
- (id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index { (void)comboBox; return _fontFamilies[index]; }
- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    (void)comboBox;
    NSUInteger exact=[_fontFamilies indexOfObjectPassingTest:^BOOL(NSString *name,NSUInteger index,BOOL *stop) {
        (void)index; (void)stop; return [name caseInsensitiveCompare:string]==NSOrderedSame;
    }];
    if(exact!=NSNotFound || !string.length) return exact;
    return [_fontFamilies indexOfObjectPassingTest:^BOOL(NSString *name,NSUInteger index,BOOL *stop) {
        (void)index; (void)stop; return [name rangeOfString:string options:NSCaseInsensitiveSearch|NSAnchoredSearch].location==0;
    }];
}
- (NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
    NSUInteger index=[self comboBox:comboBox indexOfItemWithStringValue:string];
    return index==NSNotFound?nil:_fontFamilies[index];
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if(notification.object!=_fontFamily || _loading) return;
    NSUInteger index=[self comboBox:_fontFamily indexOfItemWithStringValue:_fontFamily.stringValue];
    if(index!=NSNotFound) [_fontFamily scrollItemAtIndexToVisible:index];
    [self updatePreview];
}
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if(notification.object==_fontFamily) [self fontCommitted:nil];
    else if(notification.object==_punctuationSymbols) [self punctuationCommitted:nil];
}
- (void)updatePunctuationControls {
    BOOL enabled=_ready && _punctuation.state!=0 && _fullWidth.state==0;
    _punctuationSymbols.enabled=enabled; _punctuationPreset.enabled=enabled;
    [_punctuationPreset selectItemAtIndex:_state.punctuationASCII.empty()?1:
        _state.punctuationASCII==cassotis::State{}.punctuationASCII?0:2];
}
- (void)punctuationCommitted:(id)sender {
    (void)sender; if(_loading || !_ready || _saving) return;
    if(_punctuationSymbols.enabled) {
        std::string draft=_punctuationSymbols.stringValue.UTF8String?:"";
        auto normalized=cassotis::normalizePunctuationASCII(draft);
        for(unsigned char c:draft) if(c>32 && normalized.find(c)==std::string::npos) {
            _punctuationSymbols.stringValue=[NSString stringWithUTF8String:_state.punctuationASCII.c_str()];
            _status.stringValue=@"请输入半角标点符号；未保存的内容已恢复。";
            [self updatePunctuationControls]; return;
        }
        _state.punctuationASCII=normalized;
        _punctuationSymbols.stringValue=[NSString stringWithUTF8String:_state.punctuationASCII.c_str()];
        [self changed:nil];
    } else _punctuationSymbols.stringValue=[NSString stringWithUTF8String:_state.punctuationASCII.c_str()];
    [self updatePunctuationControls];
}
- (void)punctuationPresetChanged:(id)sender {
    (void)sender; if(_loading || !_ready || _saving || !_punctuationPreset.enabled) return;
    NSInteger index=_punctuationPreset.indexOfSelectedItem;
    if(index==2) { [self.window makeFirstResponder:_punctuationSymbols]; return; }
    _punctuationSymbols.stringValue=index==0?[NSString stringWithUTF8String:cassotis::State{}.punctuationASCII.c_str()]:@"";
    [self punctuationCommitted:nil];
}
- (void)comboBoxWillPopUp:(NSNotification *)notification { (void)notification; _fontPopupOpen=YES; _fontPicked=NO; }
- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    if(_fontPopupOpen && !_loading) _fontPicked=YES;
}
- (void)comboBoxWillDismiss:(NSNotification *)notification {
    (void)notification; _fontPopupOpen=NO;
    if(_fontPicked && !_loading) {
        NSInteger index=_fontFamily.indexOfSelectedItem;
        if(index>=0 && index<(NSInteger)_fontFamilies.count) _fontFamily.stringValue=_fontFamilies[index];
        [self fontCommitted:nil];
    }
    _fontPicked=NO;
}
- (void)fontCommitted:(id)sender {
    (void)sender; if(_loading || !_ready || _saving) return;
    NSString *value=[_fontFamily.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger index=[_fontFamilies indexOfObjectPassingTest:^BOOL(NSString *name,NSUInteger i,BOOL *stop) {
        (void)i; (void)stop; return [name caseInsensitiveCompare:value]==NSOrderedSame;
    }];
    _fontFamily.stringValue=index==NSNotFound?@"PingFang SC":_fontFamilies[index];
    [self appearanceChanged:_fontFamily];
}
- (void)changed:(id)sender {
    (void)sender; if(_loading || !_ready || _saving) return;
    for(NSButton *rule in _rules) rule.enabled=_fuzzy.state==NSControlStateValueOn;
    _decimalPeriod.enabled=_punctuation.state==NSControlStateValueOn;
    [self updatePunctuationControls];
    _saving=YES;
    if(![self persistSettings]) {
        NSString *error=_status.stringValue;
        [self reloadSettings]; _status.stringValue=error;
    }
    _saving=NO;
}
- (void)rememberModeChanged:(NSButton *)sender {
    if(_loading) return;
    CassotisSetRememberInputModeEnabled(sender.state==NSControlStateValueOn);
    _status.stringValue=sender.state==NSControlStateValueOn
        ?@"已保存：各应用分别记住上次的中英文状态。"
        :@"已保存：中英文状态在全部应用间保持统一。";
}
- (void)loggingChanged:(NSButton *)sender {
    if(_loading) return;
    CassotisRuntimeLog.shared.enabled=sender.state==NSControlStateValueOn;
    if(CassotisRuntimeLog.shared.enabled)
        [CassotisRuntimeLog.shared appendData:[@"[INFO] runtime logging enabled\n" dataUsingEncoding:NSUTF8StringEncoding]];
    _status.stringValue=@"日志设置已自动保存并生效。";
}
- (void)modeHintChanged:(NSButton *)sender {
    if(_loading) return;
    CassotisSetInputModeHintEnabled(sender.state==NSControlStateValueOn);
    _status.stringValue=@"中英文状态提示已自动保存并生效。";
}
- (void)shortcutEnabledChanged:(NSButton *)sender { _shortcuts[sender.tag].enabled=sender.state==NSControlStateValueOn; [self changed:sender]; }
- (void)appearanceChanged:(id)sender { [self updatePreview]; [self changed:sender]; }
- (CGFloat)selectedFontSize { return CassotisCandidateFontSizes()[(NSUInteger)llround(_fontSize.doubleValue)].doubleValue; }
- (void)updatePreview {
    if(!_preview) return;
    CGFloat size=[self selectedFontSize];
    _fontSizeLabel.stringValue=[NSString stringWithFormat:@"%g 点%@",size,size==14?@"（默认）":@""];
    _fontSize.accessibilityValueDescription=_fontSizeLabel.stringValue;
    // Start with the Windows preview and extend it for every supported page
    // size. These are display samples, never learned/removable user words.
    cassotis::Result result; result.preedit="luoxiayu"; result.selected=0; result.pages=1;
    const char *samples[]={"落霞","落下","落","洛","罗","络","骆","珞","螺"};
    NSInteger count=MIN(9,MAX(3,_pageSize.indexOfSelectedItem+3));
    for(NSInteger i=0;i<count;++i) result.candidates.push_back({samples[i],"",0,0,false});
    if(_expandCandidates.state) {
        result.pages=3; result.page=1;
        const char *extra[][9]={{"罗夏","洛下","落花","落雪","落日","落叶","落笔","落定","落幕"},
                              {"落座","落地","落款","落脚","落成","落户","落实","落伍","落单"}};
        for(int row=0;row<3;++row) {
            cassotis::CandidatePage page; page.page=row;
            if(row==1) page.candidates=result.candidates;
            else for(NSInteger i=0;i<count;++i) page.candidates.push_back({extra[row/2][i],"",0,0,false});
            result.candidatePages.push_back(page);
        }
    }
    result.completion="落霞与孤鹜齐飞";
    result.completionSource=cassotis::CompletionSource::BaseExact;
    CGFloat width=_preview.bounds.size.width?:500;
    NSView *content=CassotisCandidateView(result,size,_fontFamily.stringValue,_theme.indexOfSelectedItem,
        width,self.window.effectiveAppearance,nil,nullptr,nullptr,0,(uint8_t)_completionKey.indexOfSelectedItem);
    for(NSView *view in [_preview.subviews copy]) [view removeFromSuperview];
    [_preview addSubview:content];
    NSSize fitting=content.fittingSize; _previewHeight.constant=fitting.height;
    [content setFrame:NSMakeRect(0,0,MIN(width,fitting.width),fitting.height)];
}
- (void)resetAppearance:(id)sender {
    (void)sender; _fontSize.doubleValue=1; _fontFamily.stringValue=@"PingFang SC";
    _modeHint.state=NSControlStateValueOn; CassotisSetInputModeHintEnabled(YES);
    [_theme selectItemAtIndex:0]; [_pageSize selectItemAtIndex:6]; _expandCandidates.state=0; [self appearanceChanged:nil];
}
- (void)reloadSettings {
    _loading=YES; _ready=NO; CassotisStartEngine(); cassotis::EngineClient engine;
    _rememberMode.state=CassotisRememberInputModeEnabled()?NSControlStateValueOn:NSControlStateValueOff;
    _modeHint.state=CassotisInputModeHintEnabled()?NSControlStateValueOn:NSControlStateValueOff;
    try {
        if(!engine.connect(CassotisSocketPath().UTF8String)) throw std::runtime_error("正在读取设置，请稍候…");
        _state=engine.state(); _ready=YES;
        [_customPhrases setPhrases:_state.customPhrases];
        _autoEnglish.state=_state.autoEnglish?NSControlStateValueOn:NSControlStateValueOff;
        _punctuationSymbols.stringValue=[NSString stringWithUTF8String:_state.punctuationASCII.c_str()];
        [_scheme selectItemAtIndex:_state.scheme]; [_dictionary selectItemAtIndex:_state.dictionary];
        [_pageKeys selectItemAtIndex:_state.pageKeys]; [_completionKey selectItemAtIndex:_state.completionKey];
        [_pageSize selectItemAtIndex:_state.pageSize-3]; _fullWidth.state=(_state.flags&1)?1:0;
        _expandCandidates.state=(_state.flags&16)?1:0;
        _debugMode.state=(_state.flags&8)?1:0;
        _punctuation.state=(_state.flags&2)?1:0; _decimalPeriod.state=(_state.flags&32)?1:0; _fuzzy.state=(_state.flags&4)?1:0;
        for(NSUInteger i=0;i<_rules.count;++i) { _rules[i].state=(_state.fuzzy&(1<<i))?1:0; _rules[i].enabled=_fuzzy.state!=0; }
        for(int i=0;i<5;++i) {
            _shortcutEnabled[i].state=_state.shortcuts[i].disabled?0:1;
            _shortcuts[i].shortcut=_state.shortcuts[i]; _shortcuts[i].enabled=!_state.shortcuts[i].disabled;
        }
        _status.stringValue=@"所有词库学习和模型推理均在本机进行。";
    } catch(const std::exception &e) { _status.stringValue=[NSString stringWithUTF8String:e.what()]; }
    NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
    _logging.state=CassotisRuntimeLog.shared.enabled?NSControlStateValueOn:NSControlStateValueOff;
    [_theme selectItemAtIndex:CassotisCandidateTheme(defaults)];
    _fontFamily.stringValue=[defaults stringForKey:@"CandidateFontFamily"]?:@"PingFang SC";
    CGFloat size=CassotisCandidateFontSize(defaults),distance=100; NSUInteger best=1;
    for(NSUInteger i=0;i<CassotisCandidateFontSizes().count;++i) {
        CGFloat delta=fabs(CassotisCandidateFontSizes()[i].doubleValue-size);
        if(delta<distance) { distance=delta; best=i; }
    }
    _fontSize.doubleValue=best; _loading=NO;
    // Do not present placeholder engine state as editable user preferences.
    for(NSControl *control in @[_scheme,_dictionary,_pageKeys,_completionKey,_pageSize,_theme,_fontSize,
        _fontFamily,_fullWidth,_punctuation,_fuzzy,_resetAppearance,_expandCandidates,_autoEnglish,_debugMode]) control.enabled=_ready;
    _decimalPeriod.enabled=_ready && _punctuation.state!=0;
    [self updatePunctuationControls];
    for(NSButton *control in _shortcutEnabled) control.enabled=_ready;
    for(NSButton *control in _rules) control.enabled=_ready && _fuzzy.state!=0;
    for(NSUInteger i=0;i<_shortcuts.count;++i) _shortcuts[i].enabled=_ready && _shortcutEnabled[i].state!=0;
    _customPhrases.enabled=_ready;
    _importWords.enabled=_ready && !_importing;
    _clearLearning.enabled=_ready && !_importing;
    _retry.hidden=_ready; _retry.enabled=!_ready;
    [self.window.contentView layoutSubtreeIfNeeded];
    [self windowDidResize:[NSNotification notificationWithName:NSWindowDidResizeNotification object:self.window]];
}
- (void)showWindow:(id)sender {
    if(!self.window.visible || !_ready) [self reloadSettings];
    [super showWindow:sender]; [NSApp activateIgnoringOtherApps:YES]; [self.window makeKeyAndOrderFront:nil];
    if(!_ready) [self retryLoading];
}
- (void)retryLoading {
    [_loadTimer invalidate]; _loadAttempts=0;
    __weak CassotisSettingsController *weak=self;
    _loadTimer=[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        CassotisSettingsController *controller=weak;
        if(!controller || !controller.window.visible || controller->_ready) { [timer invalidate]; return; }
        [controller reloadSettings];
        if(controller->_ready) [timer invalidate];
        else if(++controller->_loadAttempts>=20) {
            [timer invalidate]; controller->_status.stringValue=@"暂时无法读取设置，请点击“重试”。";
        }
    }];
}
- (BOOL)persistSettings {
    if(!_ready) { _status.stringValue=@"引擎暂不可用，请重新打开设置后重试。"; return NO; }
    auto state=_state;
    state.autoEnglish=_autoEnglish.state!=0;
    state.scheme=(uint8_t)_scheme.indexOfSelectedItem; state.dictionary=(uint8_t)_dictionary.indexOfSelectedItem;
    state.pageKeys=(uint8_t)_pageKeys.indexOfSelectedItem; state.completionKey=(uint8_t)_completionKey.indexOfSelectedItem;
    state.pageSize=(uint8_t)(_pageSize.indexOfSelectedItem+3);
    state.flags=(_fullWidth.state?1:0)|(_punctuation.state?2:0)|(_fuzzy.state?4:0)|(_debugMode.state?8:0)|(_expandCandidates.state?16:0)|(_decimalPeriod.state?32:0); state.fuzzy=0;
    for(NSUInteger i=0;i<_rules.count;++i) if(_rules[i].state) state.fuzzy|=1<<i;
    for(int i=0;i<5;++i) {
        if(_shortcuts[i].recording) { _status.stringValue=@"请先完成快捷键录制，或按 Esc 取消。"; return NO; }
        state.shortcuts[i]=_shortcuts[i].shortcut; state.shortcuts[i].disabled=!_shortcutEnabled[i].state;
        NSString *error=CassotisShortcutValidationError(state.shortcuts[i]);
        if(i!=0 && state.shortcuts[i].key==20) error=@"Caps Lock 只能用于中英文状态切换。";
        if(error) { _status.stringValue=error; return NO; }
        for(int j=0;j<i;++j) if(!state.shortcuts[i].disabled && !state.shortcuts[j].disabled &&
            state.shortcuts[i].key==state.shortcuts[j].key && state.shortcuts[i].modifiers==state.shortcuts[j].modifiers) {
            _status.stringValue=[NSString stringWithFormat:@"“%@”和“%@”的快捷键重复，请重新录制。",_shortcutEnabled[j].title,_shortcutEnabled[i].title]; return NO;
        }
    }
    if(state.pageKeys==3 && state.completionKey==0) { _status.stringValue=@"Tab 翻页与 Tab 补全冲突，请更换其中一项。"; return NO; }
    if(!_fontFamily.stringValue.length || ![NSFontManager.sharedFontManager fontWithFamily:_fontFamily.stringValue traits:0 weight:5 size:14])
        _fontFamily.stringValue=@"PingFang SC";
    try {
        cassotis::EngineClient engine;
        if(!engine.connect(CassotisSocketPath().UTF8String)) throw std::runtime_error("引擎暂不可用，设置尚未保存。");
        engine.setState(state); _state=state;
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        [defaults setInteger:_theme.indexOfSelectedItem forKey:@"CandidateTheme"];
        [defaults setDouble:[self selectedFontSize] forKey:@"CandidateFontSize"];
        [defaults setObject:_fontFamily.stringValue forKey:@"CandidateFontFamily"];
        _status.stringValue=@"设置已自动保存。"; [self updatePreview]; return YES;
    } catch(const std::exception &e) { _status.stringValue=[NSString stringWithUTF8String:e.what()]; return NO; }
}
- (void)retry:(id)sender {
    (void)sender;
    if(!_ready) { [self reloadSettings]; if(!_ready) [self retryLoading]; }
}
- (void)windowWillClose:(NSNotification *)notification {
    (void)notification; [_loadTimer invalidate];
    for(CassotisShortcutRecorder *recorder in _shortcuts) [recorder cancelRecording];
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
    [sender makeFirstResponder:nil]; [_customPhrases cancelDraft]; [self fontCommitted:nil]; return YES;
}
- (void)openDirectory:(NSString *)relative {
    NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:relative];
    if(![NSFileManager.defaultManager fileExistsAtPath:path]) { _status.stringValue=@"文件夹尚未创建，请先使用输入法。"; return; }
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:path isDirectory:YES]];
}
- (void)openWebsite:(id)sender { (void)sender; [NSWorkspace.sharedWorkspace openURL:CassotisWebsiteURL()]; }
- (void)openLogs:(id)sender { (void)sender; [self openDirectory:@"Library/Logs/CassotisIME"]; }
- (void)openConfig:(id)sender { (void)sender; [self openDirectory:@"Library/Application Support/CassotisIME"]; }
- (void)startWordImport:(NSURL *)url {
    if(_importing || !_ready || !url.isFileURL) return;
    _importing=YES; _importWords.enabled=NO; _clearLearning.enabled=NO;
    _status.stringValue=@"正在导入输入频次…";
    // A bulk import may take several seconds. Keep the settings window and
    // its confirmation responsive without extending normal key deadlines.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        NSString *message=nil;
        BOOL accessed=[url startAccessingSecurityScopedResource];
        try {
            cassotis::EngineClient engine;
            if(!engine.connect(CassotisSocketPath().UTF8String)) throw std::runtime_error("引擎暂不可用，请稍后重试。");
            auto result=engine.importUserWords(url.path.UTF8String);
            if(result.imported)
                message=[NSString stringWithFormat:@"已导入 %u 个词（文件中共 %u 个），并已立即生效。",result.imported,result.entries];
            else message=@"没有导入词语。请检查词语和完整拼音是否匹配。";
        } catch(const std::exception &) {
            message=@"导入未完成。请检查文件编码、格式及大小（最多 32 MB），并确认输入法服务可用。导入耗时较长时请先检查结果，避免重复导入。";
        }
        if(accessed) [url stopAccessingSecurityScopedResource];
        dispatch_async(dispatch_get_main_queue(),^{
            self->_importing=NO; self->_importWords.enabled=self->_ready; self->_clearLearning.enabled=self->_ready;
            self->_status.stringValue=message;
        });
    });
}
- (void)importWords:(id)sender {
    (void)sender; if(_importing || !_ready) return;
    NSAlert *alert=[[NSAlert alloc] init]; alert.alertStyle=NSAlertStyleWarning;
    alert.messageText=@"导入其他输入法的输入频次？";
    alert.informativeText=@"把文件里的词按使用次数记入用户词库，当作你自己的选词习惯，只影响本机。\n\n"
        @"文本文件每行一个词：词、完整拼音、次数，用逗号或 Tab 分隔，次数可以省略。例如：\n\n"
        @"知识,zhishi,120\n哪些,naxie,86\n输入法,shurufa\n\n"
        @"支持 UTF-8、带编码标记的 UTF-16 和 GBK 编码，最多 32 MB。\n\n"
        @"批量导入可能让人名、昵称、打错的词或已不用的旧词排到同音常用词前面。请先检查文件内容。\n\n"
        @"导入不能单独撤销。“清除学习记录”会将导入的频次和平时打字积累的学习记录一起删除。";
    [alert addButtonWithTitle:@"取消"]; [alert addButtonWithTitle:@"继续选择文件…"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response!=NSAlertSecondButtonReturn) return;
        NSOpenPanel *panel=NSOpenPanel.openPanel; panel.title=@"选择词频文件";
        panel.canChooseDirectories=NO; panel.allowsMultipleSelection=NO;
        panel.allowedContentTypes=@[UTTypePlainText,UTTypeCommaSeparatedText,UTTypeTabSeparatedText];
        panel.allowsOtherFileTypes=YES;
        [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse selected) {
            if(selected==NSModalResponseOK) [self startWordImport:panel.URL];
        }];
    }];
}
- (void)clear:(id)sender {
    (void)sender; if(_importing || !_ready) return; NSAlert *alert=[[NSAlert alloc] init]; alert.messageText=@"清除用户词语和学习记录？";
    alert.informativeText=@"将删除所有本地用户词语、选词习惯和补全学习记录，包括导入的输入频次，且无法撤销。基础词库、设置和自定义短语会保留。";
    [alert addButtonWithTitle:@"取消"]; [alert addButtonWithTitle:@"清除"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if(response!=NSAlertSecondButtonReturn) return;
        try { cassotis::EngineClient engine; if(!engine.connect(CassotisSocketPath().UTF8String)) throw std::runtime_error("引擎暂不可用。");
            engine.clearLearning(); self->_status.stringValue=@"学习记录已清除。";
        } catch(const std::exception &e) { self->_status.stringValue=[NSString stringWithUTF8String:e.what()]; }
    }];
}
@end
