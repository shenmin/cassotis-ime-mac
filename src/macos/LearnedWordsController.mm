#import "LearnedWordsController.h"
#import "InputSession.h"
#import "SettingsController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// The engine owns its live SQLite connection. Exchange an atomic snapshot in
// a private directory so the table and file export use exactly the same rows.
static void withWordFile(void (^operation)(cassotis::EngineClient &, NSURL *)) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSURL *folder = [files.temporaryDirectory URLByAppendingPathComponent:NSUUID.UUID.UUIDString
                                                              isDirectory:YES];
    if (![files createDirectoryAtURL:folder
            withIntermediateDirectories:NO
                             attributes:@{
                                 NSFilePosixPermissions : @0700
                             }
                                  error:nil])
        throw std::runtime_error("temporary directory");
    try {
        cassotis::EngineClient engine;
        if (!engine.connect(CassotisSocketPath().UTF8String))
            throw std::runtime_error("engine unavailable");
        operation(engine, [folder URLByAppendingPathComponent:@"words.csv"]);
    } catch (...) {
        [files removeItemAtURL:folder error:nil];
        throw;
    }
    [files removeItemAtURL:folder error:nil];
}

static NSArray<NSArray<NSString *> *> *wordRows(void) {
    NSMutableArray *rows = [NSMutableArray array];
    withWordFile(^(cassotis::EngineClient &engine, NSURL *url) {
        uint32_t expected = engine.exportUserWords(url.path.fileSystemRepresentation);
        NSString *content = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (!content)
            throw std::runtime_error("read failed");
        [content enumerateLinesUsingBlock:^(NSString *line, BOOL *) {
            if (!line.length || [line hasPrefix:@"#"] || [line hasPrefix:@"\uFEFF#"])
                return;
            NSArray *fields = [line componentsSeparatedByString:@","];
            if (fields.count == 3)
                [rows addObject:fields];
        }];
        if (rows.count != expected)
            throw std::runtime_error("incomplete snapshot");
    });
    return rows;
}

@interface CassotisLearnedWordSearch : NSSearchField
@end
@implementation CassotisLearnedWordSearch
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    return CassotisSettingsFieldKey(self, event) || [super performKeyEquivalent:event];
}
@end

@interface CassotisLearnedWordTable : NSTableView
@property(nonatomic, weak) NSButton *deleteButton;
@end
@implementation CassotisLearnedWordTable
- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSEventModifierFlags modifiers = event.modifierFlags & (NSEventModifierFlagCommand |
        NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift);
    if (self.window.firstResponder == self && modifiers == NSEventModifierFlagCommand &&
        [event.charactersIgnoringModifiers.lowercaseString isEqualToString:@"a"]) {
        [self selectAll:self];
        return YES;
    }
    return [super performKeyEquivalent:event];
}
- (void)keyDown:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers;
    if (!(event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                                 NSEventModifierFlagOption | NSEventModifierFlagShift)) && key.length == 1) {
        unichar character = [key characterAtIndex:0];
        if (character == NSDeleteCharacter || character == NSDeleteFunctionKey) {
            [self.deleteButton performClick:self];
            return;
        }
    }
    [super keyDown:event];
}
@end

@interface CassotisLearnedWordsController () <NSTableViewDataSource, NSTableViewDelegate,
                                              NSSearchFieldDelegate>
@end
@implementation CassotisLearnedWordsController {
    NSSearchField *_search;
    NSTableView *_table;
    NSTextField *_count;
    NSButton *_deleteButton, *_done;
    NSArray<NSArray<NSString *> *> *_all, *_visible;
    BOOL _busy;
}
- (instancetype)init {
    NSWindow *window =
        [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 540, 420)
                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    self = [super initWithWindow:window];
    if (!self)
        return nil;
    window.title = @"管理已学词语";
    window.contentMinSize = NSMakeSize(400, 280);
    _search = [[CassotisLearnedWordSearch alloc] init];
    _search.placeholderString = @"搜索词语或拼音";
    _search.delegate = self;
    _search.accessibilityIdentifier = @"learned-word-search";
    _count = [NSTextField labelWithString:@""];
    _count.textColor = NSColor.secondaryLabelColor;
    _count.accessibilityIdentifier = @"learned-word-count";
    CassotisLearnedWordTable *wordTable = [[CassotisLearnedWordTable alloc] init];
    _table = wordTable;
    _table.dataSource = self;
    _table.delegate = self;
    _table.allowsMultipleSelection = YES;
    _table.usesAlternatingRowBackgroundColors = YES;
    _table.accessibilityIdentifier = @"learned-word-table";
    NSArray *titles = @[ @"词语", @"拼音", @"次数" ];
    for (NSUInteger i = 0; i < titles.count; ++i) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:[@(i) stringValue]];
        column.title = titles[i];
        column.width = i == 2 ? 65 : 195;
        [_table addTableColumn:column];
    }
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = _table;
    _deleteButton = [NSButton buttonWithTitle:@"删除所选…" target:self action:@selector(confirmDelete:)];
    wordTable.deleteButton = _deleteButton;
    _deleteButton.accessibilityIdentifier = @"learned-word-delete";
    _done = [NSButton buttonWithTitle:@"完成" target:self action:@selector(closeSheet:)];
    _done.keyEquivalent = @"\033";
    _done.accessibilityIdentifier = @"learned-word-done";
    NSView *body = window.contentView;
    for (NSView *view in @[ _search, _count, scroll, _deleteButton, _done ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [body addSubview:view];
    }
    [_search setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [NSLayoutConstraint activateConstraints:@[
        [_search.topAnchor constraintEqualToAnchor:body.topAnchor constant:16],
        [_search.leadingAnchor constraintEqualToAnchor:body.leadingAnchor constant:16],
        [_search.trailingAnchor constraintEqualToAnchor:_count.leadingAnchor constant:-12],
        [_count.centerYAnchor constraintEqualToAnchor:_search.centerYAnchor],
        [_count.trailingAnchor constraintEqualToAnchor:body.trailingAnchor constant:-16],
        [scroll.topAnchor constraintEqualToAnchor:_search.bottomAnchor constant:12],
        [scroll.leadingAnchor constraintEqualToAnchor:_search.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:_count.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:_done.topAnchor constant:-12],
        [_deleteButton.leadingAnchor constraintEqualToAnchor:_search.leadingAnchor],
        [_deleteButton.centerYAnchor constraintEqualToAnchor:_done.centerYAnchor],
        [_done.trailingAnchor constraintEqualToAnchor:_count.trailingAnchor],
        [_done.bottomAnchor constraintEqualToAnchor:body.bottomAnchor constant:-16]
    ]];
    window.initialFirstResponder = _search;
    return self;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return _visible.count;
}
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    // The user can drag columns; the exported row always has text, pinyin, count.
    NSUInteger index = column.identifier.integerValue;
    NSTextField *field = [tableView makeViewWithIdentifier:column.identifier owner:self];
    if (!field) {
        field = [NSTextField labelWithString:@""];
        field.identifier = column.identifier;
        field.lineBreakMode = NSLineBreakByTruncatingTail;
        if (index == 2)
            field.alignment = NSTextAlignmentRight;
    }
    field.stringValue = _visible[row][index];
    return field;
}
- (void)updateDeleteButton {
    _deleteButton.enabled = !_busy && _table.numberOfSelectedRows > 0;
}
- (void)tableViewSelectionDidChange:(NSNotification *)note {
    (void)note;
    [self updateDeleteButton];
}
- (void)filterRows {
    NSString *query =
        [_search.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *pinyin = [[[query
        componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" '’"]]
        componentsJoinedByString:@""] lowercaseString];
    if (!query.length)
        _visible = _all;
    else {
        _visible = [_all
            filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *) {
                NSArray<NSString *> *row = object;
                return [row[0] containsString:query] ||
                       (pinyin.length &&
                        [[row[1] stringByReplacingOccurrencesOfString:@"'" withString:@""] hasPrefix:pinyin]);
            }]];
    }
    [_table deselectAll:nil];
    [_table reloadData];
    [self updateDeleteButton];
    _count.stringValue = query.length
                             ? [NSString stringWithFormat:@"%lu / %lu 个词", _visible.count, _all.count]
                             : [NSString stringWithFormat:@"%lu 个词", _all.count];
}
- (void)controlTextDidChange:(NSNotification *)note {
    (void)note;
    if (!_busy)
        [self filterRows];
}
- (void)setBusy:(BOOL)busy {
    _busy = busy;
    _done.enabled = !busy;
    _search.enabled = !busy;
    _table.enabled = !busy;
    [self updateDeleteButton];
}
- (void)readWords {
    [self setBusy:YES];
    _count.stringValue = @"正在读取…";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *rows = nil;
        try {
            rows = wordRows();
        } catch (const std::exception &) {}
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_all = rows;
            [self setBusy:NO];
            [self filterRows];
            if (!rows)
                self->_count.stringValue = @"读取失败，请重新打开重试";
        });
    });
}
- (void)showForWindow:(NSWindow *)parent {
    if (self.window.sheetParent)
        return;
    _search.stringValue = @"";
    _all = @[];
    [self filterRows];
    [parent beginSheet:self.window
        completionHandler:^(NSModalResponse) {
            self->_all = @[];
            self->_search.stringValue = @"";
            [self filterRows];
        }];
    [self readWords];
}
- (void)closeSheet:(id)sender {
    (void)sender;
    if (!_busy)
        [self.window.sheetParent endSheet:self.window];
}
- (void)confirmDelete:(id)sender {
    (void)sender;
    if (_busy || !_table.numberOfSelectedRows)
        return;
    NSArray *selected = [_visible objectsAtIndexes:_table.selectedRowIndexes];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"删除所选的 %lu 条学习记录？", selected.count];
    alert.informativeText = @"只清除所选词语和读音的使用次数，基础词库中的同一个词仍可正常输入。";
    [alert addButtonWithTitle:@"取消"];
    [alert addButtonWithTitle:@"删除"];
    [alert beginSheetModalForWindow:self.window
                  completionHandler:^(NSModalResponse response) {
                      if (response != NSAlertSecondButtonReturn)
                          return;
                      [self setBusy:YES];
                      self->_count.stringValue = @"正在删除…";
                      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                          BOOL completed = YES;
                          try {
                              withWordFile(^(cassotis::EngineClient &engine, NSURL *url) {
                                  NSMutableString *records = [NSMutableString string];
                                  for (NSArray *row in selected)
                                      [records appendFormat:@"%@\n", [row componentsJoinedByString:@","]];
                                  if (![records writeToURL:url
                                                atomically:YES
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil])
                                      throw std::runtime_error("write failed");
                                  engine.forgetUserWords(url.path.fileSystemRepresentation);
                              });
                          } catch (const std::exception &) {
                              completed = NO;
                          }
                          dispatch_async(dispatch_get_main_queue(), ^{
                              if (completed)
                                  [self readWords];
                              else {
                                  [self setBusy:NO];
                                  self->_count.stringValue = @"删除未完成，请重新打开核对";
                              }
                          });
                      });
                  }];
}
- (void)exportForWindow:(NSWindow *)parent completion:(void (^)(NSString *))completion {
    NSSavePanel *panel = NSSavePanel.savePanel;
    panel.title = @"导出词频";
    panel.nameFieldStringValue = @"言泉输入法词频.csv";
    panel.allowedContentTypes = @[ UTTypeCommaSeparatedText ];
    [panel beginSheetModalForWindow:parent
                  completionHandler:^(NSModalResponse response) {
                      if (response != NSModalResponseOK)
                          return;
                      NSURL *destination = panel.URL;
                      dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                          __block NSString *message = @"导出未完成，请检查保存位置并重试。";
                          BOOL accessed = [destination startAccessingSecurityScopedResource];
                          try {
                              withWordFile(^(cassotis::EngineClient &engine, NSURL *url) {
                                  uint32_t count = engine.exportUserWords(url.path.fileSystemRepresentation);
                                  if (!count) {
                                      message = @"还没有可导出的已学词语。";
                                      return;
                                  }
                                  NSData *data = [NSData dataWithContentsOfURL:url];
                                  if (data && [data writeToURL:destination
                                                       options:NSDataWritingAtomic
                                                         error:nil])
                                      message = [NSString stringWithFormat:@"已导出 %u 个词语。", count];
                              });
                          } catch (const std::exception &) {}
                          if (accessed)
                              [destination stopAccessingSecurityScopedResource];
                          dispatch_async(dispatch_get_main_queue(), ^{ completion(message); });
                      });
                  }];
}
@end
