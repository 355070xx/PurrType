#import "PurrTypePreferencesWindowController.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypeQuickPhraseStore.h"
#import "PurrTypeBackupStore.h"
#import "PurrTypePreferencesStore.h"
#import "PurrTypePreferencesConstants.h"
#import <CoreImage/CoreImage.h>
#include <math.h>

static CGFloat const MKPreferencesWindowWidth = 622.0;
static CGFloat const MKPreferencesWindowHeight = 720.0;
static CGFloat const MKPreferencesMinimumWindowWidth = 622.0;
static CGFloat const MKPreferencesMinimumWindowHeight = 620.0;
static CGFloat const MKPreferencesSidebarWidth = 180.0;
static CGFloat const MKPreferencesSidebarTitleInset = 20.0;
static CGFloat const MKPreferencesSidebarTitleTrailingInset = 8.0;
static CGFloat const MKPreferencesSidebarHeaderIconSize = 40.0;
static CGFloat const MKPreferencesSidebarHeaderSpacing = 8.0;
static CGFloat const MKPreferencesSidebarItemInset = 14.0;
static NSString *const MKPreferencesTabGeneral = @"general";
static NSString *const MKPreferencesTabInputModes = @"input_modes";
static NSString *const MKPreferencesTabTyping = @"typing";
static NSString *const MKPreferencesTabPrivacyLearning = @"privacy_learning";
static NSString *const MKPreferencesTabAbout = @"about";
static NSString *const MKPreferencesLanguageSystem = @"system";
static NSString *const MKPreferencesLanguageEnglish = @"en";
static NSString *const MKPreferencesLanguageTraditionalChinese = @"zh-Hant";
static NSString *const MKPreferencesShortcutEditorIdentifier = @"purrtype.shortcut-editor";
static CGFloat const MKPreferencesContentHorizontalMargin = 16.0;
static CGFloat const MKPreferencesCoverAspectRatio = 1672.0 / 941.0;
static CGFloat const MKPreferencesCoverMaxWidth = 380.0;
static CGFloat const MKPrivacyPolicySheetWidth = 560.0;
static CGFloat const MKPrivacyPolicySheetHeight = 620.0;
static NSInteger const MKPreferencesShortcutTagSwitchInputMode = 9001;
static NSInteger const MKPreferencesShortcutTagPrivacyLock = 9002;
static NSInteger const MKPreferencesShortcutTagModeBase = 9100;
static NSInteger const MKPreferencesInputModeSwitchTagBase = 9200;
static NSTimeInterval const MKPreferencesShortcutDoubleTapInterval = 0.60;

static NSSize MKPreferencesStandardContentSize(void) {
    return NSMakeSize(MKPreferencesWindowWidth, MKPreferencesWindowHeight);
}

static CGFloat MKPreferencesContentColumnWidth(void) {
    return MKPreferencesWindowWidth - MKPreferencesSidebarWidth - (MKPreferencesContentHorizontalMargin * 2.0);
}

static NSFont *MKFont(CGFloat size, NSFontWeight weight) {
    return [NSFont systemFontOfSize:size weight:weight];
}

static NSColor *MKColorFromRGB(NSUInteger rgb) {
    return [NSColor colorWithCalibratedRed:((rgb >> 16) & 0xFF) / 255.0
                                     green:((rgb >> 8) & 0xFF) / 255.0
                                      blue:(rgb & 0xFF) / 255.0
                                     alpha:1.0];
}

static NSString *MKPreferencesCustomHighlightStringFromColor(NSColor *color) {
    NSColor *rgbColor = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (!rgbColor) {
        return [MKCandidatePanelHighlightCustomPrefix stringByAppendingString:@"#FF4F57"];
    }
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat alpha = 1.0;
    [rgbColor getRed:&red green:&green blue:&blue alpha:&alpha];
    NSUInteger redByte = (NSUInteger)lrint(MAX(0.0, MIN(1.0, red)) * 255.0);
    NSUInteger greenByte = (NSUInteger)lrint(MAX(0.0, MIN(1.0, green)) * 255.0);
    NSUInteger blueByte = (NSUInteger)lrint(MAX(0.0, MIN(1.0, blue)) * 255.0);
    return [NSString stringWithFormat:@"%@#%02lX%02lX%02lX",
                                      MKCandidatePanelHighlightCustomPrefix,
                                      (unsigned long)redByte,
                                      (unsigned long)greenByte,
                                      (unsigned long)blueByte];
}

static NSColor *MKPreferencesColorForCandidateHighlightValue(NSString *highlightColor) {
    if ([highlightColor hasPrefix:MKCandidatePanelHighlightCustomPrefix]) {
        NSString *hex = [highlightColor substringFromIndex:MKCandidatePanelHighlightCustomPrefix.length];
        if ([hex hasPrefix:@"#"]) {
            hex = [hex substringFromIndex:1];
        }
        if (hex.length == 6) {
            unsigned int rgb = 0;
            NSScanner *scanner = [NSScanner scannerWithString:hex];
            if ([scanner scanHexInt:&rgb] && scanner.isAtEnd) {
                return MKColorFromRGB(rgb & 0xFFFFFF);
            }
        }
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightOrange]) {
        return MKColorFromRGB(0xE86B2E);
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightYellow]) {
        return MKColorFromRGB(0xC78514);
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightGreen]) {
        return MKColorFromRGB(0x338C47);
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightBlue]) {
        return MKColorFromRGB(0x2870E8);
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightPurple]) {
        return MKColorFromRGB(0x8552DB);
    }
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightPink]) {
        return MKColorFromRGB(0xD63D85);
    }
    return MKColorFromRGB(0xFF4F57);
}

static NSColor *MKPreferencesWindowBackgroundColor(void) { return MKColorFromRGB(0xFFF9F2); }
static NSColor *MKPreferencesSidebarBackgroundColor(void) { return MKColorFromRGB(0xFFF7F0); }
static NSColor *MKPreferencesContentBackgroundColor(void) { return MKColorFromRGB(0xFFFCF8); }
static NSColor *MKPreferencesCardBackgroundColor(void) { return MKColorFromRGB(0xFFFFFF); }
static NSColor *MKPreferencesBorderColor(void) { return MKColorFromRGB(0xE8DDD3); }
static NSColor *MKPreferencesSelectedSidebarColor(void) { return MKColorFromRGB(0xF9E8DC); }
static NSColor *MKPreferencesAccentColor(void) { return MKColorFromRGB(0xD96A35); }
static NSColor *MKPreferencesAccentActiveColor(void) { return MKColorFromRGB(0xC95728); }
static NSColor *MKPreferencesPrimaryTextColor(void) { return MKColorFromRGB(0x1F1F1F); }
static NSColor *MKPreferencesSecondaryTextColor(void) { return MKColorFromRGB(0x777777); }

@interface MKPreferencesFillView : NSView
@property(nonatomic, strong) NSColor *fillColor;
@end

@implementation MKPreferencesFillView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _fillColor = MKPreferencesContentBackgroundColor();
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [self.fillColor setFill];
    NSRectFill(self.bounds);
}

@end

@interface MKPreferencesRootView : NSView
@end

@implementation MKPreferencesRootView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [MKPreferencesWindowBackgroundColor() setFill];
    NSRectFill(self.bounds);
}

@end

@interface MKPreferencesSidebarButton : NSButton
@property(nonatomic, assign) BOOL selectedItem;
@end

@implementation MKPreferencesSidebarButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.alignment = NSTextAlignmentLeft;
        self.imagePosition = NSImageLeft;
        self.font = MKFont(12, NSFontWeightSemibold);
        self.contentTintColor = MKPreferencesPrimaryTextColor();
        self.bezelStyle = NSBezelStyleRegularSquare;
        [self setButtonType:NSButtonTypeMomentaryChange];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if (self.selectedItem) {
        NSRect rect = NSInsetRect(self.bounds, 1.0, 2.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];
        [MKPreferencesSelectedSidebarColor() setFill];
        [path fill];
    }
    [super drawRect:dirtyRect];
}

@end

@interface MKPreferencesCardView : NSView
@property(nonatomic, strong) NSColor *fillColor;
@property(nonatomic, strong) NSColor *strokeColor;
@property(nonatomic, assign) CGFloat radius;
@end

@implementation MKPreferencesCardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _fillColor = MKPreferencesCardBackgroundColor();
        _strokeColor = MKPreferencesBorderColor();
        _radius = 16.0;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect rect = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:self.radius yRadius:self.radius];
    [self.fillColor setFill];
    [path fill];
    [self.strokeColor setStroke];
    path.lineWidth = 1.0;
    [path stroke];
}

@end

@interface MKPreferencesCoverView : MKPreferencesCardView
@property(nonatomic, strong, nullable) NSImage *image;
@property(nonatomic, copy) NSString *fallbackTitle;
@end

@implementation MKPreferencesCoverView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect imageBounds = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:imageBounds
                                                         xRadius:self.radius
                                                         yRadius:self.radius];
    [self.fillColor setFill];
    [clip fill];

    [NSGraphicsContext saveGraphicsState];
    [clip addClip];

    if (self.image) {
        NSSize imageSize = self.image.size;
        if (imageSize.width > 0.0 && imageSize.height > 0.0) {
            CGFloat scaleX = NSWidth(imageBounds) / imageSize.width;
            CGFloat scaleY = NSHeight(imageBounds) / imageSize.height;
            CGFloat scale = MIN(scaleX, scaleY);
            NSSize drawSize = NSMakeSize(imageSize.width * scale, imageSize.height * scale);
            NSRect drawRect = NSMakeRect(NSMidX(imageBounds) - drawSize.width / 2.0,
                                         NSMidY(imageBounds) - drawSize.height / 2.0,
                                         drawSize.width,
                                         drawSize.height);
            NSRect sourceRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
            [self.image drawInRect:drawRect
                           fromRect:sourceRect
                          operation:NSCompositingOperationSourceOver
                           fraction:1.0
                     respectFlipped:YES
                              hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
        }
    } else {
        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSFontAttributeName: MKFont(22, NSFontWeightSemibold),
            NSForegroundColorAttributeName: MKPreferencesAccentColor()
        };
        NSSize textSize = [self.fallbackTitle sizeWithAttributes:attributes];
        NSRect textRect = NSMakeRect(NSMidX(imageBounds) - textSize.width / 2.0,
                                     NSMidY(imageBounds) - textSize.height / 2.0,
                                     textSize.width,
                                     textSize.height);
        [self.fallbackTitle drawInRect:textRect withAttributes:attributes];
    }

    [NSGraphicsContext restoreGraphicsState];

    [self.strokeColor setStroke];
    clip.lineWidth = 1.0;
    [clip stroke];
}

@end

@interface MKPreferencesSegmentedControl : NSControl
@property(nonatomic, assign) NSInteger segmentCount;
@property(nonatomic, assign) NSInteger selectedSegment;
@property(nonatomic, assign) NSSegmentSwitchTracking trackingMode;
@property(nonatomic, assign) NSSegmentStyle segmentStyle;
- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment;
- (NSString *)labelForSegment:(NSInteger)segment;
- (void)setWidth:(CGFloat)width forSegment:(NSInteger)segment;
- (void)setSegmentEnabled:(BOOL)enabled forSegment:(NSInteger)segment;
- (BOOL)isSegmentEnabled:(NSInteger)segment;
@end

@implementation MKPreferencesSegmentedControl {
    NSMutableArray<NSString *> *_labels;
    NSMutableArray<NSNumber *> *_segmentWidths;
    NSMutableArray<NSNumber *> *_segmentEnabled;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _labels = [NSMutableArray array];
        _segmentWidths = [NSMutableArray array];
        _segmentEnabled = [NSMutableArray array];
        _selectedSegment = -1;
        self.font = MKFont(12, NSFontWeightRegular);
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)setSegmentCount:(NSInteger)segmentCount {
    _segmentCount = MAX(0, segmentCount);
    [_labels removeAllObjects];
    [_segmentWidths removeAllObjects];
    [_segmentEnabled removeAllObjects];
    for (NSInteger index = 0; index < _segmentCount; index += 1) {
        [_labels addObject:@""];
        [_segmentWidths addObject:@0];
        [_segmentEnabled addObject:@YES];
    }
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay:YES];
}

- (void)setSelectedSegment:(NSInteger)selectedSegment {
    _selectedSegment = selectedSegment;
    [self setNeedsDisplay:YES];
}

- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment {
    if (segment < 0 || segment >= self.segmentCount) {
        return;
    }
    _labels[(NSUInteger)segment] = label ?: @"";
    [self setNeedsDisplay:YES];
}

- (NSString *)labelForSegment:(NSInteger)segment {
    if (segment < 0 || segment >= self.segmentCount) {
        return @"";
    }
    return _labels[(NSUInteger)segment];
}

- (void)setWidth:(CGFloat)width forSegment:(NSInteger)segment {
    if (segment < 0 || segment >= self.segmentCount) {
        return;
    }
    _segmentWidths[(NSUInteger)segment] = @(MAX(0.0, width));
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay:YES];
}

- (void)setSegmentEnabled:(BOOL)enabled forSegment:(NSInteger)segment {
    if (segment < 0 || segment >= self.segmentCount) {
        return;
    }
    _segmentEnabled[(NSUInteger)segment] = @(enabled);
    [self setNeedsDisplay:YES];
}

- (BOOL)isSegmentEnabled:(NSInteger)segment {
    if (segment < 0 || segment >= self.segmentCount) {
        return NO;
    }
    return _segmentEnabled[(NSUInteger)segment].boolValue;
}

- (CGFloat)configuredWidth {
    CGFloat total = 0.0;
    for (NSNumber *width in _segmentWidths) {
        total += width.doubleValue;
    }
    return total;
}

- (NSSize)intrinsicContentSize {
    CGFloat width = [self configuredWidth];
    if (width <= 0.0) {
        width = MAX(1, self.segmentCount) * 76.0;
    }
    return NSMakeSize(width, 28.0);
}

- (CGFloat)drawWidthForSegment:(NSInteger)segment availableWidth:(CGFloat)availableWidth configuredTotal:(CGFloat)configuredTotal {
    if (self.segmentCount <= 0) {
        return 0.0;
    }
    if (configuredTotal <= 0.0) {
        return availableWidth / self.segmentCount;
    }
    CGFloat configured = _segmentWidths[(NSUInteger)segment].doubleValue;
    if (configured <= 0.0) {
        configured = configuredTotal / self.segmentCount;
    }
    return availableWidth * configured / configuredTotal;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
    CGFloat radius = 8.0;
    NSBezierPath *outerPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius];
    [MKPreferencesCardBackgroundColor() setFill];
    [outerPath fill];
    [MKPreferencesBorderColor() setStroke];
    outerPath.lineWidth = 1.0;
    [outerPath stroke];

    CGFloat configuredTotal = [self configuredWidth];
    CGFloat x = NSMinX(bounds);
    for (NSInteger index = 0; index < self.segmentCount; index += 1) {
        CGFloat width = [self drawWidthForSegment:index
                                   availableWidth:NSWidth(bounds)
                                  configuredTotal:configuredTotal];
        NSRect segmentRect = NSMakeRect(x, NSMinY(bounds), width, NSHeight(bounds));
        if (index == self.selectedSegment) {
            NSRect selectedRect = NSInsetRect(segmentRect, 2.0, 2.0);
            NSBezierPath *selectedPath = [NSBezierPath bezierPathWithRoundedRect:selectedRect xRadius:7.0 yRadius:7.0];
            [MKPreferencesSelectedSidebarColor() setFill];
            [selectedPath fill];
        }
        if (index > 0) {
            [MKPreferencesBorderColor() setStroke];
            NSBezierPath *separator = [NSBezierPath bezierPath];
            [separator moveToPoint:NSMakePoint(NSMinX(segmentRect), NSMinY(bounds) + 5.0)];
            [separator lineToPoint:NSMakePoint(NSMinX(segmentRect), NSMaxY(bounds) - 5.0)];
            separator.lineWidth = 1.0;
            [separator stroke];
        }
        NSString *label = [self labelForSegment:index];
        BOOL segmentEnabled = [self isSegmentEnabled:index];
        NSColor *textColor = segmentEnabled ? (index == self.selectedSegment ? MKPreferencesAccentActiveColor() : MKPreferencesPrimaryTextColor()) : MKPreferencesSecondaryTextColor();
        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSFontAttributeName: self.font ?: MKFont(13, NSFontWeightRegular),
            NSForegroundColorAttributeName: textColor
        };
        NSSize labelSize = [label sizeWithAttributes:attributes];
        NSRect labelRect = NSMakeRect(NSMidX(segmentRect) - labelSize.width / 2.0,
                                      NSMidY(segmentRect) - labelSize.height / 2.0,
                                      labelSize.width,
                                      labelSize.height);
        [label drawInRect:labelRect withAttributes:attributes];
        x += width;
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.enabled || self.segmentCount <= 0) {
        return;
    }
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat configuredTotal = [self configuredWidth];
    CGFloat x = 0.0;
    for (NSInteger index = 0; index < self.segmentCount; index += 1) {
        CGFloat width = [self drawWidthForSegment:index
                                   availableWidth:NSWidth(self.bounds)
                                  configuredTotal:configuredTotal];
        if (point.x >= x && point.x <= x + width) {
            if (![self isSegmentEnabled:index]) {
                NSBeep();
                return;
            }
            self.selectedSegment = index;
            [self sendAction:self.action to:self.target];
            return;
        }
        x += width;
    }
}

@end

@interface MKPreferencesSwitchControl : NSControl
@property(nonatomic, assign) NSControlStateValue state;
@end

@implementation MKPreferencesSwitchControl

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _state = NSControlStateValueOff;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(38.0, 22.0);
}

- (void)setState:(NSControlStateValue)state {
    _state = state == NSControlStateValueOn ? NSControlStateValueOn : NSControlStateValueOff;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect trackRect = NSInsetRect(self.bounds, 1.0, 2.0);
    CGFloat radius = NSHeight(trackRect) / 2.0;
    NSColor *trackColor = self.state == NSControlStateValueOn ? MKPreferencesAccentColor() : MKColorFromRGB(0xD2D2D2);
    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:trackRect xRadius:radius yRadius:radius];
    [trackColor setFill];
    [trackPath fill];

    CGFloat knobSize = NSHeight(trackRect) - 4.0;
    CGFloat knobX = self.state == NSControlStateValueOn ? NSMaxX(trackRect) - knobSize - 2.0 : NSMinX(trackRect) + 2.0;
    NSRect knobRect = NSMakeRect(knobX, NSMinY(trackRect) + 2.0, knobSize, knobSize);
    NSBezierPath *knobPath = [NSBezierPath bezierPathWithOvalInRect:knobRect];
    [NSColor.whiteColor setFill];
    [knobPath fill];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.12] setStroke];
    knobPath.lineWidth = 0.5;
    [knobPath stroke];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    if (!self.enabled) {
        return;
    }
    self.state = self.state == NSControlStateValueOn ? NSControlStateValueOff : NSControlStateValueOn;
    [self sendAction:self.action to:self.target];
}

@end

@interface MKPreferencesShortcutRecorderControl : NSControl
@property(nonatomic, copy) NSString *shortcutSpec;
@property(nonatomic, assign, getter=isRecording) BOOL recording;
@property(nonatomic, assign) BOOL allowsDoubleTapBacktick;
@property(nonatomic, copy) NSString *recordingPrompt;
@property(nonatomic, copy) NSString *secondBacktickPrompt;
@property(nonatomic, assign) BOOL awaitingSecondBacktick;
@property(nonatomic, assign) NSTimeInterval firstBacktickTime;
@end

@implementation MKPreferencesShortcutRecorderControl

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _shortcutSpec = [PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec];
        _recordingPrompt = NSLocalizedString(@"Press shortcut...", nil);
        _secondBacktickPrompt = NSLocalizedString(@"Press ` again...", nil);
        self.font = MKFont(12, NSFontWeightSemibold);
        self.focusRingType = NSFocusRingTypeDefault;
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    [self setNeedsDisplay:YES];
    return became;
}

- (BOOL)resignFirstResponder {
    self.recording = NO;
    [self setNeedsDisplay:YES];
    return [super resignFirstResponder];
}

- (NSSize)intrinsicContentSize {
    return NSMakeSize(178.0, 30.0);
}

- (void)setShortcutSpec:(NSString *)shortcutSpec {
    _shortcutSpec = [shortcutSpec copy] ?: @"none";
    [self setNeedsDisplay:YES];
}

- (void)setRecording:(BOOL)recording {
    _recording = recording;
    if (!recording) {
        _awaitingSecondBacktick = NO;
        _firstBacktickTime = 0;
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:8.0 yRadius:8.0];
    NSColor *fill = self.isRecording ? MKPreferencesSelectedSidebarColor() : MKPreferencesCardBackgroundColor();
    NSColor *stroke = self.isRecording ? MKPreferencesAccentColor() : MKPreferencesBorderColor();
    [fill setFill];
    [path fill];
    [stroke setStroke];
    path.lineWidth = self.isRecording ? 1.5 : 1.0;
    [path stroke];

    NSString *text = self.isRecording ?
        (self.awaitingSecondBacktick ? self.secondBacktickPrompt : self.recordingPrompt) :
        [PurrTypeInputBehavior displayNameForShortcutSpec:self.shortcutSpec];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: self.font ?: MKFont(12, NSFontWeightSemibold),
        NSForegroundColorAttributeName: self.enabled ? (self.isRecording ? MKPreferencesAccentActiveColor() : MKPreferencesPrimaryTextColor()) : MKPreferencesSecondaryTextColor(),
        NSParagraphStyleAttributeName: paragraphStyle
    };
    CGFloat textHeight = [text sizeWithAttributes:attributes].height;
    NSRect textRect = NSInsetRect(bounds, 8.0, 0.0);
    textRect.origin.y = NSMidY(bounds) - textHeight / 2.0;
    textRect.size.height = textHeight + 2.0;
    [text drawWithRect:textRect
               options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
            attributes:attributes];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    if (!self.enabled) {
        return;
    }
    self.recording = YES;
    [self.window makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)event {
    if (!self.isRecording) {
        [super keyDown:event];
        return;
    }

    NSUInteger relevantFlags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;

    if (event.keyCode == 53) {
        self.recording = NO;
        [self.window makeFirstResponder:nil];
        return;
    }

    if (event.keyCode == 51 &&
        (relevantFlags & (NSEventModifierFlagCommand |
                          NSEventModifierFlagControl |
                          NSEventModifierFlagOption |
                          NSEventModifierFlagShift)) == 0) {
        self.shortcutSpec = @"none";
        self.recording = NO;
        [self sendAction:self.action to:self.target];
        [self.window makeFirstResponder:nil];
        return;
    }

    BOOL unmodifiedBacktick = self.allowsDoubleTapBacktick &&
                              event.keyCode == 50 &&
                              (relevantFlags & (NSEventModifierFlagCommand |
                                                NSEventModifierFlagControl |
                                                NSEventModifierFlagOption |
                                                NSEventModifierFlagShift)) == 0;
    if (unmodifiedBacktick) {
        NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
        if (self.awaitingSecondBacktick &&
            self.firstBacktickTime > 0 &&
            now - self.firstBacktickTime <= MKPreferencesShortcutDoubleTapInterval) {
            self.shortcutSpec = [PurrTypeInputBehavior defaultPrivacyLockShortcutSpec];
            self.recording = NO;
            [self sendAction:self.action to:self.target];
            [self.window makeFirstResponder:nil];
            return;
        }

        self.awaitingSecondBacktick = YES;
        self.firstBacktickTime = now;
        [self setNeedsDisplay:YES];
        return;
    }

    NSString *shortcut = [PurrTypeInputBehavior shortcutSpecForKeyCode:event.keyCode modifiers:event.modifierFlags];
    if (shortcut.length == 0) {
        NSBeep();
        return;
    }

    self.shortcutSpec = shortcut;
    self.recording = NO;
    [self sendAction:self.action to:self.target];
    [self.window makeFirstResponder:nil];
}

@end

@interface PurrTypePreferencesWindowController ()

@property(nonatomic, strong) PurrTypeEngine *engine;
@property(nonatomic, weak) id<PurrTypePreferencesWindowControllerDelegate> preferencesDelegate;
@property(nonatomic, strong) NSView *sidebarContainer;
@property(nonatomic, strong) NSView *contentContainer;
@property(nonatomic, copy) NSString *selectedTab;
@property(nonatomic, strong) NSArray<NSString *> *tabIdentifiers;
@property(nonatomic, strong) NSMutableDictionary<NSString *, MKPreferencesSidebarButton *> *sidebarButtonsByIdentifier;
@property(nonatomic, strong) MKPreferencesSegmentedControl *modeSegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *inputModeSettingsSegmentedControl;
@property(nonatomic, strong) MKPreferencesSwitchControl *inputModeSettingsEnabledSwitch;
@property(nonatomic, strong) MKPreferencesSegmentedControl *modeCandidatePageSizeSegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *modeSpaceKeySegmentedControl;
@property(nonatomic, strong) MKPreferencesSwitchControl *modeClearReadingOnFailureSwitch;
@property(nonatomic, strong) MKPreferencesShortcutRecorderControl *modeShortcutRecorderControl;
@property(nonatomic, strong) NSButton *modeShortcutResetButton;
@property(nonatomic, strong) NSTextField *modeSettingsStatusField;
@property(nonatomic, copy) NSString *selectedInputModeSettingsMode;
@property(nonatomic, strong) MKPreferencesSegmentedControl *spaceKeySegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *candidatePanelOrientationSegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *candidatePanelFontSizeSegmentedControl;
@property(nonatomic, strong) NSPopUpButton *candidatePanelHighlightPopupButton;
@property(nonatomic, strong) MKPreferencesSwitchControl *associationCandidatesSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *associationContinuationSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *learningSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *privacyLockSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *rawEnglishCandidateSwitch;
@property(nonatomic, strong) MKPreferencesSegmentedControl *rawEnglishCandidatePositionSegmentedControl;
@property(nonatomic, strong) MKPreferencesSwitchControl *spellingSuggestionsSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *decimalPointShortcutSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *chineseContextPunctuationSwitch;
@property(nonatomic, strong) NSPopUpButton *voiceRecognitionLocalePopupButton;
@property(nonatomic, strong) MKPreferencesSwitchControl *voiceFloatingButtonSwitch;
@property(nonatomic, strong) MKPreferencesSegmentedControl *candidatePageSizeSegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *preferencesLanguageSegmentedControl;
@property(nonatomic, strong) NSTextField *learningStatusField;
@property(nonatomic, strong) NSTextField *privacyLockStatusField;
@property(nonatomic, strong) NSTextField *enabledInputModesNoticeField;
@property(nonatomic, strong) NSTextField *shortcutErrorField;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSImage *> *preferenceCoverImagesByFilename;
@property(nonatomic, strong) NSImage *cachedAppIconImage;
@property(nonatomic, strong) NSWindow *privacyPolicySheet;
@property(nonatomic, strong) PurrTypeQuickPhraseStore *quickPhraseStore;
@property(nonatomic, strong) PurrTypeBackupStore *backupStore;
@property(nonatomic, strong) NSTextField *quickPhraseTriggerField;
@property(nonatomic, strong) NSTextField *quickPhraseReplacementField;
@property(nonatomic, strong) NSTextField *quickPhraseSummaryField;
@property(nonatomic, strong) NSTextField *quickPhraseStatusField;
@property(nonatomic, strong) NSTextField *backupStatusField;
@property(nonatomic, strong) NSTextField *generalBehaviorStatusField;
@property(nonatomic, strong) NSTextField *dataStatusField;

- (void)rebuildSidebar;
- (void)rebuildContentPreservingScrollPosition;
- (void)normalizeWindowContentSize;
- (NSString *)localizedString:(NSString *)key;
- (NSImage *)preferenceCoverImageInBundle:(NSBundle *)bundle
                             resourceName:(NSString *)resourceName
                                extension:(NSString *)extension;
- (NSImage *)preferenceCoverImageInResourceDirectory:(NSURL *)resourceDirectory
                                       resourceName:(NSString *)resourceName
                                          extension:(NSString *)extension;

@end

@implementation PurrTypePreferencesWindowController

+ (instancetype)sharedController {
    static PurrTypePreferencesWindowController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[PurrTypePreferencesWindowController alloc] init];
    });
    return controller;
}

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, MKPreferencesWindowWidth, MKPreferencesWindowHeight)
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _selectedTab = MKPreferencesTabGeneral;
        _quickPhraseStore = [PurrTypeQuickPhraseStore defaultStore];
        _backupStore = [PurrTypeBackupStore defaultStore];
        _tabIdentifiers = @[MKPreferencesTabGeneral,
                            MKPreferencesTabInputModes,
                            MKPreferencesTabTyping,
                            MKPreferencesTabPrivacyLearning,
                            MKPreferencesTabAbout];
        _sidebarButtonsByIdentifier = [NSMutableDictionary dictionary];
        _preferenceCoverImagesByFilename = [NSMutableDictionary dictionary];
        window.title = [self localizedString:@"PurrType Settings"];
        window.minSize = NSMakeSize(MKPreferencesMinimumWindowWidth, MKPreferencesMinimumWindowHeight);
        window.contentMinSize = NSMakeSize(MKPreferencesMinimumWindowWidth, MKPreferencesMinimumWindowHeight);
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        window.backgroundColor = MKPreferencesWindowBackgroundColor();
        window.titlebarAppearsTransparent = NO;
        window.movableByWindowBackground = NO;
        [self buildWindowContent];
    }
    return self;
}

- (void)showWithEngine:(nullable PurrTypeEngine *)engine
              delegate:(id<PurrTypePreferencesWindowControllerDelegate>)delegate {
    self.engine = engine;
    self.preferencesDelegate = delegate;
    [self reloadState];
    [self normalizeWindowContentSize];
    [self showWindow:nil];
    [self.window center];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)reloadState {
    self.window.title = [self localizedString:@"PurrType Settings"];
    [self rebuildSidebar];
    [self rebuildContent];
    [self normalizeWindowContentSize];
}

- (void)buildWindowContent {
    MKPreferencesRootView *root = [[MKPreferencesRootView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = YES;
    self.window.contentView = root;

    MKPreferencesFillView *sidebar = [[MKPreferencesFillView alloc] initWithFrame:NSZeroRect];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    sidebar.fillColor = MKPreferencesSidebarBackgroundColor();
    [root addSubview:sidebar];

    self.sidebarContainer = sidebar;

    self.contentContainer = [[MKPreferencesFillView alloc] initWithFrame:NSZeroRect];
    ((MKPreferencesFillView *)self.contentContainer).fillColor = MKPreferencesContentBackgroundColor();
    self.contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.contentContainer];

    [NSLayoutConstraint activateConstraints:@[
        [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor],
        [sidebar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:MKPreferencesSidebarWidth],

        [self.contentContainer.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.contentContainer.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [self.contentContainer.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.contentContainer.bottomAnchor constraintEqualToAnchor:root.bottomAnchor]
    ]];
}

- (void)normalizeWindowContentSize {
    NSSize targetSize = MKPreferencesStandardContentSize();
    NSRect currentFrame = self.window.frame;
    NSRect currentContentRect = [self.window contentRectForFrameRect:currentFrame];
    if (fabs(NSWidth(currentContentRect) - targetSize.width) < 0.5 &&
        fabs(NSHeight(currentContentRect) - targetSize.height) < 0.5) {
        return;
    }

    NSRect targetContentRect = currentContentRect;
    targetContentRect.size = targetSize;
    NSRect targetFrame = [self.window frameRectForContentRect:targetContentRect];
    targetFrame.origin.x = NSMinX(currentFrame);
    targetFrame.origin.y = NSMaxY(currentFrame) - NSHeight(targetFrame);
    [self.window setFrame:targetFrame display:self.window.visible animate:NO];
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)sidebarItems {
    return @[
        @{@"id": MKPreferencesTabGeneral, @"title": [self localizedString:@"General"], @"symbol": @"house"},
        @{@"id": MKPreferencesTabInputModes, @"title": [self localizedString:@"Input Modes"], @"symbol": @"keyboard"},
        @{@"id": MKPreferencesTabTyping, @"title": [self localizedString:@"Typing"], @"symbol": @"character.cursor.ibeam"},
        @{@"id": MKPreferencesTabPrivacyLearning, @"title": [self localizedString:@"Privacy & Learning"], @"symbol": @"shield"},
        @{@"id": MKPreferencesTabAbout, @"title": [self localizedString:@"About"], @"symbol": @"info.circle"}
    ];
}

- (void)rebuildSidebar {
    for (NSView *view in self.sidebarContainer.subviews) {
        [view removeFromSuperview];
    }
    [self.sidebarButtonsByIdentifier removeAllObjects];

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [self appIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.wantsLayer = YES;
    icon.layer.cornerRadius = 10.0;
    icon.layer.masksToBounds = YES;

    NSTextField *title = [self labelWithText:[self localizedString:@"PurrType"] size:16 weight:NSFontWeightBold color:MKPreferencesPrimaryTextColor()];
    NSTextField *status = [self labelWithText:[self localizedString:@"Active"] size:11 weight:NSFontWeightRegular color:MKPreferencesSecondaryTextColor()];
    NSView *statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    statusDot.wantsLayer = YES;
    statusDot.layer.backgroundColor = NSColor.systemGreenColor.CGColor;
    statusDot.layer.cornerRadius = 4.0;

    NSStackView *statusRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusRow.alignment = NSLayoutAttributeCenterY;
    statusRow.spacing = 6.0;
    [statusRow addArrangedSubview:statusDot];
    [statusRow addArrangedSubview:status];

    NSStackView *headerText = [self verticalStackWithSpacing:3];
    headerText.alignment = NSLayoutAttributeLeading;
    [headerText addArrangedSubview:title];
    [headerText addArrangedSubview:statusRow];

    NSStackView *header = [[NSStackView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = MKPreferencesSidebarHeaderSpacing;
    [header addArrangedSubview:icon];
    [header addArrangedSubview:headerText];

    NSStackView *stack = [self verticalStackWithSpacing:10];
    stack.alignment = NSLayoutAttributeLeading;

    [self.sidebarContainer addSubview:header];
    [self.sidebarContainer addSubview:stack];

    NSArray<NSDictionary<NSString *, NSString *> *> *items = [self sidebarItems];
    for (NSUInteger index = 0; index < items.count; index += 1) {
        NSDictionary<NSString *, NSString *> *item = items[index];
        NSString *identifier = item[@"id"] ?: @"";
        MKPreferencesSidebarButton *button = [[MKPreferencesSidebarButton alloc] initWithFrame:NSZeroRect];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.title = item[@"title"] ?: @"";
        button.image = [NSImage imageWithSystemSymbolName:item[@"symbol"] ?: @"gearshape"
                                   accessibilityDescription:button.title];
        button.target = self;
        button.action = @selector(sidebarButtonClicked:);
        button.tag = (NSInteger)index;
        button.selectedItem = [identifier isEqualToString:self.selectedTab ?: MKPreferencesTabGeneral];
        NSColor *itemColor = button.selectedItem ? MKPreferencesAccentActiveColor() : MKPreferencesPrimaryTextColor();
        button.contentTintColor = itemColor;
        button.attributedTitle = [[NSAttributedString alloc] initWithString:button.title
                                                                 attributes:@{
            NSFontAttributeName: button.font ?: MKFont(12, NSFontWeightSemibold),
            NSForegroundColorAttributeName: itemColor
        }];
        [button.heightAnchor constraintEqualToConstant:32].active = YES;
        [button.widthAnchor constraintEqualToConstant:MKPreferencesSidebarWidth - (MKPreferencesSidebarItemInset * 2.0)].active = YES;
        [stack addArrangedSubview:button];
        self.sidebarButtonsByIdentifier[identifier] = button;
    }

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:self.sidebarContainer.leadingAnchor constant:MKPreferencesSidebarTitleInset],
        [header.trailingAnchor constraintLessThanOrEqualToAnchor:self.sidebarContainer.trailingAnchor constant:-MKPreferencesSidebarTitleTrailingInset],
        [header.topAnchor constraintEqualToAnchor:self.sidebarContainer.topAnchor constant:28],
        [icon.widthAnchor constraintEqualToConstant:MKPreferencesSidebarHeaderIconSize],
        [icon.heightAnchor constraintEqualToConstant:MKPreferencesSidebarHeaderIconSize],
        [statusDot.widthAnchor constraintEqualToConstant:8],
        [statusDot.heightAnchor constraintEqualToConstant:8],
        [stack.leadingAnchor constraintEqualToAnchor:self.sidebarContainer.leadingAnchor constant:MKPreferencesSidebarItemInset],
        [stack.trailingAnchor constraintEqualToAnchor:self.sidebarContainer.trailingAnchor constant:-MKPreferencesSidebarItemInset],
        [stack.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:26]
    ]];
}

- (void)sidebarButtonClicked:(MKPreferencesSidebarButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)self.tabIdentifiers.count) {
        return;
    }
    self.selectedTab = self.tabIdentifiers[(NSUInteger)index];
    [self reloadState];
}

- (void)rebuildContent {
    for (NSView *view in self.contentContainer.subviews) {
        [view removeFromSuperview];
    }

    NSView *content = nil;
    if ([self.selectedTab isEqualToString:MKPreferencesTabGeneral]) {
        content = [self generalView];
    } else if ([self.selectedTab isEqualToString:MKPreferencesTabInputModes]) {
        content = [self inputModesView];
    } else if ([self.selectedTab isEqualToString:MKPreferencesTabTyping]) {
        content = [self typingView];
    } else if ([self.selectedTab isEqualToString:MKPreferencesTabPrivacyLearning]) {
        content = [self privacyLearningView];
    } else if ([self.selectedTab isEqualToString:MKPreferencesTabAbout]) {
        content = [self aboutView];
    } else {
        self.selectedTab = MKPreferencesTabGeneral;
        content = [self generalView];
    }

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.drawsBackground = YES;
    scrollView.backgroundColor = MKPreferencesContentBackgroundColor();
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autohidesScrollers = YES;
    scrollView.scrollerStyle = NSScrollerStyleOverlay;
    scrollView.borderType = NSNoBorder;
    [self.contentContainer addSubview:scrollView];

    content.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.documentView = content;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.contentContainer.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.contentContainer.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.contentContainer.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.contentContainer.bottomAnchor],

        [content.leadingAnchor constraintEqualToAnchor:scrollView.contentView.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scrollView.contentView.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:scrollView.contentView.topAnchor],
        [content.widthAnchor constraintEqualToAnchor:scrollView.contentView.widthAnchor],
        [content.heightAnchor constraintGreaterThanOrEqualToAnchor:scrollView.contentView.heightAnchor]
    ]];
    [content setNeedsLayout:YES];
    [content layoutSubtreeIfNeeded];
}

- (void)rebuildContentPreservingScrollPosition {
    NSPoint scrollOrigin = NSZeroPoint;
    for (NSView *view in self.contentContainer.subviews) {
        if ([view isKindOfClass:[NSScrollView class]]) {
            scrollOrigin = ((NSScrollView *)view).contentView.bounds.origin;
            break;
        }
    }
    [self rebuildContent];
    for (NSView *view in self.contentContainer.subviews) {
        if ([view isKindOfClass:[NSScrollView class]]) {
            NSScrollView *scrollView = (NSScrollView *)view;
            [scrollView.contentView scrollToPoint:scrollOrigin];
            [scrollView reflectScrolledClipView:scrollView.contentView];
            break;
        }
    }
}

- (NSView *)generalView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_general.png"
                                             title:[self localizedString:@"General"]]
           toStack:stack];
    [self addContentView:[self overviewCard] toStack:stack];
    [self addContentView:[self currentModeCard] toStack:stack];
    [self addContentView:[self globalShortcutsCard] toStack:stack];
    [self addContentView:[self candidatePanelCard] toStack:stack];
    [self addContentView:[self generalBehaviorCard] toStack:stack];
    return view;
}

- (NSView *)inputModesView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_input_modes.png"
	                                             title:[self localizedString:@"Input Modes"]]
	           toStack:stack];
    [self addContentView:[self inputModeSettingsCard] toStack:stack];
    return view;
}

- (NSView *)typingView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_typing.png"
                                             title:[self localizedString:@"Typing"]]
               toStack:stack];
    [self addContentView:[self compositionCard] toStack:stack];
    [self addContentView:[self voiceInputCard] toStack:stack];
    [self addContentView:[self englishPassThroughCard] toStack:stack];
    [self addContentView:[self associationCard] toStack:stack];
    [self addContentView:[self quickPhrasesCard] toStack:stack];
    return view;
}

- (NSView *)privacyLearningView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_privacy_learning.png"
	                                             title:[self localizedString:@"Privacy & Learning"]]
	           toStack:stack];
    [self addContentView:[self learningCard] toStack:stack];
    [self addContentView:[self privacyLockSettingsCard] toStack:stack];
    [self addContentView:[self dataCard] toStack:stack];
    [self addContentView:[self backupRestoreCard] toStack:stack];
    return view;
}

- (NSView *)aboutView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_about.png"
	                                             title:[self localizedString:@"About"]]
	           toStack:stack];
    [self addContentView:[self appIdentityCard] toStack:stack];
    NSView *linksCard = [self linksCard];
    if (linksCard) {
        [self addContentView:linksCard toStack:stack];
    }
    [self addContentView:[self madeByCard] toStack:stack];
    return view;
}

- (void)addContentView:(NSView *)contentView toStack:(NSStackView *)stack {
    [stack addArrangedSubview:contentView];
    [contentView.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
}

- (void)addCoverView:(NSView *)coverView toStack:(NSStackView *)stack {
    NSView *layoutView = [[NSView alloc] initWithFrame:NSZeroRect];
    layoutView.translatesAutoresizingMaskIntoConstraints = NO;
    [layoutView addSubview:coverView];
    [stack addArrangedSubview:layoutView];
    [layoutView.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;

    NSLayoutConstraint *matchAvailableWidth = [coverView.widthAnchor constraintEqualToAnchor:layoutView.widthAnchor];
    matchAvailableWidth.priority = NSLayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [coverView.topAnchor constraintEqualToAnchor:layoutView.topAnchor],
        [coverView.bottomAnchor constraintEqualToAnchor:layoutView.bottomAnchor],
        [coverView.centerXAnchor constraintEqualToAnchor:layoutView.centerXAnchor],
        [coverView.widthAnchor constraintLessThanOrEqualToAnchor:layoutView.widthAnchor],
        [coverView.widthAnchor constraintLessThanOrEqualToConstant:MKPreferencesCoverMaxWidth],
        matchAvailableWidth
    ]];
}

- (NSImage *)bundledPreferenceCoverNamed:(NSString *)filename {
    NSString *cacheKey = filename ?: @"";
    NSImage *cachedImage = self.preferenceCoverImagesByFilename[cacheKey];
    if (cachedImage) {
        return cachedImage;
    }

    NSString *extension = filename.pathExtension.length > 0 ? filename.pathExtension : @"png";
    NSString *resourceName = filename.pathExtension.length > 0 ? [filename stringByDeletingPathExtension] : filename;
    NSImage *image = [self preferenceCoverImageInBundle:[NSBundle mainBundle]
                                           resourceName:resourceName
                                              extension:extension];
    if (image) {
        self.preferenceCoverImagesByFilename[cacheKey] = image;
        return image;
    }

    NSURL *helperURL = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"PurrTypePreferences.app"
                                                                            isDirectory:YES];
    NSBundle *helperBundle = [NSBundle bundleWithURL:helperURL];
    image = [self preferenceCoverImageInBundle:helperBundle
                                  resourceName:resourceName
                                     extension:extension];
    if (image) {
        self.preferenceCoverImagesByFilename[cacheKey] = image;
        return image;
    }

    NSURL *parentResourceURL = [[[NSBundle mainBundle] bundleURL] URLByDeletingLastPathComponent];
    image = [self preferenceCoverImageInResourceDirectory:parentResourceURL
                                             resourceName:resourceName
                                                extension:extension];
    if (image) {
        self.preferenceCoverImagesByFilename[cacheKey] = image;
    }
    return image;
}

- (NSImage *)preferenceCoverImageInBundle:(NSBundle *)bundle
                             resourceName:(NSString *)resourceName
                                extension:(NSString *)extension {
    NSURL *url = [bundle URLForResource:resourceName
                          withExtension:extension
                           subdirectory:@"PreferenceCovers"];
    return url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
}

- (NSImage *)preferenceCoverImageInResourceDirectory:(NSURL *)resourceDirectory
                                       resourceName:(NSString *)resourceName
                                          extension:(NSString *)extension {
    if (!resourceDirectory) {
        return nil;
    }

    NSString *filename = [resourceName stringByAppendingPathExtension:extension];
    NSURL *url = [[[resourceDirectory URLByAppendingPathComponent:@"PreferenceCovers" isDirectory:YES]
                   URLByAppendingPathComponent:filename]
                  URLByStandardizingPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        return nil;
    }
    return [[NSImage alloc] initWithContentsOfURL:url];
}

- (NSView *)coverCardWithFilename:(NSString *)filename
                            title:(NSString *)title {
    MKPreferencesCoverView *cover = [[MKPreferencesCoverView alloc] initWithFrame:NSZeroRect];
    cover.translatesAutoresizingMaskIntoConstraints = NO;
    cover.image = [self bundledPreferenceCoverNamed:filename];
    cover.fallbackTitle = title ?: @"";
    cover.radius = 14.0;
    cover.fillColor = MKPreferencesCardBackgroundColor();
    [cover.heightAnchor constraintEqualToAnchor:cover.widthAnchor
                                     multiplier:(1.0 / MKPreferencesCoverAspectRatio)].active = YES;
    return cover;
}

- (NSImage *)appIconImage {
    if (self.cachedAppIconImage) {
        return self.cachedAppIconImage;
    }

    NSImage *image = [NSImage imageNamed:@"PurrType"];
    if (image) {
        self.cachedAppIconImage = image;
        return image;
    }

    NSURL *icnsURL = [[NSBundle mainBundle] URLForResource:@"PurrType" withExtension:@"icns"];
    if (icnsURL) {
        self.cachedAppIconImage = [[NSImage alloc] initWithContentsOfURL:icnsURL];
        return self.cachedAppIconImage;
    }

    NSURL *pngURL = [[NSBundle mainBundle] URLForResource:@"PurrType" withExtension:@"png"];
    if (pngURL) {
        self.cachedAppIconImage = [[NSImage alloc] initWithContentsOfURL:pngURL];
        return self.cachedAppIconImage;
    }

    self.cachedAppIconImage = [NSImage imageWithSystemSymbolName:@"keyboard" accessibilityDescription:[self localizedString:@"PurrType"]];
    return self.cachedAppIconImage;
}

- (NSView *)overviewCard {
    MKPreferencesCardView *card = [self cardViewWithHeight:118];

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [self appIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.wantsLayer = YES;
    icon.layer.cornerRadius = 10.0;
    icon.layer.masksToBounds = YES;

    NSTextField *title = [self labelWithText:[self localizedString:@"PurrType"]
                                        size:16
                                      weight:NSFontWeightBold
                                       color:MKPreferencesPrimaryTextColor()];
    NSTextField *description = [self wrappingLabelWithText:[self localizedString:@"Open-source Traditional Chinese input method for macOS."]
                                                      size:12
                                                    weight:NSFontWeightRegular
                                                     color:MKPreferencesSecondaryTextColor()];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: [self localizedString:@"development"];
    NSTextField *versionLabel = [self labelWithText:[NSString stringWithFormat:@"%@ %@", [self localizedString:@"Version"], version]
                                               size:12
                                             weight:NSFontWeightSemibold
                                              color:MKPreferencesPrimaryTextColor()];

    [card addSubview:icon];
    [card addSubview:title];
    [card addSubview:description];
    [card addSubview:versionLabel];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [icon.widthAnchor constraintEqualToConstant:44],
        [icon.heightAnchor constraintEqualToConstant:44],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:14],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [description.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [description.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [description.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [versionLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [versionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [versionLabel.topAnchor constraintEqualToAnchor:description.bottomAnchor constant:6]
    ]];
    return card;
}

- (NSView *)enabledInputModesCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Enabled Input Modes"]
                                                         symbol:@"checkmark.circle"
                                                         height:230
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    for (NSUInteger index = 0; index < modes.count; index += 1) {
        NSString *mode = modes[index];
        MKPreferencesSwitchControl *toggle = [self switchControlWithState:[self isInputModeEnabled:mode]
                                                                   action:@selector(inputModeSwitchChanged:)];
        toggle.tag = MKPreferencesInputModeSwitchTagBase + (NSInteger)index;
        [stack addArrangedSubview:[self settingRowWithTitle:[self titleForInputMode:mode]
                                                     detail:nil
                                                    control:toggle
                                                    enabled:YES]];
    }

    self.enabledInputModesNoticeField = [self wrappingLabelWithText:@""
                                                               size:11
                                                             weight:NSFontWeightRegular
                                                              color:MKPreferencesAccentActiveColor()];
    [self.enabledInputModesNoticeField.heightAnchor constraintGreaterThanOrEqualToConstant:16.0].active = YES;
    self.enabledInputModesNoticeField.hidden = YES;
    [stack addArrangedSubview:self.enabledInputModesNoticeField];
    return card;
}

- (NSView *)globalShortcutsCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Global Shortcuts"]
                                                         symbol:@"keyboard.badge.ellipsis"
                                                         height:150
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Switch Input Mode"]
                                                 detail:nil
                                                control:[self shortcutEditorWithSpec:[self.preferencesDelegate preferencesSwitchInputModeShortcut]
                                                                          defaultSpec:[PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec]
                                                                                  tag:MKPreferencesShortcutTagSwitchInputMode]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Pause Learning"]
                                                 detail:nil
                                                control:[self shortcutEditorWithSpec:[self.preferencesDelegate preferencesPrivacyLockShortcut]
                                                                          defaultSpec:[PurrTypeInputBehavior defaultPrivacyLockShortcutSpec]
                                                                                  tag:MKPreferencesShortcutTagPrivacyLock]
                                                enabled:YES]];
    self.shortcutErrorField = [self wrappingLabelWithText:@""
                                                     size:11
                                                   weight:NSFontWeightRegular
                                                    color:NSColor.systemRedColor];
    self.shortcutErrorField.hidden = YES;
    [stack addArrangedSubview:self.shortcutErrorField];
    return card;
}

- (NSView *)candidatePanelCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Candidate Window"]
                                                         symbol:@"list.bullet.rectangle"
                                                         height:264
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];

    self.candidatePanelOrientationSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.candidatePanelOrientationSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.candidatePanelOrientationSegmentedControl.segmentCount = 2;
    self.candidatePanelOrientationSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.candidatePanelOrientationSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.candidatePanelOrientationSegmentedControl.controlSize = NSControlSizeRegular;
    self.candidatePanelOrientationSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.candidatePanelOrientationSegmentedControl setLabel:[self localizedString:@"Vertical"] forSegment:0];
    [self.candidatePanelOrientationSegmentedControl setLabel:[self localizedString:@"Horizontal"] forSegment:1];
    [self.candidatePanelOrientationSegmentedControl setWidth:72 forSegment:0];
    [self.candidatePanelOrientationSegmentedControl setWidth:80 forSegment:1];
    self.candidatePanelOrientationSegmentedControl.target = self;
    self.candidatePanelOrientationSegmentedControl.action = @selector(candidatePanelOrientationSegmentChanged:);
    [self syncCandidatePanelOrientationSegment];
    [self.candidatePanelOrientationSegmentedControl.widthAnchor constraintEqualToConstant:152].active = YES;
    [self.candidatePanelOrientationSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Direction"]
                                                 detail:nil
                                                control:self.candidatePanelOrientationSegmentedControl
                                                enabled:YES]];

    self.candidatePageSizeSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.candidatePageSizeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.candidatePageSizeSegmentedControl.segmentCount = 2;
    self.candidatePageSizeSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.candidatePageSizeSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.candidatePageSizeSegmentedControl.controlSize = NSControlSizeRegular;
    self.candidatePageSizeSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.candidatePageSizeSegmentedControl setLabel:@"5" forSegment:0];
    [self.candidatePageSizeSegmentedControl setLabel:@"9" forSegment:1];
    [self.candidatePageSizeSegmentedControl setWidth:58 forSegment:0];
    [self.candidatePageSizeSegmentedControl setWidth:58 forSegment:1];
    self.candidatePageSizeSegmentedControl.target = self;
    self.candidatePageSizeSegmentedControl.action = @selector(candidatePageSizeSegmentChanged:);
    [self syncCandidatePageSizeSegment];
    [self.candidatePageSizeSegmentedControl.widthAnchor constraintEqualToConstant:116].active = YES;
    [self.candidatePageSizeSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Candidates per page"]
                                                 detail:nil
                                                control:self.candidatePageSizeSegmentedControl
                                                enabled:YES]];

    self.spaceKeySegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.spaceKeySegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.spaceKeySegmentedControl.segmentCount = 2;
    self.spaceKeySegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.spaceKeySegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.spaceKeySegmentedControl.controlSize = NSControlSizeRegular;
    self.spaceKeySegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.spaceKeySegmentedControl setLabel:[self localizedString:@"Commit"] forSegment:0];
    [self.spaceKeySegmentedControl setLabel:[self localizedString:@"Page"] forSegment:1];
    [self.spaceKeySegmentedControl setWidth:68 forSegment:0];
    [self.spaceKeySegmentedControl setWidth:58 forSegment:1];
    self.spaceKeySegmentedControl.target = self;
    self.spaceKeySegmentedControl.action = @selector(spaceKeySegmentChanged:);
    self.spaceKeySegmentedControl.selectedSegment = [self.preferencesDelegate preferencesSpacePagingEnabled] ? 1 : 0;
    [self.spaceKeySegmentedControl.widthAnchor constraintEqualToConstant:126].active = YES;
    [self.spaceKeySegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Default Space key"]
                                                 detail:nil
                                                control:self.spaceKeySegmentedControl
                                                enabled:YES]];

    self.candidatePanelFontSizeSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.candidatePanelFontSizeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.candidatePanelFontSizeSegmentedControl.segmentCount = 3;
    self.candidatePanelFontSizeSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.candidatePanelFontSizeSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.candidatePanelFontSizeSegmentedControl.controlSize = NSControlSizeRegular;
    self.candidatePanelFontSizeSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.candidatePanelFontSizeSegmentedControl setLabel:[self localizedString:@"Small"] forSegment:0];
    [self.candidatePanelFontSizeSegmentedControl setLabel:[self localizedString:@"Medium"] forSegment:1];
    [self.candidatePanelFontSizeSegmentedControl setLabel:[self localizedString:@"Large"] forSegment:2];
    [self.candidatePanelFontSizeSegmentedControl setWidth:52 forSegment:0];
    [self.candidatePanelFontSizeSegmentedControl setWidth:62 forSegment:1];
    [self.candidatePanelFontSizeSegmentedControl setWidth:52 forSegment:2];
    self.candidatePanelFontSizeSegmentedControl.target = self;
    self.candidatePanelFontSizeSegmentedControl.action = @selector(candidatePanelFontSizeSegmentChanged:);
    [self syncCandidatePanelFontSizeSegment];
    [self.candidatePanelFontSizeSegmentedControl.widthAnchor constraintEqualToConstant:166].active = YES;
    [self.candidatePanelFontSizeSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Candidate font size"]
                                                 detail:nil
                                                control:self.candidatePanelFontSizeSegmentedControl
                                                enabled:YES]];

    self.candidatePanelHighlightPopupButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.candidatePanelHighlightPopupButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.candidatePanelHighlightPopupButton.controlSize = NSControlSizeRegular;
    self.candidatePanelHighlightPopupButton.font = MKFont(12, NSFontWeightRegular);
    self.candidatePanelHighlightPopupButton.target = self;
    self.candidatePanelHighlightPopupButton.action = @selector(candidatePanelHighlightPopupChanged:);
    [self configureCandidatePanelHighlightPopup];
    [self syncCandidatePanelHighlightPopup];
    [self.candidatePanelHighlightPopupButton.widthAnchor constraintEqualToConstant:150].active = YES;
    [self.candidatePanelHighlightPopupButton.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Highlight color"]
                                                 detail:nil
                                                control:self.candidatePanelHighlightPopupButton
                                                enabled:YES]];
    return card;
}

- (NSView *)generalBehaviorCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"General Behavior"]
                                                         symbol:@"gearshape"
                                                         height:126
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.preferencesLanguageSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.preferencesLanguageSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.preferencesLanguageSegmentedControl.segmentCount = 3;
    self.preferencesLanguageSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.preferencesLanguageSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.preferencesLanguageSegmentedControl.controlSize = NSControlSizeRegular;
    self.preferencesLanguageSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.preferencesLanguageSegmentedControl setLabel:[self localizedString:@"System"] forSegment:0];
    [self.preferencesLanguageSegmentedControl setLabel:[self localizedString:@"English"] forSegment:1];
    [self.preferencesLanguageSegmentedControl setLabel:[self localizedString:@"Traditional Chinese"] forSegment:2];
    [self.preferencesLanguageSegmentedControl setWidth:54 forSegment:0];
    [self.preferencesLanguageSegmentedControl setWidth:62 forSegment:1];
    [self.preferencesLanguageSegmentedControl setWidth:92 forSegment:2];
    self.preferencesLanguageSegmentedControl.target = self;
    self.preferencesLanguageSegmentedControl.action = @selector(preferencesLanguageSegmentChanged:);
    [self syncPreferencesLanguageSegment];
    [self.preferencesLanguageSegmentedControl.widthAnchor constraintEqualToConstant:208].active = YES;
    [self.preferencesLanguageSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self leadingAlignedView:self.preferencesLanguageSegmentedControl height:30.0]];
    self.generalBehaviorStatusField = [self statusLabel];
    [stack addArrangedSubview:self.generalBehaviorStatusField];
    return card;
}

- (NSView *)iconTileWithSymbol:(NSString *)symbol accessibilityDescription:(NSString *)description {
    NSView *tile = [[NSView alloc] initWithFrame:NSZeroRect];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.wantsLayer = YES;
    tile.layer.backgroundColor = MKPreferencesSelectedSidebarColor().CGColor;
    tile.layer.cornerRadius = 9.0;

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [NSImage imageWithSystemSymbolName:symbol ?: @"gearshape"
                           accessibilityDescription:description];
    icon.contentTintColor = MKPreferencesAccentColor();
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightSemibold];
    [tile addSubview:icon];

    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:40],
        [tile.heightAnchor constraintEqualToConstant:40],
        [icon.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22]
    ]];
    return tile;
}

- (MKPreferencesCardView *)preferenceCardWithTitle:(NSString *)title
                                            symbol:(NSString *)symbol
                                            height:(CGFloat)height
                                        titleLabel:(NSTextField **)titleLabelOut {
    MKPreferencesCardView *card = [self cardViewWithHeight:height];
    NSView *icon = [self iconTileWithSymbol:symbol accessibilityDescription:title];
    NSTextField *titleLabel = [self labelWithText:title size:15 weight:NSFontWeightSemibold color:MKPreferencesPrimaryTextColor()];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                         forOrientation:NSLayoutConstraintOrientationVertical];
    [titleLabel setContentHuggingPriority:NSLayoutPriorityRequired
                           forOrientation:NSLayoutConstraintOrientationVertical];
    [card addSubview:icon];
    [card addSubview:titleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [icon.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:14],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [titleLabel.heightAnchor constraintGreaterThanOrEqualToConstant:24]
    ]];
    if (titleLabelOut) {
        *titleLabelOut = titleLabel;
    }
    return card;
}

- (NSStackView *)bodyStackInCard:(MKPreferencesCardView *)card belowTitle:(NSTextField *)titleLabel {
    NSStackView *stack = [self verticalStackWithSpacing:8];
    stack.alignment = NSLayoutAttributeWidth;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    return stack;
}

- (NSView *)settingRowWithTitle:(NSString *)title detail:(NSString *)detail control:(NSView *)control enabled:(BOOL)enabled {
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    BOOL hasDetail = detail.length > 0;
    BOOL isShortcutEditor = [control.identifier isEqualToString:MKPreferencesShortcutEditorIdentifier];
    BOOL controlStacksVertically = control &&
                                   !isShortcutEditor &&
                                   [control isKindOfClass:[NSStackView class]];
    NSTextField *titleLabel = [self labelWithText:title
                                             size:12
                                           weight:NSFontWeightRegular
                                            color:(enabled ? MKPreferencesPrimaryTextColor() : MKPreferencesSecondaryTextColor())];
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
    [titleLabel setContentHuggingPriority:NSLayoutPriorityDefaultHigh
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSTextField *detailLabel = [self wrappingLabelWithText:detail ?: @""
                                                      size:11
                                                    weight:NSFontWeightRegular
                                                     color:MKPreferencesSecondaryTextColor()];
    if ([title isEqualToString:[self localizedString:@"Pause learning immediately"]]) {
        self.privacyLockStatusField = detailLabel;
    }
    [detailLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
    detailLabel.maximumNumberOfLines = 2;
    [row addSubview:titleLabel];
    if (hasDetail) {
        [row addSubview:detailLabel];
    }
    if (control) {
        control.translatesAutoresizingMaskIntoConstraints = NO;
        if (!enabled) {
            [self setControlsInView:control enabled:NO];
        }
        [control setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
        [row addSubview:control];
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:(controlStacksVertically ? (hasDetail ? 78 : 56) : (hasDetail ? 40 : 30))],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:(hasDetail || controlStacksVertically ? 1 : 5)]
    ] mutableCopy];

    if (hasDetail) {
        [constraints addObjectsFromArray:@[
            [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
            [detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:(controlStacksVertically || !control) ? row.trailingAnchor : control.leadingAnchor
                                                                  constant:(controlStacksVertically || !control) ? 0 : -12],
            [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
            [detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor]
        ]];
    } else if (!controlStacksVertically) {
        [constraints addObject:[titleLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]];
    }

    if (control) {
        if (controlStacksVertically) {
            [constraints addObjectsFromArray:@[
                [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
                [control.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [control.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
                [control.topAnchor constraintEqualToAnchor:(hasDetail ? detailLabel.bottomAnchor : titleLabel.bottomAnchor) constant:7],
                [control.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor]
            ]];
        } else {
            [constraints addObjectsFromArray:@[
                [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:control.leadingAnchor constant:-12],
                [control.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
                [control.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
            ]];
        }
    } else {
        [constraints addObject:[titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor]];
    }

    [NSLayoutConstraint activateConstraints:constraints];
    return row;
}

- (NSView *)leadingAlignedView:(NSView *)content height:(CGFloat)height {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:height],
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor],
        [content.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor],
        [content.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor]
    ]];
    return container;
}

- (void)setControlsInView:(NSView *)view enabled:(BOOL)enabled {
    if ([view isKindOfClass:[NSControl class]]) {
        ((NSControl *)view).enabled = enabled;
    }
    for (NSView *subview in view.subviews) {
        [self setControlsInView:subview enabled:enabled];
    }
}

- (NSView *)readOnlyChipWithText:(NSString *)text {
    NSView *chip = [[NSView alloc] initWithFrame:NSZeroRect];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    chip.wantsLayer = YES;
    chip.layer.backgroundColor = MKPreferencesSelectedSidebarColor().CGColor;
    chip.layer.borderColor = MKPreferencesBorderColor().CGColor;
    chip.layer.borderWidth = 1.0;
    chip.layer.cornerRadius = 7.0;

    NSTextField *label = [self labelWithText:text size:11 weight:NSFontWeightSemibold color:MKPreferencesPrimaryTextColor()];
    label.alignment = NSTextAlignmentCenter;
    [chip addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [chip.heightAnchor constraintEqualToConstant:26],
        [chip.widthAnchor constraintGreaterThanOrEqualToConstant:64],
        [label.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor constant:9],
        [label.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:-9],
        [label.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor]
    ]];
    return chip;
}

- (NSView *)shortcutEditorWithSpec:(NSString *)shortcutSpec defaultSpec:(NSString *)defaultSpec tag:(NSInteger)tag {
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.identifier = MKPreferencesShortcutEditorIdentifier;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 6.0;

    MKPreferencesShortcutRecorderControl *recorder = [[MKPreferencesShortcutRecorderControl alloc] initWithFrame:NSZeroRect];
    recorder.translatesAutoresizingMaskIntoConstraints = NO;
    recorder.shortcutSpec = shortcutSpec ?: defaultSpec;
    recorder.target = self;
    recorder.action = @selector(shortcutRecorderChanged:);
    recorder.tag = tag;
    recorder.allowsDoubleTapBacktick = (tag == MKPreferencesShortcutTagPrivacyLock);
    recorder.recordingPrompt = [self localizedString:@"Press shortcut..."];
    recorder.secondBacktickPrompt = [self localizedString:@"Press ` again..."];
    [recorder.widthAnchor constraintEqualToConstant:142].active = YES;
    [recorder.heightAnchor constraintEqualToConstant:30].active = YES;
    [row addArrangedSubview:recorder];

    NSButton *reset = [self secondaryButtonWithTitle:[self localizedString:@"Reset"] action:@selector(shortcutResetButtonClicked:)];
    reset.tag = tag;
    [reset.heightAnchor constraintEqualToConstant:28].active = YES;
    [reset.widthAnchor constraintEqualToConstant:54].active = YES;
    [row addArrangedSubview:reset];
    if (tag >= MKPreferencesShortcutTagModeBase && tag < MKPreferencesShortcutTagModeBase + 4) {
        self.modeShortcutRecorderControl = recorder;
        self.modeShortcutResetButton = reset;
    }

    [row.widthAnchor constraintEqualToConstant:202].active = YES;
    return row;
}

- (NSView *)privacyShortcutReferenceControl {
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.identifier = MKPreferencesShortcutEditorIdentifier;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 6.0;
    MKPreferencesShortcutRecorderControl *display = [[MKPreferencesShortcutRecorderControl alloc] initWithFrame:NSZeroRect];
    display.translatesAutoresizingMaskIntoConstraints = NO;
    display.enabled = NO;
    display.shortcutSpec = [self.preferencesDelegate preferencesPrivacyLockShortcut];
    [display.widthAnchor constraintEqualToConstant:126].active = YES;
    [display.heightAnchor constraintEqualToConstant:30].active = YES;
    [row addArrangedSubview:display];
    NSButton *edit = [self secondaryButtonWithTitle:[self localizedString:@"Edit in General"] action:@selector(editPrivacyShortcutInGeneral:)];
    [edit.heightAnchor constraintEqualToConstant:28].active = YES;
    [edit.widthAnchor constraintEqualToConstant:54].active = YES;
    [row addArrangedSubview:edit];
    [row.widthAnchor constraintEqualToConstant:186].active = YES;
    return row;
}

- (NSView *)buttonRowWithButtons:(NSArray<NSButton *> *)buttons {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8.0;
    [row setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
    for (NSButton *button in buttons) {
        [button setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button setContentHuggingPriority:NSLayoutPriorityRequired
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:[self minimumButtonWidthForTitle:button.title]].active = YES;
        [row addArrangedSubview:button];
    }
    [container addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],
        [row.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [row.topAnchor constraintEqualToAnchor:container.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor]
    ]];
    return container;
}

- (NSView *)horizontalButtonRowWithButtons:(NSArray<NSButton *> *)buttons {
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8.0;
    [row setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                  forOrientation:NSLayoutConstraintOrientationHorizontal];
    for (NSButton *button in buttons) {
        [button setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button setContentHuggingPriority:NSLayoutPriorityRequired
                           forOrientation:NSLayoutConstraintOrientationHorizontal];
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:[self minimumButtonWidthForTitle:button.title]].active = YES;
        [row addArrangedSubview:button];
    }
    [container addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:30.0],
        [row.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [row.topAnchor constraintEqualToAnchor:container.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor]
    ]];
    return container;
}

- (NSButton *)linkButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [self secondaryButtonWithTitle:title action:action];
    button.contentTintColor = MKPreferencesAccentColor();
    return button;
}

- (BOOL)hasUsableURLString:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    return url.scheme.length > 0 && (url.host.length > 0 || url.isFileURL);
}

- (NSImage *)qrCodeImageForString:(NSString *)string sideLength:(CGFloat)sideLength {
    NSData *payload = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (payload.length == 0 || sideLength <= 0.0) {
        return nil;
    }

    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:payload forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *outputImage = filter.outputImage;
    if (!outputImage) {
        return nil;
    }

    CGRect extent = outputImage.extent;
    CGFloat scale = floor(sideLength / MAX(CGRectGetWidth(extent), CGRectGetHeight(extent)));
    if (scale < 1.0) {
        scale = 1.0;
    }
    CIImage *scaledImage = [outputImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    NSCIImageRep *imageRep = [NSCIImageRep imageRepWithCIImage:scaledImage];
    NSImage *image = [[NSImage alloc] initWithSize:imageRep.size];
    [image addRepresentation:imageRep];
    return image;
}

- (NSView *)buyMeACoffeeQRCodeView {
    NSImageView *qrCode = [[NSImageView alloc] initWithFrame:NSZeroRect];
    qrCode.translatesAutoresizingMaskIntoConstraints = NO;
    qrCode.image = [self qrCodeImageForString:MKPurrTypeBuyMeACoffeeURLString sideLength:108.0];
    qrCode.imageScaling = NSImageScaleProportionallyUpOrDown;
    qrCode.accessibilityLabel = [self localizedString:@"Buy Me a Coffee QR Code"];
    [NSLayoutConstraint activateConstraints:@[
        [qrCode.widthAnchor constraintEqualToConstant:108.0],
        [qrCode.heightAnchor constraintEqualToConstant:108.0]
    ]];
    return qrCode;
}

- (NSView *)compositionCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Composition"]
                                                         symbol:@"text.cursor"
                                                         height:226
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Escape cancels composition"]
                                                 detail:nil
                                                control:[self readOnlyChipWithText:[self localizedString:@"Esc"]]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Enter commits raw input"]
                                                 detail:nil
                                                control:[self readOnlyChipWithText:[self localizedString:@"Return"]]
                                                enabled:YES]];
    self.decimalPointShortcutSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesDecimalPointShortcutEnabled]
                                                            action:@selector(decimalPointShortcutSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Decimal point after numbers"]
                                                 detail:[self localizedString:@"Typing . after a number inserts a decimal point instead of opening punctuation candidates."]
                                                control:self.decimalPointShortcutSwitch
                                                enabled:YES]];
    self.chineseContextPunctuationSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesChineseContextPunctuationEnabled]
                                                                 action:@selector(chineseContextPunctuationSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Chinese punctuation after Chinese text"]
                                                 detail:[self localizedString:@"When text before the caret is Chinese, punctuation candidates start with Chinese or full-width marks."]
                                                control:self.chineseContextPunctuationSwitch
                                                enabled:YES]];
    return card;
}

- (NSView *)voiceInputCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Voice Input (Beta)"]
                                                         symbol:@"mic"
                                                         height:206
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.voiceRecognitionLocalePopupButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.voiceRecognitionLocalePopupButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.voiceRecognitionLocalePopupButton.controlSize = NSControlSizeRegular;
    self.voiceRecognitionLocalePopupButton.font = MKFont(12, NSFontWeightRegular);
    self.voiceRecognitionLocalePopupButton.target = self;
    self.voiceRecognitionLocalePopupButton.action = @selector(voiceRecognitionLocalePopupChanged:);
    [self configureVoiceRecognitionLocalePopup];
    [self syncVoiceRecognitionLocalePopup];
    [self.voiceRecognitionLocalePopupButton.widthAnchor constraintEqualToConstant:190].active = YES;
    [self.voiceRecognitionLocalePopupButton.heightAnchor constraintEqualToConstant:28].active = YES;
    NSStackView *localeControlStack = [self verticalStackWithSpacing:0];
    [localeControlStack addArrangedSubview:self.voiceRecognitionLocalePopupButton];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Recognition locale"]
                                                 detail:[self localizedString:@"Voice Input is a beta testing feature. Auto prefers Cantonese (Hong Kong), then Mandarin (Taiwan)."]
                                                control:localeControlStack
                                                enabled:YES]];
    self.voiceFloatingButtonSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesVoiceFloatingButtonVisible]
                                                           action:@selector(voiceFloatingButtonSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Floating mic button"]
                                                 detail:[self localizedString:@"Show the draggable voice button. The shortcut and menu still work when hidden."]
                                                control:self.voiceFloatingButtonSwitch
                                                enabled:YES]];
    return card;
}

- (NSView *)englishPassThroughCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"English Pass-through"]
                                                         symbol:@"globe"
                                                         height:274
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.rawEnglishCandidateSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesRawEnglishCandidateEnabled]
                                                           action:@selector(rawEnglishCandidateSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Show raw English candidate as 0"]
                                                 detail:nil
                                                control:self.rawEnglishCandidateSwitch
                                                enabled:YES]];
    self.rawEnglishCandidatePositionSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.rawEnglishCandidatePositionSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.rawEnglishCandidatePositionSegmentedControl.segmentCount = 2;
    self.rawEnglishCandidatePositionSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.rawEnglishCandidatePositionSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.rawEnglishCandidatePositionSegmentedControl.controlSize = NSControlSizeRegular;
    self.rawEnglishCandidatePositionSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.rawEnglishCandidatePositionSegmentedControl setLabel:[self localizedString:@"First"] forSegment:0];
    [self.rawEnglishCandidatePositionSegmentedControl setLabel:[self localizedString:@"Last"] forSegment:1];
    [self.rawEnglishCandidatePositionSegmentedControl setWidth:62 forSegment:0];
    [self.rawEnglishCandidatePositionSegmentedControl setWidth:62 forSegment:1];
    self.rawEnglishCandidatePositionSegmentedControl.target = self;
    self.rawEnglishCandidatePositionSegmentedControl.action = @selector(rawEnglishCandidatePositionSegmentChanged:);
    [self syncRawEnglishCandidatePositionSegment];
    [self.rawEnglishCandidatePositionSegmentedControl.widthAnchor constraintEqualToConstant:124].active = YES;
    [self.rawEnglishCandidatePositionSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"0 candidate position"]
                                                detail:nil
                                               control:self.rawEnglishCandidatePositionSegmentedControl
                                               enabled:YES]];
    self.spellingSuggestionsSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesSpellingSuggestionsEnabled]
                                                           action:@selector(spellingSuggestionsSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"English spelling suggestions"]
                                                detail:nil
                                               control:self.spellingSuggestionsSwitch
                                               enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Temporary English with Shift"]
                                                detail:nil
                                                control:[self readOnlyChipWithText:[self localizedString:@"Shift"]]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Keep URL / email / path in English"]
                                                detail:nil
                                               control:[self readOnlyChipWithText:[self localizedString:@"Automatic"]]
                                               enabled:YES]];
    return card;
}

- (NSView *)associationCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Related Words"]
                                                         symbol:@"text.append"
                                                         height:146
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.associationCandidatesSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesAssociationCandidatesEnabled]
                                                             action:@selector(associationCandidatesSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Show related words"]
                                                 detail:nil
                                                control:self.associationCandidatesSwitch
                                                enabled:YES]];
    self.associationContinuationSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesAssociationContinuationEnabled]
                                                               action:@selector(associationContinuationSwitchChanged:)];
    self.associationContinuationSwitch.enabled = [self.preferencesDelegate preferencesAssociationCandidatesEnabled];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Continue after choosing related word"]
                                                 detail:nil
                                                control:self.associationContinuationSwitch
                                                enabled:YES]];
    return card;
}

- (NSView *)quickPhrasesCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Quick Phrases"]
                                                         symbol:@"text.quote"
                                                         height:270
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.quickPhraseTriggerField = [self textFieldWithPlaceholder:[self localizedString:@"Start with ;, e.g. ;email"]];
    [stack addArrangedSubview:self.quickPhraseTriggerField];

    self.quickPhraseReplacementField = [self textFieldWithPlaceholder:[self localizedString:@"Replacement text"]];
    [stack addArrangedSubview:self.quickPhraseReplacementField];

    NSButton *save = [self prominentButtonWithTitle:[self localizedString:@"Save Phrase"] action:@selector(saveQuickPhrase:)];
    NSButton *remove = [self secondaryButtonWithTitle:[self localizedString:@"Remove Phrase"] action:@selector(removeQuickPhrase:)];
    NSView *saveRow = [self horizontalButtonRowWithButtons:@[save, remove]];
    [stack addArrangedSubview:saveRow];

    NSButton *import = [self secondaryButtonWithTitle:[self localizedString:@"Import TXT"] action:@selector(importQuickPhrasesFromTXT:)];
    NSButton *export = [self secondaryButtonWithTitle:[self localizedString:@"Export TXT"] action:@selector(exportQuickPhrasesToTXT:)];
    NSView *transferRow = [self horizontalButtonRowWithButtons:@[import, export]];
    [stack addArrangedSubview:transferRow];
    [stack setCustomSpacing:6.0 afterView:transferRow];

    self.quickPhraseSummaryField = [self labelWithText:@""
                                                  size:11
                                                weight:NSFontWeightSemibold
                                                 color:MKPreferencesPrimaryTextColor()];
    self.quickPhraseSummaryField.alignment = NSTextAlignmentLeft;
    self.quickPhraseSummaryField.lineBreakMode = NSLineBreakByTruncatingTail;
    self.quickPhraseSummaryField.maximumNumberOfLines = 1;
    [self.quickPhraseSummaryField.heightAnchor constraintGreaterThanOrEqualToConstant:18.0].active = YES;
    [stack addArrangedSubview:self.quickPhraseSummaryField];
    [stack setCustomSpacing:4.0 afterView:self.quickPhraseSummaryField];

    self.quickPhraseStatusField = [self statusLabel];
    self.quickPhraseStatusField.lineBreakMode = NSLineBreakByTruncatingTail;
    self.quickPhraseStatusField.maximumNumberOfLines = 1;
    [self.quickPhraseStatusField.heightAnchor constraintGreaterThanOrEqualToConstant:18.0].active = YES;
    [stack addArrangedSubview:self.quickPhraseStatusField];
    [NSLayoutConstraint activateConstraints:@[
        [self.quickPhraseSummaryField.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [self.quickPhraseStatusField.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];
    [self updateQuickPhraseSummary];
    return card;
}

- (NSView *)learningCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Learning"]
                                                         symbol:@"brain"
                                                         height:98
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.learningSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesLearningEnabled]
                                                action:@selector(learningSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Enable New Sucheng learning"]
                                                 detail:nil
                                                control:self.learningSwitch
                                                enabled:YES]];
    return card;
}

- (NSView *)privacyLockSettingsCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Privacy Lock"]
                                                         symbol:@"lock"
                                                         height:142
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.privacyLockSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesPrivacyLockEnabled]
                                                   action:@selector(privacyLockSwitchChanged:)];
    self.privacyLockStatusField = nil;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Pause learning immediately"]
                                                 detail:nil
                                                control:self.privacyLockSwitch
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Current shortcut"]
                                                 detail:nil
                                                control:[self privacyShortcutReferenceControl]
                                                enabled:YES]];
    return card;
}

- (NSView *)dataCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Data"]
                                                         symbol:@"externaldrive"
                                                         height:126
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    NSButton *reset = [self prominentButtonWithTitle:[self localizedString:@"Reset Learning Data"] action:@selector(resetLearning:)];
    NSMutableArray<NSButton *> *buttons = [NSMutableArray arrayWithObject:reset];
    if ([self privacyPolicyURL]) {
        [buttons addObject:[self linkButtonWithTitle:[self localizedString:@"Open Privacy Policy"] action:@selector(openPrivacyPolicy:)]];
    }
    [stack addArrangedSubview:[self buttonRowWithButtons:buttons]];
    self.dataStatusField = [self statusLabel];
    [stack addArrangedSubview:self.dataStatusField];
    return card;
}

- (NSView *)backupRestoreCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Backup / Restore"]
                                                         symbol:@"externaldrive.badge.timemachine"
                                                         height:126
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    NSButton *export = [self prominentButtonWithTitle:[self localizedString:@"Export Backup"] action:@selector(exportBackup:)];
    NSButton *restore = [self secondaryButtonWithTitle:[self localizedString:@"Restore Backup"] action:@selector(restoreBackup:)];
    [stack addArrangedSubview:[self horizontalButtonRowWithButtons:@[export, restore]]];

    self.backupStatusField = [self statusLabel];
    [stack addArrangedSubview:self.backupStatusField];
    return card;
}

- (NSView *)appIdentityCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"PurrType"]
                                                         symbol:@"keyboard"
                                                         height:118
                                                     titleLabel:&titleLabel];
    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = [self appIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    NSTextField *description = [self wrappingLabelWithText:[self localizedString:@"Open-source Traditional Chinese input method for macOS"]
                                                      size:13
                                                    weight:NSFontWeightRegular
                                                     color:MKPreferencesSecondaryTextColor()];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: [self localizedString:@"development"];
    NSTextField *versionLabel = [self labelWithText:[NSString stringWithFormat:@"%@ %@", [self localizedString:@"Version"], version]
                                               size:13
                                             weight:NSFontWeightSemibold
                                              color:MKPreferencesPrimaryTextColor()];
    [card addSubview:icon];
    [card addSubview:description];
    [card addSubview:versionLabel];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [icon.widthAnchor constraintEqualToConstant:36],
        [icon.heightAnchor constraintEqualToConstant:36],
        [description.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [description.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [description.topAnchor constraintEqualToAnchor:icon.topAnchor],
        [versionLabel.leadingAnchor constraintEqualToAnchor:description.leadingAnchor],
        [versionLabel.topAnchor constraintEqualToAnchor:description.bottomAnchor constant:6]
    ]];
    return card;
}

- (NSView *)linksCard {
    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    if ([self hasUsableURLString:MKPurrTypeGitHubURLString]) {
        [buttons addObject:[self linkButtonWithTitle:[self localizedString:@"GitHub"] action:@selector(openGitHub:)]];
    }
    if ([self hasUsableURLString:MKPurrTypeBuyMeACoffeeURLString]) {
        [buttons addObject:[self linkButtonWithTitle:[self localizedString:@"Buy Me a Coffee"] action:@selector(openBuyMeACoffee:)]];
    }
    if ([self hasUsableURLString:MKPurrTypeBugReportURLString]) {
        [buttons addObject:[self linkButtonWithTitle:[self localizedString:@"Report a Bug"] action:@selector(reportBug:)]];
    }
    if (buttons.count == 0) {
        return nil;
    }

    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Links"]
                                                         symbol:@"link"
                                                         height:214
                                                     titleLabel:&titleLabel];
    NSView *buttonRow = [self horizontalButtonRowWithButtons:buttons];
    [card addSubview:buttonRow];
    [NSLayoutConstraint activateConstraints:@[
        [buttonRow.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [buttonRow.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [buttonRow.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16]
    ]];

    if ([self hasUsableURLString:MKPurrTypeBuyMeACoffeeURLString]) {
        NSView *qrCode = [self buyMeACoffeeQRCodeView];
        [card addSubview:qrCode];
        [NSLayoutConstraint activateConstraints:@[
            [qrCode.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
            [qrCode.topAnchor constraintEqualToAnchor:buttonRow.bottomAnchor constant:14],
            [qrCode.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-16]
        ]];
    } else {
        [buttonRow.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-16].active = YES;
    }
    return card;
}

- (NSView *)madeByCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Made by"]
                                                         symbol:@"heart"
                                                         height:94
                                                     titleLabel:&titleLabel];
    NSTextField *text = [self wrappingLabelWithText:[self localizedString:@"Made by a photographer who accidentally started coding."]
                                               size:13
                                             weight:NSFontWeightRegular
                                              color:MKPreferencesSecondaryTextColor()];
    [card addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [text.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [text.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [text.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12]
    ]];
    return card;
}

- (NSView *)inputModeSettingsCard {
    if (![self.selectedInputModeSettingsMode isKindOfClass:[NSString class]] ||
        ![[PurrTypeInputBehavior orderedInputModes] containsObject:self.selectedInputModeSettingsMode]) {
        self.selectedInputModeSettingsMode = [self.preferencesDelegate preferencesCurrentMode] ?: MKInputModeSucheng;
    }

    NSTextField *title = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Input Mode Settings"]
                                                         symbol:@"keyboard"
                                                         height:346
                                                     titleLabel:&title];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:title];
    stack.spacing = 6.0;

    self.inputModeSettingsSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.inputModeSettingsSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.inputModeSettingsSegmentedControl.segmentCount = 4;
    self.inputModeSettingsSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.inputModeSettingsSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.inputModeSettingsSegmentedControl.controlSize = NSControlSizeRegular;
    self.inputModeSettingsSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    for (NSUInteger index = 0; index < modes.count; index += 1) {
        [self.inputModeSettingsSegmentedControl setLabel:[self titleForInputMode:modes[index]] forSegment:(NSInteger)index];
    }
    [self.inputModeSettingsSegmentedControl setWidth:58 forSegment:0];
    [self.inputModeSettingsSegmentedControl setWidth:86 forSegment:1];
    [self.inputModeSettingsSegmentedControl setWidth:50 forSegment:2];
    [self.inputModeSettingsSegmentedControl setWidth:42 forSegment:3];
    self.inputModeSettingsSegmentedControl.target = self;
    self.inputModeSettingsSegmentedControl.action = @selector(inputModeSettingsSegmentChanged:);
    [self.inputModeSettingsSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    NSView *modeSelectorRow = [[NSView alloc] initWithFrame:NSZeroRect];
    modeSelectorRow.translatesAutoresizingMaskIntoConstraints = NO;
    [modeSelectorRow addSubview:self.inputModeSettingsSegmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [modeSelectorRow.heightAnchor constraintGreaterThanOrEqualToConstant:28],
        [self.inputModeSettingsSegmentedControl.leadingAnchor constraintEqualToAnchor:modeSelectorRow.leadingAnchor constant:-2],
        [self.inputModeSettingsSegmentedControl.topAnchor constraintEqualToAnchor:modeSelectorRow.topAnchor],
        [self.inputModeSettingsSegmentedControl.bottomAnchor constraintEqualToAnchor:modeSelectorRow.bottomAnchor],
        [self.inputModeSettingsSegmentedControl.widthAnchor constraintEqualToConstant:236]
    ]];
    [stack addArrangedSubview:modeSelectorRow];

    self.inputModeSettingsEnabledSwitch = [self switchControlWithState:YES
                                                                 action:@selector(inputModeSettingsEnabledSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Use this input mode"]
                                                 detail:nil
                                                control:self.inputModeSettingsEnabledSwitch
                                                enabled:YES]];

    NSString *selectedMode = self.selectedInputModeSettingsMode ?: MKInputModeSucheng;
    NSUInteger selectedIndex = [self selectedInputModeSettingsIndex];
    NSDictionary<NSString *, NSString *> *shortcuts = [self.preferencesDelegate preferencesModeShortcutsByMode] ?: @{};
    NSString *shortcut = shortcuts[selectedMode] ?: [PurrTypeInputBehavior defaultModeShortcutSpecForMode:selectedMode];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Shortcut"]
                                                 detail:nil
                                                control:[self shortcutEditorWithSpec:shortcut
                                                                          defaultSpec:[PurrTypeInputBehavior defaultModeShortcutSpecForMode:selectedMode]
                                                                                  tag:MKPreferencesShortcutTagModeBase + (NSInteger)selectedIndex]
                                                enabled:YES]];

    self.modeCandidatePageSizeSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.modeCandidatePageSizeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeCandidatePageSizeSegmentedControl.segmentCount = 3;
    self.modeCandidatePageSizeSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.modeCandidatePageSizeSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.modeCandidatePageSizeSegmentedControl.controlSize = NSControlSizeRegular;
    self.modeCandidatePageSizeSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.modeCandidatePageSizeSegmentedControl setLabel:[self localizedString:@"Follow Global"] forSegment:0];
    [self.modeCandidatePageSizeSegmentedControl setLabel:@"5" forSegment:1];
    [self.modeCandidatePageSizeSegmentedControl setLabel:@"9" forSegment:2];
    [self.modeCandidatePageSizeSegmentedControl setWidth:70 forSegment:0];
    [self.modeCandidatePageSizeSegmentedControl setWidth:50 forSegment:1];
    [self.modeCandidatePageSizeSegmentedControl setWidth:50 forSegment:2];
    self.modeCandidatePageSizeSegmentedControl.target = self;
    self.modeCandidatePageSizeSegmentedControl.action = @selector(modeCandidatePageSizeSegmentChanged:);
    [self.modeCandidatePageSizeSegmentedControl.widthAnchor constraintLessThanOrEqualToConstant:170].active = YES;
    [self.modeCandidatePageSizeSegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Candidate Page Size"]
                                                 detail:nil
                                                control:self.modeCandidatePageSizeSegmentedControl
                                                enabled:YES]];

    self.modeSpaceKeySegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.modeSpaceKeySegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSpaceKeySegmentedControl.segmentCount = 3;
    self.modeSpaceKeySegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.modeSpaceKeySegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.modeSpaceKeySegmentedControl.controlSize = NSControlSizeRegular;
    self.modeSpaceKeySegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.modeSpaceKeySegmentedControl setLabel:[self localizedString:@"Follow Global"] forSegment:0];
    [self.modeSpaceKeySegmentedControl setLabel:[self localizedString:@"Commit"] forSegment:1];
    [self.modeSpaceKeySegmentedControl setLabel:[self localizedString:@"Page"] forSegment:2];
    [self.modeSpaceKeySegmentedControl setWidth:70 forSegment:0];
    [self.modeSpaceKeySegmentedControl setWidth:70 forSegment:1];
    [self.modeSpaceKeySegmentedControl setWidth:54 forSegment:2];
    self.modeSpaceKeySegmentedControl.target = self;
    self.modeSpaceKeySegmentedControl.action = @selector(modeSpaceKeySegmentChanged:);
    [self.modeSpaceKeySegmentedControl.widthAnchor constraintLessThanOrEqualToConstant:194].active = YES;
    [self.modeSpaceKeySegmentedControl.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Space key"]
                                                 detail:nil
                                                control:self.modeSpaceKeySegmentedControl
                                                enabled:YES]];

    self.modeClearReadingOnFailureSwitch = [self switchControlWithState:NO
                                                                  action:@selector(modeClearReadingOnFailureSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Clear reading when composition fails"]
                                                 detail:nil
                                                control:self.modeClearReadingOnFailureSwitch
                                                enabled:YES]];

    NSButton *resetButton = [self secondaryButtonWithTitle:[self localizedString:@"Reset this mode"]
                                                    action:@selector(resetSelectedInputModeSettings:)];
    [resetButton.heightAnchor constraintEqualToConstant:28].active = YES;
    [resetButton.widthAnchor constraintEqualToConstant:112].active = YES;
    [resetButton setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];

    self.modeSettingsStatusField = [self wrappingLabelWithText:@""
                                                          size:11
                                                        weight:NSFontWeightRegular
                                                         color:MKPreferencesSecondaryTextColor()];
    self.modeSettingsStatusField.maximumNumberOfLines = 2;

    NSView *footer = [[NSView alloc] initWithFrame:NSZeroRect];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:resetButton];
    [NSLayoutConstraint activateConstraints:@[
        [footer.heightAnchor constraintGreaterThanOrEqualToConstant:34],
        [resetButton.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
        [resetButton.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor]
    ]];
    [stack addArrangedSubview:footer];

    [self refreshInputModeSettingsControls];
    return card;
}

- (NSView *)currentModeCard {
    NSTextField *title = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Default Mode"]
                                                         symbol:@"star"
                                                         height:112
                                                     titleLabel:&title];
    self.modeSegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSegmentedControl.segmentCount = 4;
    self.modeSegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.modeSegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.modeSegmentedControl.controlSize = NSControlSizeRegular;
    self.modeSegmentedControl.font = MKFont(12, NSFontWeightRegular);
    NSArray<NSString *> *labels = @[
        [self localizedString:@"Sucheng"],
        [self localizedString:@"New Sucheng"],
        [self localizedString:@"Cangjie"],
        [self localizedString:@"Pinyin"]
    ];
    for (NSUInteger index = 0; index < labels.count; index += 1) {
        [self.modeSegmentedControl setLabel:labels[index] forSegment:index];
    }
    [self.modeSegmentedControl setWidth:58 forSegment:0];
    [self.modeSegmentedControl setWidth:86 forSegment:1];
    [self.modeSegmentedControl setWidth:50 forSegment:2];
    [self.modeSegmentedControl setWidth:42 forSegment:3];
    self.modeSegmentedControl.target = self;
    self.modeSegmentedControl.action = @selector(modeSegmentChanged:);
    [self syncModeSegment];
    [card addSubview:self.modeSegmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSegmentedControl.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.modeSegmentedControl.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [self.modeSegmentedControl.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14],
        [self.modeSegmentedControl.widthAnchor constraintEqualToConstant:236]
    ]];
    return card;
}

- (NSView *)contentColumnView {
    MKPreferencesFillView *view = [[MKPreferencesFillView alloc] initWithFrame:NSZeroRect];
    view.fillColor = MKPreferencesContentBackgroundColor();
    NSStackView *stack = [self verticalStackWithSpacing:14];
    stack.alignment = NSLayoutAttributeWidth;
    [view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.widthAnchor constraintGreaterThanOrEqualToConstant:MKPreferencesContentColumnWidth()],
        [stack.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:MKPreferencesContentHorizontalMargin],
        [stack.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-MKPreferencesContentHorizontalMargin],
        [stack.topAnchor constraintEqualToAnchor:view.topAnchor constant:18],
        [stack.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-24]
    ]];
    return view;
}

- (NSStackView *)verticalStackWithSpacing:(CGFloat)spacing {
    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = spacing;
    return stack;
}

- (MKPreferencesCardView *)cardViewWithHeight:(CGFloat)height {
    MKPreferencesCardView *card = [[MKPreferencesCardView alloc] initWithFrame:NSZeroRect];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [card.heightAnchor constraintEqualToConstant:height].active = YES;
    return card;
}

- (NSTextField *)labelWithText:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = MKFont(size, weight);
    label.textColor = color;
    label.backgroundColor = NSColor.clearColor;
    return label;
}

- (NSTextField *)wrappingLabelWithText:(NSString *)text size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *label = [self labelWithText:text size:size weight:weight color:color];
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 3;
    [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    return label;
}

- (NSTextField *)statusLabel {
    NSTextField *label = [self wrappingLabelWithText:@""
                                               size:11
                                             weight:NSFontWeightRegular
                                              color:MKPreferencesAccentActiveColor()];
    label.maximumNumberOfLines = 2;
    [label.heightAnchor constraintGreaterThanOrEqualToConstant:16.0].active = YES;
    return label;
}

- (NSTextField *)textFieldWithPlaceholder:(NSString *)placeholder {
    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    textField.translatesAutoresizingMaskIntoConstraints = NO;
    textField.placeholderString = placeholder ?: @"";
    textField.font = MKFont(12, NSFontWeightRegular);
    textField.bezelStyle = NSTextFieldRoundedBezel;
    textField.lineBreakMode = NSLineBreakByTruncatingTail;
    [textField.heightAnchor constraintEqualToConstant:30].active = YES;
    return textField;
}

- (NSButton *)prominentButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleRounded;
    button.font = MKFont(12, NSFontWeightSemibold);
    button.contentTintColor = MKPreferencesAccentColor();
    return button;
}

- (NSButton *)secondaryButtonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleRounded;
    button.font = MKFont(12, NSFontWeightSemibold);
    return button;
}

- (CGFloat)minimumButtonWidthForTitle:(NSString *)title {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: MKFont(12, NSFontWeightSemibold)
    };
    return MAX(62.0, ceil([(title ?: @"") sizeWithAttributes:attributes].width) + 28.0);
}

- (MKPreferencesSwitchControl *)switchControlWithState:(BOOL)enabled action:(SEL)action {
    MKPreferencesSwitchControl *toggle = [[MKPreferencesSwitchControl alloc] initWithFrame:NSZeroRect];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    toggle.target = self;
    toggle.action = action;
    return toggle;
}

- (NSPopUpButton *)shortcutPopUpWithOptions:(NSArray<NSString *> *)options
                                   selected:(NSString *)selectedShortcut
                                     action:(SEL)action {
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.translatesAutoresizingMaskIntoConstraints = NO;
    popup.target = self;
    popup.action = action;
    NSString *selected = selectedShortcut ?: @"";
    for (NSString *shortcut in options) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[self localizedShortcutDisplayNameForSpec:shortcut]
                                                      action:nil
                                               keyEquivalent:@""];
        item.representedObject = shortcut;
        [popup.menu addItem:item];
        if ([shortcut isEqualToString:selected]) {
            [popup selectItem:item];
        }
    }
    if (!popup.selectedItem && popup.itemArray.count > 0) {
        [popup selectItemAtIndex:0];
    }
    return popup;
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)voiceRecognitionLocaleMenuItems {
    return @[
        @{@"title": [self localizedString:@"Auto"], @"value": MKVoiceRecognitionLocaleAuto},
        @{@"title": [self localizedString:@"Cantonese (Hong Kong)"], @"value": MKVoiceRecognitionLocaleZhHK},
        @{@"title": [self localizedString:@"Mandarin (Taiwan)"], @"value": MKVoiceRecognitionLocaleZhTW}
    ];
}

- (void)configureVoiceRecognitionLocalePopup {
    [self.voiceRecognitionLocalePopupButton removeAllItems];
    for (NSDictionary<NSString *, NSString *> *item in [self voiceRecognitionLocaleMenuItems]) {
        [self.voiceRecognitionLocalePopupButton addItemWithTitle:item[@"title"] ?: @""];
        self.voiceRecognitionLocalePopupButton.lastItem.representedObject = item[@"value"] ?: MKVoiceRecognitionLocaleAuto;
    }
}

- (void)syncVoiceRecognitionLocalePopup {
    NSString *localeIdentifier = [self.preferencesDelegate preferencesVoiceRecognitionLocaleIdentifier] ?: MKVoiceRecognitionLocaleAuto;
    for (NSMenuItem *item in self.voiceRecognitionLocalePopupButton.itemArray) {
        if ([item.representedObject isEqualToString:localeIdentifier]) {
            [self.voiceRecognitionLocalePopupButton selectItem:item];
            return;
        }
    }
    [self.voiceRecognitionLocalePopupButton selectItemAtIndex:0];
}

- (NSString *)localizedShortcutDisplayNameForSpec:(NSString *)shortcutSpec {
    NSString *displayName = [PurrTypeInputBehavior displayNameForShortcutSpec:shortcutSpec];
    if ([displayName isEqualToString:@"None"] || [displayName isEqualToString:@"Double `"]) {
        return [self localizedString:displayName];
    }
    return displayName;
}

- (NSString *)spacedShortcutDisplayNameForSpec:(NSString *)shortcutSpec {
    NSString *displayName = [self localizedShortcutDisplayNameForSpec:shortcutSpec];
    return [displayName stringByReplacingOccurrencesOfString:@"+" withString:@" + "];
}

- (NSString *)titleForInputMode:(NSString *)mode {
    if ([mode isEqualToString:MKInputModeSucheng]) {
        return [self localizedString:@"Sucheng"];
    }
    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        return [self localizedString:@"New Sucheng"];
    }
    if ([mode isEqualToString:MKInputModeCangjie]) {
        return [self localizedString:@"Cangjie"];
    }
    if ([mode isEqualToString:MKInputModePinyin]) {
        return [self localizedString:@"Pinyin"];
    }
    return [self localizedString:@"Sucheng"];
}

- (NSUInteger)selectedInputModeSettingsIndex {
    NSUInteger index = [[PurrTypeInputBehavior orderedInputModes] indexOfObject:self.selectedInputModeSettingsMode ?: @""];
    return index == NSNotFound ? 0 : index;
}

- (NSString *)selectedInputModeSettingsTitle {
    return [self titleForInputMode:self.selectedInputModeSettingsMode ?: MKInputModeSucheng];
}

- (void)refreshInputModeSettingsControls {
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    NSUInteger selectedIndex = [self selectedInputModeSettingsIndex];
    self.inputModeSettingsSegmentedControl.selectedSegment = (NSInteger)selectedIndex;

    NSString *mode = modes[selectedIndex];
    BOOL modeEnabled = [self isInputModeEnabled:mode];
    self.inputModeSettingsEnabledSwitch.state = modeEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSUInteger pageSizeOverride = [self.preferencesDelegate preferencesCandidatePageSizeOverrideForMode:mode];
    self.modeCandidatePageSizeSegmentedControl.selectedSegment = pageSizeOverride == 5 ? 1 : (pageSizeOverride == 9 ? 2 : 0);

    NSString *spaceOverride = [self.preferencesDelegate preferencesSpaceKeyOverrideForMode:mode];
    if ([spaceOverride isEqualToString:MKModeSpaceKeyCommitFirst]) {
        self.modeSpaceKeySegmentedControl.selectedSegment = 1;
    } else if ([spaceOverride isEqualToString:MKModeSpaceKeyPageCandidates]) {
        self.modeSpaceKeySegmentedControl.selectedSegment = 2;
    } else {
        self.modeSpaceKeySegmentedControl.selectedSegment = 0;
    }

    BOOL clearReadingOnFailureEnabled =
        [self.preferencesDelegate preferencesClearReadingOnCompositionFailureEnabledForMode:mode];
    self.modeClearReadingOnFailureSwitch.state = clearReadingOnFailureEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    BOOL isDefault = [[self.preferencesDelegate preferencesCurrentMode] isEqualToString:mode];
    self.modeSettingsStatusField.stringValue = isDefault ?
        [NSString stringWithFormat:[self localizedString:@"%@ is the default input mode."], [self selectedInputModeSettingsTitle]] :
        [NSString stringWithFormat:[self localizedString:@"Editing %@ settings."], [self selectedInputModeSettingsTitle]];
    [self refreshSelectedModeShortcutControl];
}

- (void)refreshSelectedModeShortcutControl {
    if (!self.modeShortcutRecorderControl || !self.modeShortcutResetButton) {
        return;
    }
    NSUInteger selectedIndex = [self selectedInputModeSettingsIndex];
    NSString *mode = [PurrTypeInputBehavior orderedInputModes][selectedIndex];
    NSInteger tag = MKPreferencesShortcutTagModeBase + (NSInteger)selectedIndex;
    NSDictionary<NSString *, NSString *> *shortcuts = [self.preferencesDelegate preferencesModeShortcutsByMode] ?: @{};
    self.modeShortcutRecorderControl.tag = tag;
    self.modeShortcutResetButton.tag = tag;
    self.modeShortcutRecorderControl.shortcutSpec = shortcuts[mode] ?: [PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode];
}

- (BOOL)isInputModeEnabled:(NSString *)mode {
    return [PurrTypeInputBehavior inputMode:mode
                            isEnabledInModes:[self.preferencesDelegate preferencesEnabledInputModes]];
}

- (NSString *)modeForInputModeSwitchTag:(NSInteger)tag {
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    NSInteger index = tag - MKPreferencesInputModeSwitchTagBase;
    if (index < 0 || index >= (NSInteger)modes.count) {
        return nil;
    }
    return modes[(NSUInteger)index];
}

- (NSString *)modeForShortcutTag:(NSInteger)tag {
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    NSInteger index = tag - MKPreferencesShortcutTagModeBase;
    if (index < 0 || index >= (NSInteger)modes.count) {
        return nil;
    }
    return modes[(NSUInteger)index];
}

- (NSString *)normalizedShortcutSpec:(NSString *)shortcutSpec forTag:(NSInteger)tag {
    if (tag == MKPreferencesShortcutTagSwitchInputMode) {
        return [PurrTypeInputBehavior normalizedSwitchInputModeShortcutSpec:shortcutSpec];
    }
    if (tag == MKPreferencesShortcutTagPrivacyLock) {
        return [PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:shortcutSpec];
    }
    NSString *mode = [self modeForShortcutTag:tag];
    if (mode) {
        return [PurrTypeInputBehavior normalizedModeShortcutSpec:shortcutSpec forMode:mode];
    }
    return @"none";
}

- (NSString *)shortcutSpecForTag:(NSInteger)tag {
    if (tag == MKPreferencesShortcutTagSwitchInputMode) {
        return [self.preferencesDelegate preferencesSwitchInputModeShortcut];
    }
    if (tag == MKPreferencesShortcutTagPrivacyLock) {
        return [self.preferencesDelegate preferencesPrivacyLockShortcut];
    }
    NSString *mode = [self modeForShortcutTag:tag];
    if (mode) {
        NSDictionary<NSString *, NSString *> *shortcuts = [self.preferencesDelegate preferencesModeShortcutsByMode] ?: @{};
        NSString *shortcut = shortcuts[mode];
        return shortcut ?: [PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode];
    }
    return @"none";
}

- (NSString *)shortcutActionTitleForTag:(NSInteger)tag {
    if (tag == MKPreferencesShortcutTagSwitchInputMode) {
        return [self localizedString:@"Switch Input Mode"];
    }
    if (tag == MKPreferencesShortcutTagPrivacyLock) {
        return [self localizedString:@"Pause Learning"];
    }
    NSString *mode = [self modeForShortcutTag:tag];
    return mode ? [self titleForInputMode:mode] : [self localizedString:@"Shortcut"];
}

- (NSString *)conflictingShortcutActionTitleForSpec:(NSString *)shortcutSpec excludingTag:(NSInteger)excludedTag {
    if ([shortcutSpec isEqualToString:@"none"]) {
        return nil;
    }

    NSMutableDictionary<NSNumber *, NSString *> *shortcutsByTag = [NSMutableDictionary dictionary];
    shortcutsByTag[@(MKPreferencesShortcutTagSwitchInputMode)] = [self.preferencesDelegate preferencesSwitchInputModeShortcut];
    shortcutsByTag[@(MKPreferencesShortcutTagPrivacyLock)] = [self.preferencesDelegate preferencesPrivacyLockShortcut];

    NSDictionary<NSString *, NSString *> *modeShortcuts = [self.preferencesDelegate preferencesModeShortcutsByMode] ?: @{};
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    for (NSUInteger index = 0; index < modes.count; index += 1) {
        NSString *mode = modes[index];
        shortcutsByTag[@(MKPreferencesShortcutTagModeBase + (NSInteger)index)] =
            modeShortcuts[mode] ?: [PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode];
    }

    for (NSNumber *tagNumber in shortcutsByTag) {
        NSInteger tag = tagNumber.integerValue;
        if (tag == excludedTag) {
            continue;
        }
        NSString *existingShortcut = [self normalizedShortcutSpec:shortcutsByTag[tagNumber] forTag:tag];
        if ([PurrTypeInputBehavior shortcutSpec:existingShortcut conflictsWithShortcutSpec:shortcutSpec]) {
            return [self shortcutActionTitleForTag:tag];
        }
    }
    return nil;
}

- (void)clearShortcutError {
    self.shortcutErrorField.stringValue = @"";
    self.shortcutErrorField.hidden = YES;
}

- (void)showShortcutError:(NSString *)message {
    self.shortcutErrorField.stringValue = message ?: @"";
    self.shortcutErrorField.hidden = (message.length == 0);
    if (message.length > 0) {
        NSBeep();
    }
}

- (MKPreferencesShortcutRecorderControl *)shortcutRecorderWithTag:(NSInteger)tag inView:(NSView *)view {
    if ([view isKindOfClass:[MKPreferencesShortcutRecorderControl class]] &&
        ((MKPreferencesShortcutRecorderControl *)view).tag == tag) {
        return (MKPreferencesShortcutRecorderControl *)view;
    }
    for (NSView *subview in view.subviews) {
        MKPreferencesShortcutRecorderControl *recorder = [self shortcutRecorderWithTag:tag inView:subview];
        if (recorder) {
            return recorder;
        }
    }
    return nil;
}

- (void)updateVisibleShortcutRecorderWithTag:(NSInteger)tag shortcutSpec:(NSString *)shortcutSpec {
    MKPreferencesShortcutRecorderControl *recorder = [self shortcutRecorderWithTag:tag inView:self.contentContainer];
    recorder.shortcutSpec = shortcutSpec ?: @"none";
}

- (void)inputModeSwitchChanged:(MKPreferencesSwitchControl *)sender {
    NSString *mode = [self modeForInputModeSwitchTag:sender.tag];
    if (!mode) {
        return;
    }

    NSMutableArray<NSString *> *enabledModes = [[PurrTypeInputBehavior normalizedEnabledInputModes:[self.preferencesDelegate preferencesEnabledInputModes]] mutableCopy];
    BOOL shouldEnable = sender.state == NSControlStateValueOn;
    BOOL currentlyEnabled = [enabledModes containsObject:mode];
    if (!shouldEnable && currentlyEnabled && enabledModes.count <= 1) {
        sender.state = NSControlStateValueOn;
        self.enabledInputModesNoticeField.stringValue = [self localizedString:@"At least one input mode must remain enabled."];
        self.enabledInputModesNoticeField.hidden = NO;
        NSBeep();
        return;
    }

    if (shouldEnable && !currentlyEnabled) {
        [enabledModes addObject:mode];
    } else if (!shouldEnable && currentlyEnabled) {
        [enabledModes removeObject:mode];
    }

    NSString *previousMode = [self.preferencesDelegate preferencesCurrentMode];
    NSArray<NSString *> *normalizedModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledModes];
    [self.preferencesDelegate preferencesSetEnabledInputModes:normalizedModes];
    NSString *currentMode = [self.preferencesDelegate preferencesCurrentMode];
    if (![previousMode isEqualToString:currentMode]) {
        self.enabledInputModesNoticeField.stringValue =
            [NSString stringWithFormat:[self localizedString:@"Default mode changed to %@."],
                                       [self titleForInputMode:currentMode]];
    } else {
        self.enabledInputModesNoticeField.stringValue = [self localizedString:@"Enabled input modes updated."];
    }
    self.enabledInputModesNoticeField.hidden = NO;
}

- (void)shortcutRecorderChanged:(MKPreferencesShortcutRecorderControl *)sender {
    NSString *previousShortcut = [self normalizedShortcutSpec:[self shortcutSpecForTag:sender.tag] forTag:sender.tag];
    NSString *shortcut = [self normalizedShortcutSpec:(sender.shortcutSpec ?: @"none") forTag:sender.tag];
    NSString *conflictingAction = [self conflictingShortcutActionTitleForSpec:shortcut excludingTag:sender.tag];
    if (conflictingAction.length > 0) {
        sender.shortcutSpec = previousShortcut;
        NSString *message = [NSString stringWithFormat:[self localizedString:@"Shortcut already used by %@."], conflictingAction];
        [self showShortcutError:message];
        return;
    }

    if (sender.tag == MKPreferencesShortcutTagSwitchInputMode) {
        [self.preferencesDelegate preferencesSetSwitchInputModeShortcut:shortcut];
    } else if (sender.tag == MKPreferencesShortcutTagPrivacyLock) {
        [self.preferencesDelegate preferencesSetPrivacyLockShortcut:shortcut];
    } else if (sender.tag >= MKPreferencesShortcutTagModeBase &&
               sender.tag < MKPreferencesShortcutTagModeBase + 4) {
        NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
        NSUInteger index = (NSUInteger)(sender.tag - MKPreferencesShortcutTagModeBase);
        [self.preferencesDelegate preferencesSetModeShortcut:shortcut forMode:modes[index]];
    }
    sender.shortcutSpec = shortcut;
    [self clearShortcutError];
}

- (void)shortcutResetButtonClicked:(NSButton *)sender {
    NSString *shortcut = nil;
    if (sender.tag == MKPreferencesShortcutTagSwitchInputMode) {
        shortcut = [PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec];
        [self.preferencesDelegate preferencesSetSwitchInputModeShortcut:shortcut];
    } else if (sender.tag == MKPreferencesShortcutTagPrivacyLock) {
        shortcut = [PurrTypeInputBehavior defaultPrivacyLockShortcutSpec];
        [self.preferencesDelegate preferencesSetPrivacyLockShortcut:shortcut];
    } else if (sender.tag >= MKPreferencesShortcutTagModeBase &&
               sender.tag < MKPreferencesShortcutTagModeBase + 4) {
        NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
        NSUInteger index = (NSUInteger)(sender.tag - MKPreferencesShortcutTagModeBase);
        NSString *mode = modes[index];
        shortcut = [PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode];
        [self.preferencesDelegate preferencesSetModeShortcut:shortcut forMode:mode];
    }
    if (shortcut.length > 0) {
        [self updateVisibleShortcutRecorderWithTag:sender.tag shortcutSpec:shortcut];
    }
    [self clearShortcutError];
}

- (void)editPrivacyShortcutInGeneral:(id)sender {
    (void)sender;
    self.selectedTab = MKPreferencesTabGeneral;
    [self reloadState];
}

- (void)preferencesLanguageSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSArray<NSString *> *languages = @[MKPreferencesLanguageSystem, MKPreferencesLanguageEnglish, MKPreferencesLanguageTraditionalChinese];
    NSInteger index = sender.selectedSegment;
    if (index < 0 || index >= (NSInteger)languages.count) {
        return;
    }
    [[self preferencesDefaults] setObject:languages[(NSUInteger)index] forKey:MKUserDefaultPreferencesLanguageKey];
    [[self preferencesDefaults] synchronize];
    self.window.title = [self localizedString:@"PurrType Settings"];
    [self rebuildSidebar];
    [self rebuildContentPreservingScrollPosition];
    [self showGeneralBehaviorStatus:[self localizedString:@"Preferences language updated."] error:NO beep:NO];
    [self normalizeWindowContentSize];
}

- (void)modeSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    NSInteger index = sender.selectedSegment;
    if (index < 0 || index >= (NSInteger)modes.count) {
        return;
    }
    NSString *mode = modes[(NSUInteger)index];
    if (![self isInputModeEnabled:mode]) {
        [self syncModeSegment];
        NSBeep();
        return;
    }
    [self.preferencesDelegate preferencesSwitchToMode:mode];
    self.selectedInputModeSettingsMode = mode;
    [self syncModeSegment];
    [self refreshInputModeSettingsControls];
}

- (void)inputModeSettingsSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    NSInteger index = sender.selectedSegment;
    if (index < 0 || index >= (NSInteger)modes.count) {
        return;
    }
    self.selectedInputModeSettingsMode = modes[(NSUInteger)index];
    [self refreshInputModeSettingsControls];
}

- (void)inputModeSettingsEnabledSwitchChanged:(MKPreferencesSwitchControl *)sender {
    NSString *mode = self.selectedInputModeSettingsMode ?: MKInputModeSucheng;
    NSMutableArray<NSString *> *enabledModes = [[PurrTypeInputBehavior normalizedEnabledInputModes:[self.preferencesDelegate preferencesEnabledInputModes]] mutableCopy];
    BOOL shouldEnable = sender.state == NSControlStateValueOn;
    BOOL currentlyEnabled = [enabledModes containsObject:mode];
    if (!shouldEnable && currentlyEnabled && enabledModes.count <= 1) {
        sender.state = NSControlStateValueOn;
        self.modeSettingsStatusField.stringValue = [self localizedString:@"At least one input mode must remain enabled."];
        NSBeep();
        return;
    }

    if (shouldEnable && !currentlyEnabled) {
        [enabledModes addObject:mode];
    } else if (!shouldEnable && currentlyEnabled) {
        [enabledModes removeObject:mode];
    }

    [self.preferencesDelegate preferencesSetEnabledInputModes:[PurrTypeInputBehavior normalizedEnabledInputModes:enabledModes]];
    [self refreshInputModeSettingsControls];
}

- (void)modeCandidatePageSizeSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSUInteger override = sender.selectedSegment == 1 ? 5 : (sender.selectedSegment == 2 ? 9 : 0);
    [self.preferencesDelegate preferencesSetCandidatePageSizeOverride:override
                                                               forMode:self.selectedInputModeSettingsMode ?: MKInputModeSucheng];
    [self refreshInputModeSettingsControls];
}

- (void)modeSpaceKeySegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSString *override = MKModeOverrideFollowGlobal;
    if (sender.selectedSegment == 1) {
        override = MKModeSpaceKeyCommitFirst;
    } else if (sender.selectedSegment == 2) {
        override = MKModeSpaceKeyPageCandidates;
    }
    [self.preferencesDelegate preferencesSetSpaceKeyOverride:override
                                                     forMode:self.selectedInputModeSettingsMode ?: MKInputModeSucheng];
    [self refreshInputModeSettingsControls];
}

- (void)modeClearReadingOnFailureSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetClearReadingOnCompositionFailureEnabled:(sender.state == NSControlStateValueOn)
                                                                            forMode:self.selectedInputModeSettingsMode ?: MKInputModeSucheng];
    [self refreshInputModeSettingsControls];
}

- (void)resetSelectedInputModeSettings:(id)sender {
    (void)sender;
    [self.preferencesDelegate preferencesResetOverridesForMode:self.selectedInputModeSettingsMode ?: MKInputModeSucheng];
    [self refreshInputModeSettingsControls];
}

- (void)learningSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetLearningEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)privacyLockSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetPrivacyLockEnabled:(sender.state == NSControlStateValueOn)];
    self.privacyLockStatusField.stringValue = [self privacyLockStatusText];
}

- (void)rawEnglishCandidateSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetRawEnglishCandidateEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)rawEnglishCandidatePositionSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSString *position = sender.selectedSegment == 1 ? MKRawEnglishCandidatePositionTrailing : MKRawEnglishCandidatePositionLeading;
    [self.preferencesDelegate preferencesSetRawEnglishCandidatePosition:position];
}

- (void)spellingSuggestionsSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetSpellingSuggestionsEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)decimalPointShortcutSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetDecimalPointShortcutEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)chineseContextPunctuationSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetChineseContextPunctuationEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)voiceRecognitionLocalePopupChanged:(NSPopUpButton *)sender {
    NSString *localeIdentifier = sender.selectedItem.representedObject;
    [self.preferencesDelegate preferencesSetVoiceRecognitionLocaleIdentifier:localeIdentifier ?: MKVoiceRecognitionLocaleAuto];
    [self syncVoiceRecognitionLocalePopup];
}

- (void)voiceFloatingButtonSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetVoiceFloatingButtonVisible:(sender.state == NSControlStateValueOn)];
}

- (void)spaceKeySegmentChanged:(MKPreferencesSegmentedControl *)sender {
    [self.preferencesDelegate preferencesSetSpacePagingEnabled:(sender.selectedSegment == 1)];
}

- (void)candidatePageSizeSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSUInteger pageSize = sender.selectedSegment == 0 ? 5 : 9;
    [self.preferencesDelegate preferencesSetCandidatePageSize:pageSize];
}

- (void)candidatePanelOrientationSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSString *orientation = sender.selectedSegment == 1 ? MKCandidatePanelOrientationHorizontal : MKCandidatePanelOrientationVertical;
    [self.preferencesDelegate preferencesSetCandidatePanelOrientation:orientation];
}

- (void)candidatePanelFontSizeSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    CGFloat fontSize = 17.0;
    if (sender.selectedSegment == 0) {
        fontSize = 15.0;
    } else if (sender.selectedSegment == 2) {
        fontSize = 19.0;
    }
    [self.preferencesDelegate preferencesSetCandidatePanelFontSize:fontSize];
}

- (void)candidatePanelHighlightPopupChanged:(NSPopUpButton *)sender {
    NSString *highlightColor = sender.selectedItem.representedObject;
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightCustomPrefix]) {
        NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
        colorPanel.showsAlpha = NO;
        colorPanel.target = self;
        colorPanel.action = @selector(candidatePanelCustomHighlightColorChanged:);
        [colorPanel setColor:MKPreferencesColorForCandidateHighlightValue([self.preferencesDelegate preferencesCandidatePanelHighlightColor])];
        [colorPanel orderFront:self];
        return;
    }
    if (highlightColor.length == 0) {
        highlightColor = MKCandidatePanelHighlightRed;
    }
    [self.preferencesDelegate preferencesSetCandidatePanelHighlightColor:highlightColor];
    [self syncCandidatePanelHighlightPopup];
}

- (void)candidatePanelCustomHighlightColorChanged:(NSColorPanel *)sender {
    NSString *highlightColor = MKPreferencesCustomHighlightStringFromColor(sender.color ?: NSColor.systemRedColor);
    [self.preferencesDelegate preferencesSetCandidatePanelHighlightColor:highlightColor];
    [self syncCandidatePanelHighlightPopup];
}

- (void)associationCandidatesSwitchChanged:(MKPreferencesSwitchControl *)sender {
    BOOL enabled = sender.state == NSControlStateValueOn;
    [self.preferencesDelegate preferencesSetAssociationCandidatesEnabled:enabled];
    self.associationContinuationSwitch.enabled = enabled;
}

- (void)associationContinuationSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetAssociationContinuationEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)modeShortcutPopUpChanged:(NSPopUpButton *)sender {
    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    NSInteger index = sender.tag;
    if (index < 0 || index >= (NSInteger)modes.count) {
        return;
    }
    NSString *shortcut = [sender.selectedItem.representedObject isKindOfClass:[NSString class]] ? sender.selectedItem.representedObject : @"";
    [self.preferencesDelegate preferencesSetModeShortcut:shortcut forMode:modes[(NSUInteger)index]];
}

- (void)privacyLockShortcutPopUpChanged:(NSPopUpButton *)sender {
    NSString *shortcut = [sender.selectedItem.representedObject isKindOfClass:[NSString class]] ? sender.selectedItem.representedObject : @"";
    [self.preferencesDelegate preferencesSetPrivacyLockShortcut:shortcut];
}

- (void)resetLearning:(id)sender {
    (void)sender;
    [self.preferencesDelegate preferencesResetLearning];
    [self showDataStatus:[self localizedString:@"Learning data reset."] error:NO beep:NO];
}

- (void)saveQuickPhrase:(id)sender {
    (void)sender;
    NSError *error = nil;
    PurrTypeQuickPhraseEntry *entry = [self.quickPhraseStore upsertTrigger:self.quickPhraseTriggerField.stringValue
                                                               replacement:self.quickPhraseReplacementField.stringValue
                                                                     label:@""
                                                                   enabled:YES
                                                                     error:&error];
    if (!entry || ![self.quickPhraseStore saveWithError:&error]) {
        [self showQuickPhraseStatus:error.localizedDescription ?: [self localizedString:@"Unable to save quick phrase."] beep:YES];
        return;
    }

    NSString *trigger = entry.normalizedTrigger ?: [PurrTypeQuickPhraseStore normalizedTriggerForTrigger:self.quickPhraseTriggerField.stringValue];
    NSUInteger triggerCount = [self.quickPhraseStore entriesForTrigger:trigger].count;
    [self postQuickPhrasesChangedNotification];
    [self updateQuickPhraseSummary];
    NSString *message = [NSString stringWithFormat:[self localizedString:@"Saved %@. This command has %lu items."],
                         trigger.length > 0 ? trigger : [self localizedString:@"Quick Phrases"],
                         (unsigned long)triggerCount];
    [self showQuickPhraseStatus:message beep:NO];
}

- (void)removeQuickPhrase:(id)sender {
    (void)sender;
    NSError *error = nil;
    NSUInteger removedCount = [self.quickPhraseStore removeEntriesForTrigger:self.quickPhraseTriggerField.stringValue
                                                                 replacement:self.quickPhraseReplacementField.stringValue
                                                                       error:&error];
    if (error || ![self.quickPhraseStore saveWithError:&error]) {
        [self showQuickPhraseStatus:error.localizedDescription ?: [self localizedString:@"Unable to remove quick phrase."] beep:YES];
        return;
    }

    if (removedCount == 0) {
        [self showQuickPhraseStatus:[self localizedString:@"No matching quick phrase to remove."] beep:YES];
        return;
    }
    self.quickPhraseReplacementField.stringValue = @"";
    [self postQuickPhrasesChangedNotification];
    [self updateQuickPhraseSummary];
    NSString *message = [NSString stringWithFormat:[self localizedString:@"Removed %lu quick phrase items."], (unsigned long)removedCount];
    [self showQuickPhraseStatus:message beep:NO];
}

- (void)importQuickPhrasesFromTXT:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [self localizedString:@"Import Quick Phrases"];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.directoryURL = [self downloadsDirectoryURL];
    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:panel.URL encoding:NSUTF8StringEncoding error:&error];
    PurrTypeQuickPhraseImportSummary *summary = text ? [self.quickPhraseStore importEntriesFromText:text error:&error] : nil;
    if (!summary || ![self.quickPhraseStore saveWithError:&error]) {
        [self showQuickPhraseStatus:error.localizedDescription ?: [self localizedString:@"Unable to import quick phrases."] beep:YES];
        return;
    }

    [self postQuickPhrasesChangedNotification];
    [self updateQuickPhraseSummary];
    NSString *message = [NSString stringWithFormat:[self localizedString:@"Imported %lu, updated %lu, invalid %lu."],
                         (unsigned long)summary.importedCount,
                         (unsigned long)summary.updatedCount,
                         (unsigned long)summary.invalidCount];
    [self showQuickPhraseStatus:message beep:NO];
}

- (void)exportQuickPhrasesToTXT:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = [self localizedString:@"Export Quick Phrases"];
    panel.directoryURL = [self downloadsDirectoryURL];
    panel.nameFieldStringValue = @"purrtype-quick-phrases.txt";
    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError *error = nil;
    NSString *text = [self.quickPhraseStore exportText];
    if (![text writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self showQuickPhraseStatus:error.localizedDescription ?: [self localizedString:@"Unable to export quick phrases."] beep:YES];
        return;
    }
    [self showQuickPhraseStatus:[self localizedString:@"Quick phrases exported."] beep:NO];
}

- (void)exportBackup:(id)sender {
    (void)sender;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = [self localizedString:@"Export Backup"];
    panel.directoryURL = [self downloadsDirectoryURL];
    panel.nameFieldStringValue = [NSString stringWithFormat:@"purrtype-backup-%@.json", [self filenameTimestamp]];
    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError *error = nil;
    NSData *data = [self.backupStore exportBackupDataWithError:&error];
    if (!data || ![data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]) {
        [self showBackupStatus:error.localizedDescription ?: [self localizedString:@"Unable to export backup."] beep:YES];
        return;
    }
    [[NSFileManager defaultManager] setAttributes:@{ NSFilePosixPermissions: @0600 } ofItemAtPath:panel.URL.path error:nil];
    [self showBackupStatus:[self localizedString:@"Backup exported."] beep:NO];
}

- (void)restoreBackup:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = [self localizedString:@"Restore Backup"];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.directoryURL = [self downloadsDirectoryURL];
    if ([panel runModal] != NSModalResponseOK) {
        return;
    }

    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:panel.URL options:0 error:&error];
    PurrTypeBackupSummary *summary = data ? [self.backupStore restoreBackupData:data error:&error] : nil;
    if (!summary) {
        [self showBackupStatus:error.localizedDescription ?: [self localizedString:@"Unable to restore backup."] beep:YES];
        return;
    }

    [self.quickPhraseStore loadWithError:nil];
    [self postQuickPhrasesChangedNotification];
    [self updateQuickPhraseSummary];
    NSString *message = [NSString stringWithFormat:[self localizedString:@"Restored %lu data file, invalid %lu."],
                         (unsigned long)summary.importedCount,
                         (unsigned long)summary.invalidCount];
    [self showBackupStatus:message beep:(summary.invalidCount > 0)];
}

- (void)postQuickPhrasesChangedNotification {
    [[PurrTypePreferencesStore sharedStore] postPreferencesChangedNotificationWithUserInfo:@{ MKPreferencesQuickPhrasesChangedKey: @YES }];
}

- (void)updateQuickPhraseSummary {
    [self.quickPhraseStore loadWithError:nil];
    NSUInteger count = self.quickPhraseStore.entries.count;
    self.quickPhraseSummaryField.stringValue =
        count == 0 ? [self localizedString:@"No quick phrases yet."] :
        [NSString stringWithFormat:[self localizedString:@"%lu quick phrases saved."], (unsigned long)count];
}

- (void)showQuickPhraseStatus:(NSString *)message beep:(BOOL)beep {
    [self showStatus:message inField:self.quickPhraseStatusField error:beep beep:beep];
}

- (void)showBackupStatus:(NSString *)message beep:(BOOL)beep {
    [self showStatus:message inField:self.backupStatusField error:beep beep:beep];
}

- (void)showGeneralBehaviorStatus:(NSString *)message error:(BOOL)isError beep:(BOOL)beep {
    [self showStatus:message inField:self.generalBehaviorStatusField error:isError beep:beep];
}

- (void)showDataStatus:(NSString *)message error:(BOOL)isError beep:(BOOL)beep {
    [self showStatus:message inField:self.dataStatusField error:isError beep:beep];
}

- (void)showStatus:(NSString *)message inField:(NSTextField *)field error:(BOOL)isError beep:(BOOL)beep {
    field.stringValue = message ?: @"";
    field.textColor = isError ? NSColor.systemRedColor : MKPreferencesAccentActiveColor();
    if (beep) {
        NSBeep();
    }
}

- (NSURL *)downloadsDirectoryURL {
    NSURL *url = [[NSFileManager defaultManager] URLForDirectory:NSDownloadsDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil
                                                          create:NO
                                                           error:nil];
    return url ?: [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
}

- (NSString *)filenameTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone localTimeZone];
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
    return [formatter stringFromDate:[NSDate date]];
}

- (NSURL *)privacyPolicyFileURL {
    NSURL *bundledURL = [[NSBundle mainBundle] URLForResource:@"PRIVACY_POLICY"
                                                withExtension:@"md"
                                                 subdirectory:@"Legal"];
    if (bundledURL) {
        return bundledURL;
    }

    NSURL *resourceURL = [[NSBundle mainBundle] resourceURL];
    NSURL *inputMethodResourceURL = [resourceURL URLByDeletingLastPathComponent];
    inputMethodResourceURL = [inputMethodResourceURL URLByDeletingLastPathComponent];
    inputMethodResourceURL = [inputMethodResourceURL URLByDeletingLastPathComponent];
    NSURL *siblingURL = [inputMethodResourceURL URLByAppendingPathComponent:@"Legal/PRIVACY_POLICY.md"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:siblingURL.path]) {
        return siblingURL;
    }

    NSURL *developmentURL = [[[NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath] isDirectory:YES]
        URLByAppendingPathComponent:@"docs"]
        URLByAppendingPathComponent:@"PRIVACY_POLICY.md"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:developmentURL.path]) {
        return developmentURL;
    }

    return nil;
}

- (NSURL *)privacyPolicyURL {
    NSURL *fileURL = [self privacyPolicyFileURL];
    if (fileURL) {
        return fileURL;
    }

    return [NSURL URLWithString:MKPurrTypePrivacyPolicyURLString];
}

- (void)showPrivacyPolicyText:(NSString *)text sourceURL:(NSURL *)sourceURL {
    if (self.privacyPolicySheet) {
        [self.privacyPolicySheet makeKeyAndOrderFront:nil];
        return;
    }

    NSWindow *sheet = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, MKPrivacyPolicySheetWidth, MKPrivacyPolicySheetHeight)
                                                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    sheet.title = [self localizedString:@"Privacy Policy"];
    sheet.minSize = NSMakeSize(460.0, 420.0);
    sheet.backgroundColor = MKPreferencesContentBackgroundColor();
    sheet.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];

    MKPreferencesFillView *root = [[MKPreferencesFillView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.fillColor = MKPreferencesContentBackgroundColor();
    sheet.contentView = root;

    NSTextField *title = [self labelWithText:[self localizedString:@"Privacy Policy"]
                                        size:20
                                      weight:NSFontWeightSemibold
                                       color:MKPreferencesPrimaryTextColor()];
    NSTextField *source = [self wrappingLabelWithText:sourceURL.lastPathComponent ?: @""
                                                size:12
                                              weight:NSFontWeightRegular
                                               color:MKPreferencesSecondaryTextColor()];
    source.maximumNumberOfLines = 1;

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autohidesScrollers = YES;
    scrollView.borderType = NSBezelBorder;
    scrollView.drawsBackground = YES;
    scrollView.backgroundColor = MKPreferencesCardBackgroundColor();

    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, MKPrivacyPolicySheetWidth - 56.0, MKPrivacyPolicySheetHeight - 140.0)];
    textView.editable = NO;
    textView.selectable = YES;
    textView.richText = NO;
    textView.importsGraphics = NO;
    textView.drawsBackground = YES;
    textView.backgroundColor = MKPreferencesCardBackgroundColor();
    textView.textColor = MKPreferencesPrimaryTextColor();
    textView.font = MKFont(13, NSFontWeightRegular);
    textView.textContainerInset = NSMakeSize(14.0, 14.0);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = NO;
    textView.autoresizingMask = NSViewWidthSizable;
    textView.textContainer.widthTracksTextView = YES;
    textView.textContainer.containerSize = NSMakeSize(NSWidth(textView.frame), CGFLOAT_MAX);
    textView.string = text ?: @"";
    scrollView.documentView = textView;

    NSButton *close = [self prominentButtonWithTitle:[self localizedString:@"Close"]
                                              action:@selector(closePrivacyPolicySheet:)];

    [root addSubview:title];
    [root addSubview:source];
    [root addSubview:scrollView];
    [root addSubview:close];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:root.topAnchor constant:22.0],
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24.0],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-24.0],

        [source.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4.0],
        [source.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [source.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24.0],

        [scrollView.topAnchor constraintEqualToAnchor:source.bottomAnchor constant:14.0],
        [scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:24.0],
        [scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24.0],
        [scrollView.bottomAnchor constraintEqualToAnchor:close.topAnchor constant:-16.0],

        [close.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-24.0],
        [close.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-18.0]
    ]];

    self.privacyPolicySheet = sheet;
    __weak typeof(self) weakSelf = self;
    [self.window beginSheet:sheet completionHandler:^(NSModalResponse returnCode) {
        (void)returnCode;
        weakSelf.privacyPolicySheet = nil;
    }];
}

- (void)closePrivacyPolicySheet:(id)sender {
    (void)sender;
    if (!self.privacyPolicySheet) {
        return;
    }
    [self.window endSheet:self.privacyPolicySheet returnCode:NSModalResponseCancel];
}

- (void)showPrivacyPolicyReadErrorForURL:(NSURL *)url error:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [self localizedString:@"Privacy policy unavailable"];
    alert.informativeText = error.localizedDescription ?: url.path ?: @"";
    [alert addButtonWithTitle:[self localizedString:@"Close"]];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)openURL:(NSURL *)url {
    if (!url) {
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)openURLString:(NSString *)urlString {
    [self openURL:[NSURL URLWithString:urlString ?: @""]];
}

- (void)openPrivacyPolicy:(id)sender {
    (void)sender;
    NSURL *fileURL = [self privacyPolicyFileURL];
    if (!fileURL) {
        [self openURL:[self privacyPolicyURL]];
        [self showDataStatus:[self localizedString:@"Privacy policy opened."] error:NO beep:NO];
        return;
    }

    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:fileURL
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (text.length == 0) {
        [self showPrivacyPolicyReadErrorForURL:fileURL error:error];
        [self showDataStatus:error.localizedDescription ?: [self localizedString:@"Privacy policy unavailable"] error:YES beep:YES];
        return;
    }

    [self showPrivacyPolicyText:text sourceURL:fileURL];
    [self showDataStatus:[self localizedString:@"Privacy policy opened."] error:NO beep:NO];
}

- (void)openGitHub:(id)sender {
    (void)sender;
    [self openURLString:MKPurrTypeGitHubURLString];
}

- (void)openBuyMeACoffee:(id)sender {
    (void)sender;
    [self openURLString:MKPurrTypeBuyMeACoffeeURLString];
}

- (void)reportBug:(id)sender {
    (void)sender;
    [self openURLString:MKPurrTypeBugReportURLString];
}

- (void)syncModeSegment {
    NSString *mode = [self.preferencesDelegate preferencesCurrentMode] ?: MKInputModeSucheng;
    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    NSArray<NSString *> *enabledModes = [PurrTypeInputBehavior normalizedEnabledInputModes:[self.preferencesDelegate preferencesEnabledInputModes]];
    for (NSUInteger segment = 0; segment < modes.count; segment += 1) {
        [self.modeSegmentedControl setSegmentEnabled:[enabledModes containsObject:modes[segment]]
                                          forSegment:(NSInteger)segment];
    }
    if (![enabledModes containsObject:mode]) {
        mode = enabledModes.firstObject ?: MKInputModeSucheng;
        [self.preferencesDelegate preferencesSwitchToMode:mode];
    }
    NSUInteger index = [modes indexOfObject:mode];
    self.modeSegmentedControl.selectedSegment = index == NSNotFound ? 0 : (NSInteger)index;
}

- (void)syncCandidatePageSizeSegment {
    NSUInteger pageSize = [self.preferencesDelegate preferencesCandidatePageSize];
    self.candidatePageSizeSegmentedControl.selectedSegment = pageSize == 5 ? 0 : 1;
}

- (void)syncRawEnglishCandidatePositionSegment {
    NSString *position = [self.preferencesDelegate preferencesRawEnglishCandidatePosition];
    self.rawEnglishCandidatePositionSegmentedControl.selectedSegment =
        [position isEqualToString:MKRawEnglishCandidatePositionTrailing] ? 1 : 0;
}

- (void)syncCandidatePanelOrientationSegment {
    NSString *orientation = [self.preferencesDelegate preferencesCandidatePanelOrientation];
    self.candidatePanelOrientationSegmentedControl.selectedSegment =
        [orientation isEqualToString:MKCandidatePanelOrientationHorizontal] ? 1 : 0;
}

- (void)syncCandidatePanelFontSizeSegment {
    CGFloat fontSize = [self.preferencesDelegate preferencesCandidatePanelFontSize];
    if (fontSize <= 15.5) {
        self.candidatePanelFontSizeSegmentedControl.selectedSegment = 0;
    } else if (fontSize >= 18.5) {
        self.candidatePanelFontSizeSegmentedControl.selectedSegment = 2;
    } else {
        self.candidatePanelFontSizeSegmentedControl.selectedSegment = 1;
    }
}

- (NSArray<NSDictionary<NSString *, NSString *> *> *)candidatePanelHighlightMenuItems {
    return @[
        @{@"title": [self localizedString:@"Red"], @"value": MKCandidatePanelHighlightRed},
        @{@"title": [self localizedString:@"Orange"], @"value": MKCandidatePanelHighlightOrange},
        @{@"title": [self localizedString:@"Yellow"], @"value": MKCandidatePanelHighlightYellow},
        @{@"title": [self localizedString:@"Green"], @"value": MKCandidatePanelHighlightGreen},
        @{@"title": [self localizedString:@"Blue"], @"value": MKCandidatePanelHighlightBlue},
        @{@"title": [self localizedString:@"Purple"], @"value": MKCandidatePanelHighlightPurple},
        @{@"title": [self localizedString:@"Pink"], @"value": MKCandidatePanelHighlightPink},
        @{@"title": [self localizedString:@"Custom Color..."], @"value": MKCandidatePanelHighlightCustomPrefix}
    ];
}

- (void)configureCandidatePanelHighlightPopup {
    [self.candidatePanelHighlightPopupButton removeAllItems];
    for (NSDictionary<NSString *, NSString *> *item in [self candidatePanelHighlightMenuItems]) {
        [self.candidatePanelHighlightPopupButton addItemWithTitle:item[@"title"] ?: @""];
        self.candidatePanelHighlightPopupButton.lastItem.representedObject = item[@"value"] ?: MKCandidatePanelHighlightRed;
    }
}

- (void)syncCandidatePanelHighlightPopup {
    NSString *highlightColor = [self.preferencesDelegate preferencesCandidatePanelHighlightColor] ?: MKCandidatePanelHighlightRed;
    BOOL isCustom = [highlightColor hasPrefix:MKCandidatePanelHighlightCustomPrefix];
    for (NSMenuItem *item in self.candidatePanelHighlightPopupButton.itemArray) {
        NSString *value = item.representedObject;
        if ((isCustom && [value isEqualToString:MKCandidatePanelHighlightCustomPrefix]) ||
            (!isCustom && [value isEqualToString:highlightColor])) {
            [self.candidatePanelHighlightPopupButton selectItem:item];
            return;
        }
    }
    [self.candidatePanelHighlightPopupButton selectItemAtIndex:0];
}

- (void)syncPreferencesLanguageSegment {
    NSString *language = [self savedPreferencesLanguage];
    if ([language isEqualToString:MKPreferencesLanguageEnglish]) {
        self.preferencesLanguageSegmentedControl.selectedSegment = 1;
    } else if ([language isEqualToString:MKPreferencesLanguageTraditionalChinese]) {
        self.preferencesLanguageSegmentedControl.selectedSegment = 2;
    } else {
        self.preferencesLanguageSegmentedControl.selectedSegment = 0;
    }
}

- (NSUserDefaults *)preferencesDefaults {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:MKUserDefaultsSuiteName]) {
        return [NSUserDefaults standardUserDefaults];
    }

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MKUserDefaultsSuiteName];
    return defaults ?: [NSUserDefaults standardUserDefaults];
}

- (NSString *)savedPreferencesLanguage {
    NSString *language = [[self preferencesDefaults] stringForKey:MKUserDefaultPreferencesLanguageKey];
    if ([language isEqualToString:MKPreferencesLanguageEnglish] ||
        [language isEqualToString:MKPreferencesLanguageTraditionalChinese]) {
        return language;
    }
    return MKPreferencesLanguageTraditionalChinese;
}

- (NSBundle *)localizationBundleForLanguage:(NSString *)language {
    if ([language isEqualToString:MKPreferencesLanguageEnglish]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"en" ofType:@"lproj"] ?:
                         [[NSBundle mainBundle] pathForResource:@"English" ofType:@"lproj"];
        return path.length > 0 ? [NSBundle bundleWithPath:path] : nil;
    }

    if ([language isEqualToString:MKPreferencesLanguageTraditionalChinese]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"zh-Hant" ofType:@"lproj"] ?:
                         [[NSBundle mainBundle] pathForResource:@"zh_TW" ofType:@"lproj"];
        return path.length > 0 ? [NSBundle bundleWithPath:path] : nil;
    }

    return nil;
}

- (NSString *)localizedString:(NSString *)key {
    NSString *language = [self savedPreferencesLanguage];
    NSBundle *languageBundle = [self localizationBundleForLanguage:language];
    if (languageBundle) {
        return [languageBundle localizedStringForKey:key value:key table:nil];
    }
    return [[NSBundle mainBundle] localizedStringForKey:key value:key table:nil];
}

- (NSString *)learningStatusTextForCard {
    if ([self.preferencesDelegate preferencesPrivacyLockEnabled]) {
        return [self localizedString:@"Paused by Privacy Lock"];
    }

    if (![self.preferencesDelegate preferencesLearningEnabled]) {
        NSString *disabled = [self localizedString:@"Disabled"];
        return disabled;
    }

    NSString *enabled = [self localizedString:@"Enabled"];
    return [NSString stringWithFormat:@"%@ · %@", enabled, [self localizedString:@"Local Ranking"]];
}

- (NSColor *)learningStatusColor {
    if ([self.preferencesDelegate preferencesPrivacyLockEnabled]) {
        return NSColor.systemOrangeColor;
    }

    if (![self.preferencesDelegate preferencesLearningEnabled]) {
        return MKPreferencesSecondaryTextColor();
    }

    return NSColor.systemGreenColor;
}

- (NSString *)privacyLockStatusText {
    return [self.preferencesDelegate preferencesPrivacyLockEnabled] ? [self localizedString:@"On - learning paused"] : [self localizedString:@"Off - normal typing"];
}

- (NSColor *)privacyLockStatusColor {
    return [self.preferencesDelegate preferencesPrivacyLockEnabled] ? NSColor.systemGreenColor : MKPreferencesSecondaryTextColor();
}

@end
