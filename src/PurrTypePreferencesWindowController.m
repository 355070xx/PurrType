#import "PurrTypePreferencesWindowController.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypePreferencesConstants.h"
#import <CoreImage/CoreImage.h>

static CGFloat const MKPreferencesWindowWidth = 540.0;
static CGFloat const MKPreferencesWindowHeight = 720.0;
static CGFloat const MKPreferencesMinimumWindowWidth = 520.0;
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
static CGFloat const MKPreferencesContentHorizontalMargin = 18.0;
static CGFloat const MKPreferencesCoverAspectRatio = 1672.0 / 941.0;
static CGFloat const MKPreferencesCoverMaxWidth = 380.0;
static CGFloat const MKPrivacyPolicySheetWidth = 560.0;
static CGFloat const MKPrivacyPolicySheetHeight = 620.0;
static NSInteger const MKPreferencesShortcutTagSwitchInputMode = 9001;
static NSInteger const MKPreferencesShortcutTagPrivacyLock = 9002;
static NSInteger const MKPreferencesShortcutTagModeBase = 9100;
static NSInteger const MKPreferencesInputModeSwitchTagBase = 9200;
static NSTimeInterval const MKPreferencesShortcutDoubleTapInterval = 0.60;

static NSFont *MKFont(CGFloat size, NSFontWeight weight) {
    return [NSFont systemFontOfSize:size weight:weight];
}

static NSColor *MKColorFromRGB(NSUInteger rgb) {
    return [NSColor colorWithCalibratedRed:((rgb >> 16) & 0xFF) / 255.0
                                     green:((rgb >> 8) & 0xFF) / 255.0
                                      blue:(rgb & 0xFF) / 255.0
                                     alpha:1.0];
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
@property(nonatomic, strong) MKPreferencesSegmentedControl *spaceKeySegmentedControl;
@property(nonatomic, strong) MKPreferencesSwitchControl *learningSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *privacyLockSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *rawEnglishCandidateSwitch;
@property(nonatomic, strong) MKPreferencesSwitchControl *spellingSuggestionsSwitch;
@property(nonatomic, strong) MKPreferencesSegmentedControl *candidatePageSizeSegmentedControl;
@property(nonatomic, strong) MKPreferencesSegmentedControl *preferencesLanguageSegmentedControl;
@property(nonatomic, strong) NSTextField *learningStatusField;
@property(nonatomic, strong) NSTextField *privacyLockStatusField;
@property(nonatomic, strong) NSTextField *enabledInputModesNoticeField;
@property(nonatomic, strong) NSTextField *shortcutErrorField;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSImage *> *preferenceCoverImagesByFilename;
@property(nonatomic, strong) NSImage *cachedAppIconImage;
@property(nonatomic, strong) NSWindow *privacyPolicySheet;

- (void)rebuildSidebar;
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
        _tabIdentifiers = @[MKPreferencesTabGeneral,
                            MKPreferencesTabInputModes,
                            MKPreferencesTabTyping,
                            MKPreferencesTabPrivacyLearning,
                            MKPreferencesTabAbout];
        _sidebarButtonsByIdentifier = [NSMutableDictionary dictionary];
        _preferenceCoverImagesByFilename = [NSMutableDictionary dictionary];
        window.title = [self localizedString:@"PurrType Settings"];
        window.minSize = NSMakeSize(MKPreferencesMinimumWindowWidth, MKPreferencesMinimumWindowHeight);
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
    if (!self.window.visible) {
        [self.window setContentSize:NSMakeSize(MKPreferencesWindowWidth, MKPreferencesWindowHeight)];
    }
    [self showWindow:nil];
    [self.window center];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)reloadState {
    self.window.title = [self localizedString:@"PurrType Settings"];
    [self rebuildSidebar];
    [self rebuildContent];
}

- (void)buildWindowContent {
    MKPreferencesRootView *root = [[MKPreferencesRootView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = NO;
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

- (NSView *)generalView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_general.png"
                                             title:[self localizedString:@"General"]]
           toStack:stack];
    [self addContentView:[self overviewCard] toStack:stack];
    [self addContentView:[self generalBehaviorCard] toStack:stack];
    [self addContentView:[self enabledInputModesCard] toStack:stack];
    [self addContentView:[self globalShortcutsCard] toStack:stack];
    return view;
}

- (NSView *)inputModesView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_input_modes.png"
	                                             title:[self localizedString:@"Input Modes"]]
	           toStack:stack];
    [self addContentView:[self currentModeCard] toStack:stack];
    [self addContentView:[self candidatePageSizeCard] toStack:stack];
    [self addContentView:[self modeShortcutsCard] toStack:stack];
    return view;
}

- (NSView *)typingView {
    NSView *view = [self contentColumnView];
    NSStackView *stack = view.subviews.firstObject;
    [self addCoverView:[self coverCardWithFilename:@"pref_cover_typing.png"
                                             title:[self localizedString:@"Typing"]]
           toStack:stack];
    [self addContentView:[self compositionCard] toStack:stack];
    [self addContentView:[self spaceKeyCard] toStack:stack];
    [self addContentView:[self englishPassThroughCard] toStack:stack];
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
                                                         height:296
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    NSArray<NSString *> *modes = [PurrTypeInputBehavior orderedInputModes];
    for (NSUInteger index = 0; index < modes.count; index += 1) {
        NSString *mode = modes[index];
        MKPreferencesSwitchControl *toggle = [self switchControlWithState:[self isInputModeEnabled:mode]
                                                                   action:@selector(inputModeSwitchChanged:)];
        toggle.tag = MKPreferencesInputModeSwitchTagBase + (NSInteger)index;
        [stack addArrangedSubview:[self settingRowWithTitle:[self titleForInputMode:mode]
                                                     detail:[self localizedString:@"Included in global mode switching."]
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
                                                         height:260
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Switch Input Mode"]
                                                 detail:[self localizedString:@"Cycles Sucheng, New Sucheng, Cangjie, and Pinyin."]
                                                control:[self shortcutEditorWithSpec:[self.preferencesDelegate preferencesSwitchInputModeShortcut]
                                                                          defaultSpec:[PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec]
                                                                                  tag:MKPreferencesShortcutTagSwitchInputMode]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Pause Learning"]
                                                 detail:[self localizedString:@"Toggles Privacy Lock for sensitive typing."]
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

- (NSView *)generalBehaviorCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"General Behavior"]
                                                         symbol:@"gearshape"
                                                         height:146
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
    [self.preferencesLanguageSegmentedControl setWidth:70 forSegment:0];
    [self.preferencesLanguageSegmentedControl setWidth:70 forSegment:1];
    [self.preferencesLanguageSegmentedControl setWidth:124 forSegment:2];
    self.preferencesLanguageSegmentedControl.target = self;
    self.preferencesLanguageSegmentedControl.action = @selector(preferencesLanguageSegmentChanged:);
    [self syncPreferencesLanguageSegment];
    [self.preferencesLanguageSegmentedControl.widthAnchor constraintEqualToConstant:264].active = YES;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Preferences Language"]
                                                 detail:[self localizedString:@"Controls this preferences window."]
                                                control:self.preferencesLanguageSegmentedControl
                                                enabled:YES]];
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
    BOOL stacksControlVertically = control &&
                                   ([control isKindOfClass:[NSStackView class]] ||
                                    [control isKindOfClass:[MKPreferencesSegmentedControl class]]);
    NSTextField *titleLabel = [self labelWithText:title
                                             size:12
                                           weight:NSFontWeightRegular
                                            color:(enabled ? MKPreferencesPrimaryTextColor() : MKPreferencesSecondaryTextColor())];
    [titleLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
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
    if (detail.length > 0) {
        [row addSubview:detailLabel];
    }
    if (control) {
        control.translatesAutoresizingMaskIntoConstraints = NO;
        if (!enabled) {
            [self setControlsInView:control enabled:NO];
        }
        [row addSubview:control];
    }

    NSMutableArray<NSLayoutConstraint *> *constraints = [@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:(stacksControlVertically ? (detail.length > 0 ? 78 : 62) : (detail.length > 0 ? 40 : 34))],
        [titleLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:(detail.length > 0 ? 1 : 7)]
    ] mutableCopy];

    if (detail.length > 0) {
        [constraints addObjectsFromArray:@[
            [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
            [detailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:(stacksControlVertically || !control) ? row.trailingAnchor : control.leadingAnchor
                                                                  constant:(stacksControlVertically || !control) ? 0 : -12],
            [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:2],
            [detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor]
        ]];
    } else {
        [constraints addObject:[titleLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]];
    }

    if (control) {
        if (stacksControlVertically) {
            [constraints addObjectsFromArray:@[
                [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
                [control.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
                [control.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor],
                [control.topAnchor constraintEqualToAnchor:(detail.length > 0 ? detailLabel.bottomAnchor : titleLabel.bottomAnchor) constant:7],
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
    [recorder.widthAnchor constraintEqualToConstant:186].active = YES;
    [recorder.heightAnchor constraintEqualToConstant:30].active = YES;
    [row addArrangedSubview:recorder];

    NSButton *reset = [self secondaryButtonWithTitle:[self localizedString:@"Reset"] action:@selector(shortcutResetButtonClicked:)];
    reset.tag = tag;
    [reset.heightAnchor constraintEqualToConstant:28].active = YES;
    [row addArrangedSubview:reset];

    [row.widthAnchor constraintEqualToConstant:250].active = YES;
    return row;
}

- (NSView *)privacyShortcutReferenceControl {
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 6.0;
    MKPreferencesShortcutRecorderControl *display = [[MKPreferencesShortcutRecorderControl alloc] initWithFrame:NSZeroRect];
    display.translatesAutoresizingMaskIntoConstraints = NO;
    display.enabled = NO;
    display.shortcutSpec = [self.preferencesDelegate preferencesPrivacyLockShortcut];
    [display.widthAnchor constraintEqualToConstant:136].active = YES;
    [display.heightAnchor constraintEqualToConstant:30].active = YES;
    [row addArrangedSubview:display];
    NSButton *edit = [self secondaryButtonWithTitle:[self localizedString:@"Edit in General"] action:@selector(editPrivacyShortcutInGeneral:)];
    [edit.heightAnchor constraintEqualToConstant:28].active = YES;
    [edit.widthAnchor constraintEqualToConstant:126].active = YES;
    [row addArrangedSubview:edit];
    [row.widthAnchor constraintEqualToConstant:268].active = YES;
    return row;
}

- (NSStackView *)buttonRowWithButtons:(NSArray<NSButton *> *)buttons {
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = buttons.count > 1 ? NSUserInterfaceLayoutOrientationVertical : NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = buttons.count > 1 ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    row.spacing = buttons.count > 1 ? 8.0 : 10.0;
    for (NSButton *button in buttons) {
        [row addArrangedSubview:button];
    }
    return row;
}

- (NSStackView *)horizontalButtonRowWithButtons:(NSArray<NSButton *> *)buttons {
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8.0;
    for (NSButton *button in buttons) {
        [button setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                         forOrientation:NSLayoutConstraintOrientationHorizontal];
        [row addArrangedSubview:button];
    }
    return row;
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
                                                         height:150
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Escape cancels composition"]
                                                 detail:[self localizedString:@"Clears the active buffer without committing text."]
                                                control:[self readOnlyChipWithText:[self localizedString:@"Esc"]]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Enter commits raw input"]
                                                 detail:[self localizedString:@"Commits the typed code exactly as entered."]
                                                control:[self readOnlyChipWithText:[self localizedString:@"Return"]]
                                                enabled:YES]];
    return card;
}

- (NSView *)spaceKeyCard {
    NSTextField *title = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Space Key"]
                                                         symbol:@"keyboard"
                                                         height:116
                                                     titleLabel:&title];
    self.spaceKeySegmentedControl = [[MKPreferencesSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.spaceKeySegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.spaceKeySegmentedControl.segmentCount = 2;
    self.spaceKeySegmentedControl.trackingMode = NSSegmentSwitchTrackingSelectOne;
    self.spaceKeySegmentedControl.segmentStyle = NSSegmentStyleSeparated;
    self.spaceKeySegmentedControl.controlSize = NSControlSizeRegular;
    self.spaceKeySegmentedControl.font = MKFont(12, NSFontWeightRegular);
    [self.spaceKeySegmentedControl setLabel:[self localizedString:@"Commit first candidate"] forSegment:0];
    [self.spaceKeySegmentedControl setLabel:[self localizedString:@"Page candidates"] forSegment:1];
    [self.spaceKeySegmentedControl setWidth:150 forSegment:0];
    [self.spaceKeySegmentedControl setWidth:110 forSegment:1];
    self.spaceKeySegmentedControl.target = self;
    self.spaceKeySegmentedControl.action = @selector(spaceKeySegmentChanged:);
    self.spaceKeySegmentedControl.selectedSegment = [self.preferencesDelegate preferencesSpacePagingEnabled] ? 1 : 0;
    [card addSubview:self.spaceKeySegmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.spaceKeySegmentedControl.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.spaceKeySegmentedControl.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-24],
        [self.spaceKeySegmentedControl.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:16],
        [self.spaceKeySegmentedControl.widthAnchor constraintEqualToConstant:260]
    ]];
    return card;
}

- (NSView *)englishPassThroughCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"English Pass-through"]
                                                         symbol:@"globe"
                                                         height:260
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.rawEnglishCandidateSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesRawEnglishCandidateEnabled]
                                                           action:@selector(rawEnglishCandidateSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Show raw English candidate as 0"]
                                                 detail:[self localizedString:@"Keeps typed letters available when Chinese candidates exist."]
                                                control:self.rawEnglishCandidateSwitch
                                                enabled:YES]];
    self.spellingSuggestionsSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesSpellingSuggestionsEnabled]
                                                           action:@selector(spellingSuggestionsSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"English spelling suggestions"]
                                                detail:[self localizedString:@"Uses macOS spell checking locally and never auto-corrects."]
                                               control:self.spellingSuggestionsSwitch
                                               enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Temporary English with Shift"]
                                                detail:[self localizedString:@"Hold Shift while typing letters."]
                                                control:[self readOnlyChipWithText:[self localizedString:@"Shift"]]
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Keep URL / email / path in English"]
                                                detail:[self localizedString:@"URLs, emails, file paths and code-like text stay in English automatically."]
                                               control:[self readOnlyChipWithText:[self localizedString:@"Automatic"]]
                                               enabled:YES]];
    return card;
}

- (NSView *)protectedEnglishCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Protected English"]
                                                         symbol:@"checkmark.shield"
                                                         height:112
                                                     titleLabel:&titleLabel];
    NSTextField *note = [self wrappingLabelWithText:[self localizedString:@"URLs, emails, file paths and code-like text stay in English automatically."]
                                              size:13
                                            weight:NSFontWeightRegular
                                             color:MKPreferencesSecondaryTextColor()];
    [card addSubview:note];
    [NSLayoutConstraint activateConstraints:@[
        [note.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [note.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-24],
        [note.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16]
    ]];
    return card;
}

- (NSView *)learningCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Learning"]
                                                         symbol:@"brain"
                                                         height:112
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.learningSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesLearningEnabled]
                                                action:@selector(learningSwitchChanged:)];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Enable New Sucheng learning"]
                                                 detail:[self localizedString:@"Stores hashed ranking data locally only."]
                                                control:self.learningSwitch
                                                enabled:YES]];
    return card;
}

- (NSView *)privacyLockSettingsCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Privacy Lock"]
                                                         symbol:@"lock"
                                                         height:210
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    self.privacyLockSwitch = [self switchControlWithState:[self.preferencesDelegate preferencesPrivacyLockEnabled]
                                                   action:@selector(privacyLockSwitchChanged:)];
    self.privacyLockStatusField = nil;
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Pause learning immediately"]
                                                 detail:[self privacyLockStatusText]
                                                control:self.privacyLockSwitch
                                                enabled:YES]];
    [stack addArrangedSubview:[self settingRowWithTitle:[self localizedString:@"Current shortcut"]
                                                 detail:[self localizedString:@"Configured in General."]
                                                control:[self privacyShortcutReferenceControl]
                                                enabled:YES]];
    return card;
}

- (NSView *)dataCard {
    NSTextField *titleLabel = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Data"]
                                                         symbol:@"externaldrive"
                                                         height:146
                                                     titleLabel:&titleLabel];
    NSStackView *stack = [self bodyStackInCard:card belowTitle:titleLabel];
    NSButton *reset = [self prominentButtonWithTitle:[self localizedString:@"Reset Learning Data"] action:@selector(resetLearning:)];
    NSMutableArray<NSButton *> *buttons = [NSMutableArray arrayWithObject:reset];
    if ([self privacyPolicyURL]) {
        [buttons addObject:[self linkButtonWithTitle:[self localizedString:@"Open Privacy Policy"] action:@selector(openPrivacyPolicy:)]];
    }
    [stack addArrangedSubview:[self buttonRowWithButtons:buttons]];
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
    NSStackView *buttonRow = [self horizontalButtonRowWithButtons:buttons];
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
    [self.modeSegmentedControl setWidth:60 forSegment:0];
    [self.modeSegmentedControl setWidth:86 forSegment:1];
    [self.modeSegmentedControl setWidth:68 forSegment:2];
    [self.modeSegmentedControl setWidth:60 forSegment:3];
    self.modeSegmentedControl.target = self;
    self.modeSegmentedControl.action = @selector(modeSegmentChanged:);
    [self syncModeSegment];
    [card addSubview:self.modeSegmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.modeSegmentedControl.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.modeSegmentedControl.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [self.modeSegmentedControl.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14],
        [self.modeSegmentedControl.widthAnchor constraintEqualToConstant:274]
    ]];
    return card;
}

- (NSView *)modeShortcutsCard {
    NSTextField *title = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Mode Shortcuts"]
                                                         symbol:@"keyboard"
                                                         height:430
                                                     titleLabel:&title];

    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    NSArray<NSString *> *titles = @[
        [self localizedString:@"Sucheng"],
        [self localizedString:@"New Sucheng"],
        [self localizedString:@"Cangjie"],
        [self localizedString:@"Pinyin"]
    ];
    NSDictionary<NSString *, NSString *> *shortcuts = [self.preferencesDelegate preferencesModeShortcutsByMode] ?: @{};

    NSStackView *stack = [self bodyStackInCard:card belowTitle:title];
    for (NSUInteger index = 0; index < modes.count; index += 1) {
        NSString *mode = modes[index];
        NSString *shortcut = shortcuts[mode] ?: [PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode];
        BOOL modeEnabled = [self isInputModeEnabled:mode];
        [stack addArrangedSubview:[self settingRowWithTitle:titles[index]
                                                     detail:[self localizedString:(modeEnabled ? @"Directly switches to this mode." : @"Inactive while this mode is disabled in General.")]
                                                    control:[self shortcutEditorWithSpec:shortcut
                                                                              defaultSpec:[PurrTypeInputBehavior defaultModeShortcutSpecForMode:mode]
                                                                                      tag:MKPreferencesShortcutTagModeBase + (NSInteger)index]
                                                    enabled:modeEnabled]];
    }
    self.shortcutErrorField = [self wrappingLabelWithText:@""
                                                     size:11
                                                   weight:NSFontWeightRegular
                                                    color:NSColor.systemRedColor];
    self.shortcutErrorField.hidden = YES;
    [stack addArrangedSubview:self.shortcutErrorField];
    return card;
}

- (NSView *)candidatePageSizeCard {
    NSTextField *title = nil;
    MKPreferencesCardView *card = [self preferenceCardWithTitle:[self localizedString:@"Candidate Page Size"]
                                                         symbol:@"list.bullet"
                                                         height:108
                                                     titleLabel:&title];
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

    [card addSubview:self.candidatePageSizeSegmentedControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.candidatePageSizeSegmentedControl.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.candidatePageSizeSegmentedControl.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-18],
        [self.candidatePageSizeSegmentedControl.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14],
        [self.candidatePageSizeSegmentedControl.widthAnchor constraintEqualToConstant:116]
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
    return label;
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
    [self reloadState];
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
    [self syncModeSegment];
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

- (void)spellingSuggestionsSwitchChanged:(MKPreferencesSwitchControl *)sender {
    [self.preferencesDelegate preferencesSetSpellingSuggestionsEnabled:(sender.state == NSControlStateValueOn)];
}

- (void)spaceKeySegmentChanged:(MKPreferencesSegmentedControl *)sender {
    [self.preferencesDelegate preferencesSetSpacePagingEnabled:(sender.selectedSegment == 1)];
}

- (void)candidatePageSizeSegmentChanged:(MKPreferencesSegmentedControl *)sender {
    NSUInteger pageSize = sender.selectedSegment == 0 ? 5 : 9;
    [self.preferencesDelegate preferencesSetCandidatePageSize:pageSize];
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
        return;
    }

    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:fileURL
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (text.length == 0) {
        [self showPrivacyPolicyReadErrorForURL:fileURL error:error];
        return;
    }

    [self showPrivacyPolicyText:text sourceURL:fileURL];
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
