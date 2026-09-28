#import "CandidateAppearance.h"
#import "ProductName.h"
#include <cmath>

NSString *CassotisDisplayVersion(void) {
    NSString *version=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    // Unbundled native fixtures read the same checked-in resource as the app.
    if(!version.length) version=[NSDictionary dictionaryWithContentsOfFile:@"resources/Info.plist"][@"CFBundleShortVersionString"];
    return version?:@"";
}

NSArray<NSString *> *CassotisCandidateThemeNames(void) {
    return @[@"跟随系统", @"晴白", @"深色", @"月白", @"青瓷", @"晴蓝", @"松墨", @"靛夜"];
}
NSArray<NSNumber *> *CassotisCandidateFontSizes(void) { return @[@12,@14,@16,@18,@20,@22,@24,@28,@32]; }
CGFloat CassotisCandidateFontSize(NSUserDefaults *defaults) {
    CGFloat size=[defaults doubleForKey:@"CandidateFontSize"];
    return std::isfinite(size) && size>0 ? MIN(32,MAX(12,size)) : 14;
}
NSInteger CassotisCandidateTheme(NSUserDefaults *defaults) {
    NSInteger theme=[defaults integerForKey:@"CandidateTheme"];
    return theme>=0 && theme<(NSInteger)CassotisCandidateThemeNames().count ? theme : 0;
}
static NSColor *rgb(uint32_t value) {
    return [NSColor colorWithSRGBRed:((value>>16)&255)/255.0 green:((value>>8)&255)/255.0
        blue:(value&255)/255.0 alpha:1];
}
static NSColor *blend(NSColor *background, NSColor *foreground, CGFloat fraction) {
    auto channel=[&](CGFloat back,CGFloat front) {
        return round(255*(back*(1-fraction)+front*fraction))/255;
    };
    return [NSColor colorWithSRGBRed:channel(background.redComponent,foreground.redComponent)
        green:channel(background.greenComponent,foreground.greenComponent)
        blue:channel(background.blueComponent,foreground.blueComponent) alpha:1];
}
CassotisCandidateColors CassotisColors(NSInteger theme, NSAppearance *appearance) {
    // Exact RGB values from Windows 1.29.0 src/ui/nc_candidate_theme.pas.
    static const uint32_t palettes[][13]={
        {0xfcfdff,0xd6dfec,0x181818,0x627080,0x707a86,0x2e7d32,0x1d65c1,0xe8f0fe,0xadc6eb,0x141414,0x1b5e20,0x174f9a,0x4c5662},
        {0xf8f5ee,0xe0d8ca,0x242b30,0x706a60,0x787268,0x478053,0x2768a8,0xeae1d2,0xccbea9,0x1e2226,0x2f6c3c,0x1d568f,0x5f584e},
        {0xebf4ef,0xbed6cc,0x1e3a32,0x577069,0x586f69,0x236c46,0x176f9f,0xd3e7de,0x97beb0,0x163029,0x195b39,0x105b84,0x435d57},
        {0xe7f3f9,0xb8d3e1,0x1b3648,0x567487,0x5a7688,0x237074,0x1469a8,0xd5e8f1,0x8bb8cf,0x142d3e,0x185e62,0x0e5489,0x415e70},
        {0x192120,0x475852,0xe5ebe4,0xa0aea6,0x93a199,0x85d898,0x70bdeb,0x364b45,0x5e8074,0xf4f8f2,0xb3eabf,0x9cd6f4,0xbbc8c1},
        {0x1a2238,0x435074,0xe8edf8,0xa6b0cc,0x97a3c2,0x89d4be,0x79bfff,0x304167,0x5a71aa,0xf6f9ff,0xb0ebda,0xabd8ff,0xbec9e5},
        {0x252628,0x4c4e52,0xf0f0f2,0xb5b7bc,0xa9adb5,0x96d69b,0x92c6fc,0x414a5b,0x65799c,0xffffff,0xb3eabf,0xabd8ff,0xd1d9e8}
    };
    NSInteger index=0;
    if(theme==0) {
        NSString *match=[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]];
        index=[match isEqual:NSAppearanceNameDarkAqua]?6:0;
    } else if(theme==2) index=6;
    else if(theme>=3 && theme<=7) index=theme-2;
    const uint32_t *p=palettes[index];
    return {rgb(p[0]),rgb(p[1]),rgb(p[2]),rgb(p[3]),rgb(p[4]),rgb(p[5]),rgb(p[6]),
        rgb(p[7]),rgb(p[8]),rgb(p[9]),rgb(p[10]),rgb(p[11]),rgb(p[12]),index>=4};
}

@interface CassotisCandidateButton : NSButton
@property(nonatomic, strong) NSColor *fillColor;
@property(nonatomic, strong) NSColor *strokeColor;
@property(nonatomic) CGFloat trailingInset;
@end
@implementation CassotisCandidateButton
- (NSSize)intrinsicContentSize {
    NSSize text=self.attributedTitle.size;
    return NSMakeSize(ceil(text.width)+16+self.trailingInset,ceil(text.height)+8);
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if(self.fillColor) {
        NSBezierPath *path=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0.5,0.5) xRadius:5 yRadius:5];
        [self.fillColor setFill]; [path fill];
        [self.strokeColor setStroke]; path.lineWidth=1; [path stroke];
    }
    NSRect text=NSInsetRect(self.bounds,8,4);
    text.size.width=MAX(0,text.size.width-self.trailingInset);
    text.origin.y=floor((self.bounds.size.height-self.attributedTitle.size.height)/2);
    text.size.height=self.attributedTitle.size.height;
    [self.attributedTitle drawWithRect:text options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingTruncatesLastVisibleLine];
}
@end

@interface CassotisCandidateRemoveButton : NSButton
@end
@implementation CassotisCandidateRemoveButton
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    // Keep the small mark close to the word; the rest of the control remains
    // an easy click target on its right, outside the candidate text.
    NSRect box=NSMakeRect(MIN(4,MAX(0,self.bounds.size.width-10)),floor((self.bounds.size.height-10)/2),10,10);
    NSBezierPath *outline=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(box,0.5,0.5) xRadius:2 yRadius:2];
    [rgb(self.highlighted?0xffcdd2:0xffedef) setFill]; [outline fill];
    [rgb(0xe57373) setStroke]; [outline stroke];
    NSBezierPath *cross=[NSBezierPath bezierPath]; cross.lineWidth=1.1;
    [cross moveToPoint:NSMakePoint(NSMinX(box)+3,NSMinY(box)+3)];
    [cross lineToPoint:NSMakePoint(NSMaxX(box)-3,NSMaxY(box)-3)];
    [cross moveToPoint:NSMakePoint(NSMinX(box)+3,NSMaxY(box)-3)];
    [cross lineToPoint:NSMakePoint(NSMaxX(box)-3,NSMinY(box)+3)];
    [rgb(0xb71c1c) setStroke]; [cross stroke];
}
@end

@interface CassotisCandidateContent : NSView
@property(nonatomic) NSSize preferredSize;
@property(nonatomic) CGFloat rowHeight;
@property(nonatomic, strong) NSArray<NSArray<NSView *> *> *rows;
@property(nonatomic, strong) NSView *activeRow;
@property(nonatomic, strong) NSView *activeRowIndicator;
@property(nonatomic) NSInteger activeRowIndex;
@property(nonatomic, strong) NSView *footer;
@property(nonatomic, strong) NSView *separator;
@property(nonatomic, strong) NSButton *completion;
@property(nonatomic, strong) NSTextField *warning;
@property(nonatomic, strong) NSImageView *logo;
@property(nonatomic, strong) NSTextField *version;
@end
@implementation CassotisCandidateContent
- (NSSize)intrinsicContentSize { return self.preferredSize; }
- (NSSize)fittingSize { return self.preferredSize; }
- (void)layout {
    [super layout];
    constexpr CGFloat padding=8,gap=4;
    CGFloat inner=MAX(0,self.bounds.size.width-2*padding);
    for(NSUInteger row=0;row<self.rows.count;++row) {
        NSArray<NSView *> *items=self.rows[row];
        CGFloat available=MAX(0,inner-gap*MAX(0,(NSInteger)items.count-1));
        // Long text truncates within its row; all nine keyboard choices remain visible.
        std::vector<CGFloat> widths;
        CGFloat naturalWidth=0;
        for(NSView *item in items) {
            CGFloat width=item.subviews[0].intrinsicContentSize.width;
            widths.push_back(width); naturalWidth+=width;
        }
        CGFloat low=available,high=available;
        if(naturalWidth>available) {
            low=0;
            for(int step=0;step<32;++step) {
                CGFloat cap=(low+high)/2,sum=0;
                for(CGFloat width:widths) sum+=MIN(width,cap);
                if(sum>available) high=cap; else low=cap;
            }
        }
        CGFloat x=padding,y=8+(self.rows.count-row)*self.rowHeight+5;
        if(NSInteger(row)==self.activeRowIndex) {
            self.activeRow.frame=NSMakeRect(4,y,self.bounds.size.width-8,self.rowHeight);
            self.activeRowIndicator.frame=NSMakeRect(1,4,2,MAX(0,self.rowHeight-8));
        }
        for(NSUInteger i=0;i<items.count;++i) {
            NSView *item=items[i]; CGFloat width=floor(MIN(widths[i],low));
            item.frame=NSMakeRect(x,y,width,self.rowHeight);
            item.subviews[0].frame=item.bounds;
            if(item.subviews.count>1) item.subviews[1].frame=NSMakeRect(MAX(0,width-22),0,MIN(22,width),self.rowHeight);
            x+=width+gap;
        }
    }
    self.separator.frame=NSMakeRect(padding,8+self.rowHeight+2,inner,1);
    self.footer.frame=NSMakeRect(padding,8,inner,self.rowHeight);
    CGFloat versionWidth=ceil(self.version.intrinsicContentSize.width);
    CGFloat brandWidth=20+5+versionWidth,brandX=MAX(0,inner-brandWidth);
    self.logo.frame=NSMakeRect(brandX,floor((self.rowHeight-20)/2),20,20);
    self.version.frame=NSMakeRect(brandX+25,floor((self.rowHeight-self.version.intrinsicContentSize.height)/2),
        versionWidth,self.version.intrinsicContentSize.height);
    CGFloat textWidth=MAX(0,brandX-12),completionX=0;
    if(self.warning) {
        CGFloat warningWidth=MIN(ceil(self.warning.intrinsicContentSize.width),
            self.completion.enabled?MAX(0,(textWidth-12)/2):textWidth);
        CGFloat height=MIN(self.rowHeight,self.warning.intrinsicContentSize.height);
        self.warning.frame=NSMakeRect(0,floor((self.rowHeight-height)/2),warningWidth,height);
        completionX=MIN(textWidth,warningWidth+12);
    }
    self.completion.frame=NSMakeRect(completionX,0,MAX(0,textWidth-completionX),self.rowHeight);
}
@end

static NSString *str(const std::string &s) {
    return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding] ?: @"";
}
static CassotisCandidateButton *candidateButton(NSString *prefix, NSString *text, NSString *comment,
    NSFont *font, NSColor *color, NSColor *muted, BOOL selected, const CassotisCandidateColors &colors,
    BOOL hidePrefix=NO) {
    CassotisCandidateButton *button=[[CassotisCandidateButton alloc] init];
    button.bordered=NO; button.focusRingType=NSFocusRingTypeNone;
    button.font=font; button.alignment=NSTextAlignmentLeft;
    NSMutableParagraphStyle *paragraph=[[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode=NSLineBreakByTruncatingTail;
    NSMutableAttributedString *title=[[NSMutableAttributedString alloc] initWithString:prefix
        attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:hidePrefix?NSColor.clearColor:muted,
            NSParagraphStyleAttributeName:paragraph}];
    [title appendAttributedString:[[NSAttributedString alloc] initWithString:text
        attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:paragraph}]];
    if(comment.length) [title appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:comment]
        attributes:@{NSFontAttributeName:[NSFont systemFontOfSize:MAX(11,font.pointSize-2)],
            NSForegroundColorAttributeName:muted,NSParagraphStyleAttributeName:paragraph}]];
    button.attributedTitle=title;
    button.toolTip=hidePrefix?[title.string substringFromIndex:prefix.length]:title.string;
    if(selected) { button.fillColor=colors.selection; button.strokeColor=colors.selectionBorder; }
    button.accessibilityValue=selected?@"已选中":@"";
    return button;
}
static NSString *displayComment(const std::string &raw) {
    NSString *comment=[str(raw) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!comment.length) return @"";
    // Match Windows format_candidate_line without changing partial commits.
    NSCharacterSet *pinyin=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'"];
    return [comment rangeOfCharacterFromSet:pinyin.invertedSet].location==NSNotFound?@"":comment;
}
static NSTextField *pinyinWarning(const cassotis::Result &r, NSFont *font, NSColor *muted) {
    NSString *raw=str(r.preedit);
    NSRange excerpt=NSMakeRange(NSNotFound,0);
    for(const auto &span:r.warnings) {
        if(span.start>raw.length || span.length==0 || span.length>raw.length-span.start) continue;
        NSUInteger start=span.start>10?span.start-10:0;
        NSUInteger end=MIN(raw.length,span.start+MIN(NSUInteger(span.length),NSUInteger(24))+10);
        excerpt=[raw rangeOfComposedCharacterSequencesForRange:NSMakeRange(start,end-start)]; break;
    }
    if(excerpt.location==NSNotFound) return nil;
    // Some IMK clients replace marked-text colors with their own styles. Keep
    // the diagnostic visible in the existing footer without changing its height.
    NSString *prefix=excerpt.location?@"拼音  …":@"拼音  ";
    NSString *text=[prefix stringByAppendingString:[raw substringWithRange:excerpt]];
    if(NSMaxRange(excerpt)<raw.length) text=[text stringByAppendingString:@"…"];
    NSMutableAttributedString *value=[[NSMutableAttributedString alloc] initWithString:text
        attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:muted}];
    for(const auto &span:r.warnings) {
        if(span.start>raw.length || span.length==0 || span.length>raw.length-span.start) continue;
        NSRange visible=NSIntersectionRange(excerpt,NSMakeRange(span.start,span.length));
        if(visible.length) [value addAttributes:@{NSForegroundColorAttributeName:NSColor.systemRedColor,
            NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)}
            range:NSMakeRange(prefix.length+visible.location-excerpt.location,visible.length)];
    }
    NSTextField *field=[NSTextField labelWithAttributedString:value];
    field.maximumNumberOfLines=1; field.lineBreakMode=NSLineBreakByTruncatingTail;
    field.cell.usesSingleLineMode=YES; field.cell.wraps=NO;
    field.accessibilityIdentifier=@"candidate-pinyin-warning";
    field.accessibilityLabel=@"拼音输入有误"; field.toolTip=raw;
    return field;
}
NSView *CassotisCandidateView(const cassotis::Result &r, CGFloat size, NSString *family,
    NSInteger theme, CGFloat maximumWidth, NSAppearance *appearance,
    id target, SEL selection, SEL deletion, NSUInteger revision, uint8_t completionKey) {
    auto colors=CassotisColors(theme,appearance);
    NSFont *font=family.length?[NSFontManager.sharedFontManager fontWithFamily:family traits:0 weight:5 size:size]:nil;
    if(!font) font=[NSFont systemFontOfSize:size];
    CassotisCandidateContent *background=[[CassotisCandidateContent alloc] init];
    background.appearance=[NSAppearance appearanceNamed:colors.dark?NSAppearanceNameDarkAqua:NSAppearanceNameAqua];
    background.wantsLayer=YES; background.layer.cornerRadius=8; background.layer.masksToBounds=YES;
    background.layer.backgroundColor=colors.background.CGColor;
    background.layer.borderColor=colors.border.CGColor; background.layer.borderWidth=1;
    background.accessibilityIdentifier=@"candidate-content";
    background.accessibilityLabel=[NSString stringWithFormat:@"候选，第 %d 页，共 %d 页",r.page+1,MAX(1,r.pages)];
    // Keep the footer even for empty, pending or changing completion results.
    // Use font metrics rather than the current strings to keep their height fixed.
    background.rowHeight=ceil(MAX(size*1.4,font.ascender-font.descender+font.leading))+8;
    std::vector<cassotis::CandidatePage> pages=r.candidatePages;
    if(pages.empty()) pages.push_back({r.page,r.candidates});
    NSMutableArray<NSArray<NSView *> *> *rows=[NSMutableArray array];
    CGFloat rowWidth=0;
    if(pages.size()>1) {
        NSView *active=[[NSView alloc] init]; active.wantsLayer=YES; active.layer.cornerRadius=5;
        active.layer.backgroundColor=blend(colors.background,colors.selection,0.4).CGColor;
        active.accessibilityIdentifier=@"candidate-active-row";
        [background addSubview:active]; background.activeRow=active;
        NSView *indicator=[[NSView alloc] init]; indicator.wantsLayer=YES;
        indicator.layer.backgroundColor=blend(colors.selectionBorder,colors.text,0.25).CGColor;
        indicator.layer.cornerRadius=1; indicator.accessibilityIdentifier=@"candidate-active-row-indicator";
        [active addSubview:indicator]; background.activeRowIndicator=indicator;
    }
    for(const auto &row:pages) {
        if(row.page==r.page) background.activeRowIndex=rows.count;
        NSMutableArray<NSView *> *items=[NSMutableArray array];
        CGFloat currentWidth=0; NSInteger i=0;
    for(const auto &c:row.candidates) {
        if(i==9) break;
        BOOL active=row.page==r.page, selected=active && i==r.selected;
        NSInteger tag=active?i:(NSInteger(row.page)+1)*16+i;
        // Keep the actual numbered prefix in the layout even on inactive rows.
        // Spaces have different advances and move every subsequent candidate
        // when the active row changes, especially with proportional fonts.
        NSString *prefix=[NSString stringWithFormat:@"%ld  ",(long)i+1];
        NSColor *color=c.source==1?(selected?colors.selectedUser:colors.user):
            c.kind==1?(selected?colors.selectedCompound:colors.compound):(selected?colors.selectedText:colors.text);
        CassotisCandidateButton *button=candidateButton(prefix,str(c.text),displayComment(c.comment),
            font,color,selected?colors.selectedWeight:colors.weight,selected,colors,!active);
        button.tag=tag; button.target=target; button.action=selection;
        button.accessibilityLabel=[NSString stringWithFormat:@"候选 %ld，%@",(long)i+1,str(c.text)];
        button.accessibilityIdentifier=active?[NSString stringWithFormat:@"candidate-%ld",(long)i]:
            [NSString stringWithFormat:@"candidate-page-%d-%ld",row.page,(long)i];
        NSView *item=[[NSView alloc] init]; [item addSubview:button];
        if(c.deletable) {
            button.trailingInset=14;
            CassotisCandidateRemoveButton *remove=[[CassotisCandidateRemoveButton alloc] init];
            remove.bordered=NO; remove.focusRingType=NSFocusRingTypeNone;
            remove.title=@"×"; remove.tag=tag; remove.target=target; remove.action=deletion;
            remove.enabled=target && deletion;
            remove.accessibilityLabel=[@"删除用户词：" stringByAppendingString:str(c.text)];
            remove.accessibilityIdentifier=active?[NSString stringWithFormat:@"candidate-delete-%ld",(long)i]:
                [NSString stringWithFormat:@"candidate-delete-page-%d-%ld",row.page,(long)i];
            remove.toolTip=remove.accessibilityLabel; [item addSubview:remove];
            if(target && deletion) {
                NSMenu *menu=[[NSMenu alloc] initWithTitle:@"用户词语"];
                NSMenuItem *command=[[NSMenuItem alloc] initWithTitle:@"删除此用户词语" action:deletion keyEquivalent:@""];
                command.target=target; command.representedObject=@[@(revision),@(tag)]; [menu addItem:command]; button.menu=menu;
            }
        }
        [items addObject:item];
        currentWidth+=button.intrinsicContentSize.width+(i?4:0); [background addSubview:item]; ++i;
    }
        rowWidth=MAX(rowWidth,currentWidth); [rows addObject:items];
    }
    background.rows=rows;
    NSView *footer=[[NSView alloc] init]; footer.accessibilityIdentifier=@"candidate-completion-row";
    [background addSubview:footer]; background.footer=footer;
    NSString *key=completionKey==1?@"`":@"Tab";
    NSString *prefix=r.completion.empty()?@"":[key stringByAppendingString:@"  "];
    BOOL predictive=r.completionSource!=cassotis::CompletionSource::None &&
        r.completionSource!=cassotis::CompletionSource::ExactTailFallback;
    NSButton *completion=candidateButton(prefix,str(r.completion),@"",font,predictive?colors.compound:colors.text,colors.muted,NO,colors);
    completion.tag=-1; completion.target=target; completion.action=selection;
    completion.enabled=!r.completion.empty(); completion.accessibilityIdentifier=@"candidate-completion";
    completion.accessibilityLabel=r.completion.empty()?@"暂无补全":[@"补全，" stringByAppendingString:str(r.completion)];
    [footer addSubview:completion]; background.completion=completion;
    NSTextField *warning=pinyinWarning(r,font,colors.muted);
    if(warning) { [footer addSubview:warning]; background.warning=warning; }
    NSString *logoPath=[NSBundle.mainBundle pathForResource:@"Cassotis" ofType:@"png"]?:@"resources/Cassotis.png";
    NSImage *logo=[[NSImage alloc] initWithContentsOfFile:logoPath];
    NSImageView *image=[[NSImageView alloc] init]; image.image=logo;
    image.imageScaling=NSImageScaleProportionallyUpOrDown;
    image.accessibilityIdentifier=@"candidate-brand-logo"; image.accessibilityLabel=CassotisShortName();
    [footer addSubview:image]; background.logo=image;
    NSTextField *version=[NSTextField labelWithString:[NSString stringWithFormat:@"(v%@)",CassotisDisplayVersion()]];
    version.font=[NSFont systemFontOfSize:11]; version.textColor=colors.muted;
    version.accessibilityIdentifier=@"candidate-version"; [footer addSubview:version]; background.version=version;
    NSView *separator=[[NSView alloc] init]; separator.wantsLayer=YES; separator.layer.backgroundColor=colors.border.CGColor;
    [background addSubview:separator]; background.separator=separator;
    CGFloat footerWidth=completion.intrinsicContentSize.width+12+20+5+ceil(version.intrinsicContentSize.width);
    if(warning) footerWidth+=ceil(warning.intrinsicContentSize.width)+12;
    background.preferredSize=NSMakeSize(MIN(maximumWidth,MAX(180,MAX(rowWidth,footerWidth)+16)),(rows.count+1)*background.rowHeight+21);
    [background setFrameSize:background.preferredSize]; [background setNeedsLayout:YES]; [background layoutSubtreeIfNeeded];
    return background;
}
