#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEngine.h"
#import "../src/PurrTypeInputBehavior.h"
#import "../src/PurrTypePreferencesConstants.h"
#import "../src/PurrTypePreferencesWindowController.h"
#import "../src/PurrTypeQuickPhraseStore.h"
#include <math.h>

static NSInteger const MKPreferencesTestShortcutTagSwitchInputMode = 9001;
static NSInteger const MKPreferencesTestShortcutTagPrivacyLock = 9002;
static NSInteger const MKPreferencesTestShortcutTagModeBase = 9100;
static CGFloat const MKPreferencesExpectedCoverAspectRatio = 1672.0 / 941.0;
static CGFloat const MKPreferencesExpectedCoverMaxWidth = 380.0;

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface PreferencesTestDelegate : NSObject <PurrTypePreferencesWindowControllerDelegate>
@property(nonatomic, copy) NSString *mode;
@property(nonatomic, assign) BOOL learningEnabled;
@property(nonatomic, assign) BOOL privacyLockEnabled;
@property(nonatomic, assign) BOOL rawEnglishCandidateEnabled;
@property(nonatomic, assign) BOOL spellingSuggestionsEnabled;
@property(nonatomic, assign) BOOL spacePagingEnabled;
@property(nonatomic, assign) NSUInteger candidatePageSize;
@property(nonatomic, copy) NSString *candidatePanelOrientation;
@property(nonatomic, assign) CGFloat candidatePanelFontSize;
@property(nonatomic, copy) NSString *candidatePanelHighlightColor;
@property(nonatomic, assign) BOOL associationCandidatesEnabled;
@property(nonatomic, assign) BOOL associationContinuationEnabled;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *modeCandidatePageSizeOverrides;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *modeSpaceKeyOverrides;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *modeClearReadingOverrides;
@property(nonatomic, copy) NSArray<NSString *> *enabledInputModes;
@property(nonatomic, copy) NSString *switchInputModeShortcut;
@property(nonatomic, copy) NSString *privacyLockShortcut;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *modeShortcutsByMode;
@property(nonatomic, assign) NSUInteger modeChangeCount;
@property(nonatomic, assign) NSUInteger privacyLockChangeCount;
@property(nonatomic, assign) NSUInteger privacyLockShortcutChangeCount;
@property(nonatomic, assign) NSUInteger switchInputModeShortcutChangeCount;
@property(nonatomic, assign) NSUInteger modeShortcutChangeCount;
@property(nonatomic, assign) NSUInteger rawEnglishChangeCount;
@property(nonatomic, assign) NSUInteger spellingSuggestionsChangeCount;
@property(nonatomic, assign) NSUInteger spacePagingChangeCount;
@property(nonatomic, assign) NSUInteger candidatePageSizeChangeCount;
@property(nonatomic, assign) NSUInteger candidatePanelOrientationChangeCount;
@property(nonatomic, assign) NSUInteger candidatePanelFontSizeChangeCount;
@property(nonatomic, assign) NSUInteger candidatePanelHighlightChangeCount;
@property(nonatomic, assign) NSUInteger associationCandidatesChangeCount;
@property(nonatomic, assign) NSUInteger associationContinuationChangeCount;
@property(nonatomic, assign) NSUInteger modeCandidatePageSizeOverrideChangeCount;
@property(nonatomic, assign) NSUInteger modeSpaceKeyOverrideChangeCount;
@property(nonatomic, assign) NSUInteger modeClearReadingChangeCount;
@property(nonatomic, assign) NSUInteger modeResetCount;
@property(nonatomic, assign) NSUInteger enabledInputModesChangeCount;
@end

@implementation PreferencesTestDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _mode = MKInputModeSucheng;
        _rawEnglishCandidateEnabled = YES;
        _spellingSuggestionsEnabled = YES;
        _spacePagingEnabled = YES;
        _candidatePageSize = 9;
        _candidatePanelOrientation = MKCandidatePanelOrientationVertical;
        _candidatePanelFontSize = 17.0;
        _candidatePanelHighlightColor = MKCandidatePanelHighlightRed;
        _associationCandidatesEnabled = YES;
        _associationContinuationEnabled = YES;
        _modeCandidatePageSizeOverrides = [NSMutableDictionary dictionary];
        _modeSpaceKeyOverrides = [NSMutableDictionary dictionary];
        _modeClearReadingOverrides = [NSMutableDictionary dictionary];
        _enabledInputModes = [PurrTypeInputBehavior defaultEnabledInputModes];
        _switchInputModeShortcut = [PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec];
        _privacyLockShortcut = @"double_backtick";
        _modeShortcutsByMode = [@{
            MKInputModeSucheng: @"ctrl_shift_1",
            MKInputModeSmartSucheng: @"ctrl_shift_2",
            MKInputModeCangjie: @"ctrl_shift_3",
            MKInputModePinyin: @"ctrl_shift_4"
        } mutableCopy];
    }
    return self;
}

- (NSString *)preferencesCurrentMode {
    return self.mode;
}

- (void)preferencesSwitchToMode:(NSString *)mode {
    self.mode = mode;
    self.modeChangeCount += 1;
}

- (BOOL)preferencesLearningEnabled {
    return self.learningEnabled;
}

- (void)preferencesSetLearningEnabled:(BOOL)enabled {
    self.learningEnabled = enabled;
}

- (BOOL)preferencesPrivacyLockEnabled {
    return self.privacyLockEnabled;
}

- (void)preferencesSetPrivacyLockEnabled:(BOOL)enabled {
    self.privacyLockEnabled = enabled;
    self.privacyLockChangeCount += 1;
}

- (BOOL)preferencesRawEnglishCandidateEnabled {
    return self.rawEnglishCandidateEnabled;
}

- (void)preferencesSetRawEnglishCandidateEnabled:(BOOL)enabled {
    self.rawEnglishCandidateEnabled = enabled;
    self.rawEnglishChangeCount += 1;
}

- (BOOL)preferencesSpellingSuggestionsEnabled {
    return self.spellingSuggestionsEnabled;
}

- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled {
    self.spellingSuggestionsEnabled = enabled;
    self.spellingSuggestionsChangeCount += 1;
}

- (BOOL)preferencesSpacePagingEnabled {
    return self.spacePagingEnabled;
}

- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled {
    self.spacePagingEnabled = enabled;
    self.spacePagingChangeCount += 1;
}

- (NSUInteger)preferencesCandidatePageSize {
    return self.candidatePageSize;
}

- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize {
    self.candidatePageSize = pageSize;
    self.candidatePageSizeChangeCount += 1;
}

- (NSString *)preferencesCandidatePanelOrientation {
    return self.candidatePanelOrientation;
}

- (void)preferencesSetCandidatePanelOrientation:(NSString *)orientation {
    self.candidatePanelOrientation = orientation;
    self.candidatePanelOrientationChangeCount += 1;
}

- (CGFloat)preferencesCandidatePanelFontSize {
    return self.candidatePanelFontSize;
}

- (void)preferencesSetCandidatePanelFontSize:(CGFloat)fontSize {
    self.candidatePanelFontSize = fontSize;
    self.candidatePanelFontSizeChangeCount += 1;
}

- (NSString *)preferencesCandidatePanelHighlightColor {
    return self.candidatePanelHighlightColor;
}

- (void)preferencesSetCandidatePanelHighlightColor:(NSString *)highlightColor {
    self.candidatePanelHighlightColor = highlightColor;
    self.candidatePanelHighlightChangeCount += 1;
}

- (BOOL)preferencesAssociationCandidatesEnabled {
    return self.associationCandidatesEnabled;
}

- (void)preferencesSetAssociationCandidatesEnabled:(BOOL)enabled {
    self.associationCandidatesEnabled = enabled;
    self.associationCandidatesChangeCount += 1;
}

- (BOOL)preferencesAssociationContinuationEnabled {
    return self.associationContinuationEnabled;
}

- (void)preferencesSetAssociationContinuationEnabled:(BOOL)enabled {
    self.associationContinuationEnabled = enabled;
    self.associationContinuationChangeCount += 1;
}

- (NSUInteger)preferencesCandidatePageSizeOverrideForMode:(NSString *)mode {
    return self.modeCandidatePageSizeOverrides[mode].unsignedIntegerValue;
}

- (void)preferencesSetCandidatePageSizeOverride:(NSUInteger)pageSize forMode:(NSString *)mode {
    if (pageSize == 0) {
        [self.modeCandidatePageSizeOverrides removeObjectForKey:mode];
    } else {
        self.modeCandidatePageSizeOverrides[mode] = @(pageSize);
    }
    self.modeCandidatePageSizeOverrideChangeCount += 1;
}

- (NSString *)preferencesSpaceKeyOverrideForMode:(NSString *)mode {
    return self.modeSpaceKeyOverrides[mode] ?: MKModeOverrideFollowGlobal;
}

- (void)preferencesSetSpaceKeyOverride:(NSString *)overrideValue forMode:(NSString *)mode {
    if ([overrideValue isEqualToString:MKModeOverrideFollowGlobal]) {
        [self.modeSpaceKeyOverrides removeObjectForKey:mode];
    } else {
        self.modeSpaceKeyOverrides[mode] = overrideValue;
    }
    self.modeSpaceKeyOverrideChangeCount += 1;
}

- (BOOL)preferencesClearReadingOnCompositionFailureEnabledForMode:(NSString *)mode {
    return self.modeClearReadingOverrides[mode].boolValue;
}

- (void)preferencesSetClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode {
    if (enabled) {
        self.modeClearReadingOverrides[mode] = @YES;
    } else {
        [self.modeClearReadingOverrides removeObjectForKey:mode];
    }
    self.modeClearReadingChangeCount += 1;
}

- (void)preferencesResetOverridesForMode:(NSString *)mode {
    [self.modeCandidatePageSizeOverrides removeObjectForKey:mode];
    [self.modeSpaceKeyOverrides removeObjectForKey:mode];
    [self.modeClearReadingOverrides removeObjectForKey:mode];
    self.modeResetCount += 1;
}

- (NSArray<NSString *> *)preferencesEnabledInputModes {
    return self.enabledInputModes;
}

- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    self.enabledInputModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledInputModes];
    if (![self.enabledInputModes containsObject:self.mode]) {
        self.mode = self.enabledInputModes.firstObject ?: MKInputModeSucheng;
    }
    self.enabledInputModesChangeCount += 1;
}

- (NSString *)preferencesSwitchInputModeShortcut {
    return self.switchInputModeShortcut;
}

- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec {
    self.switchInputModeShortcut = shortcutSpec;
    self.switchInputModeShortcutChangeCount += 1;
}

- (NSString *)preferencesPrivacyLockShortcut {
    return self.privacyLockShortcut;
}

- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec {
    self.privacyLockShortcut = shortcutSpec;
    self.privacyLockShortcutChangeCount += 1;
}

- (NSDictionary<NSString *, NSString *> *)preferencesModeShortcutsByMode {
    return self.modeShortcutsByMode;
}

- (void)preferencesSetModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode {
    self.modeShortcutsByMode[mode] = shortcutSpec;
    self.modeShortcutChangeCount += 1;
}

- (void)preferencesResetLearning {
}

@end

static void CollectViewsOfClass(NSView *view, Class viewClass, NSMutableArray<NSView *> *results) {
    if ([view isKindOfClass:viewClass]) {
        [results addObject:view];
    }
    for (NSView *subview in view.subviews) {
        CollectViewsOfClass(subview, viewClass, results);
    }
}

static NSArray<NSView *> *ViewsOfClass(NSView *root, Class viewClass) {
    NSMutableArray<NSView *> *results = [NSMutableArray array];
    CollectViewsOfClass(root, viewClass, results);
    return results;
}

static NSArray<NSButton *> *SidebarButtons(NSView *root) {
    Class sidebarButtonClass = NSClassFromString(@"MKPreferencesSidebarButton");
    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    for (NSView *view in ViewsOfClass(root, sidebarButtonClass)) {
        [buttons addObject:(NSButton *)view];
    }
    return buttons;
}

static NSScrollView *CurrentScrollView(NSView *root) {
    NSArray<NSView *> *scrollViews = ViewsOfClass(root, [NSScrollView class]);
    return scrollViews.count == 1 ? (NSScrollView *)scrollViews[0] : nil;
}

static Class PreferencesSwitchClass(void) {
    return NSClassFromString(@"MKPreferencesSwitchControl");
}

static Class PreferencesSegmentedControlClass(void) {
    return NSClassFromString(@"MKPreferencesSegmentedControl");
}

static Class PreferencesShortcutRecorderClass(void) {
    return NSClassFromString(@"MKPreferencesShortcutRecorderControl");
}

static NSArray<NSControl *> *EnabledSwitches(NSView *root) {
    NSMutableArray<NSControl *> *switches = [NSMutableArray array];
    for (NSView *view in ViewsOfClass(root, PreferencesSwitchClass())) {
        NSControl *toggle = (NSControl *)view;
        if (toggle.enabled) {
            [switches addObject:toggle];
        }
    }
    return switches;
}

static NSControl *FindSegmentedControl(NSView *root, NSArray<NSString *> *labels) {
    for (NSView *view in ViewsOfClass(root, PreferencesSegmentedControlClass())) {
        id control = (id)view;
        if ([[control valueForKey:@"segmentCount"] integerValue] != (NSInteger)labels.count) {
            continue;
        }

        BOOL matches = YES;
        for (NSUInteger index = 0; index < labels.count; index += 1) {
            if (![[control labelForSegment:(NSInteger)index] isEqualToString:labels[index]]) {
                matches = NO;
                break;
            }
        }
        if (matches) {
            return (NSControl *)view;
        }
    }
    return nil;
}

static void SelectSegmentAndSend(NSControl *control, NSInteger selectedSegment) {
    [control setValue:@(selectedSegment) forKey:@"selectedSegment"];
    [control sendAction:control.action to:control.target];
}

static void SetSwitchStateAndSend(NSControl *toggle, NSControlStateValue state) {
    [toggle setValue:@(state) forKey:@"state"];
    [toggle sendAction:toggle.action to:toggle.target];
}

static NSControl *FindShortcutRecorder(NSView *root, NSInteger tag) {
    for (NSView *view in ViewsOfClass(root, PreferencesShortcutRecorderClass())) {
        NSControl *recorder = (NSControl *)view;
        if (recorder.enabled && recorder.tag == tag) {
            return recorder;
        }
    }
    return nil;
}

static void SetShortcutAndSend(NSControl *recorder, NSString *shortcutSpec) {
    [recorder setValue:shortcutSpec forKey:@"shortcutSpec"];
    [recorder sendAction:recorder.action to:recorder.target];
}

static void RecordShortcutWithKey(NSControl *recorder, NSWindow *window, NSUInteger flags, NSInteger keyCode, NSString *characters) {
    NSPoint localPoint = NSMakePoint(4.0, 4.0);
    NSPoint windowPoint = [recorder convertPoint:localPoint toView:nil];
    NSEvent *mouseEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                             location:windowPoint
                                        modifierFlags:0
                                            timestamp:0
                                         windowNumber:window.windowNumber
                                              context:nil
                                          eventNumber:1
                                           clickCount:1
                                             pressure:1.0];
    [recorder mouseDown:mouseEvent];
    AssertTrue([[recorder valueForKey:@"recording"] boolValue], @"clicking shortcut recorder enters recording state");

    NSEvent *keyEvent = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                         location:NSZeroPoint
                                    modifierFlags:flags
                                        timestamp:0
                                     windowNumber:window.windowNumber
                                          context:nil
                                       characters:characters
                      charactersIgnoringModifiers:characters
                                        isARepeat:NO
                                          keyCode:(unsigned short)keyCode];
    [recorder keyDown:keyEvent];
}

static NSButton *FindSidebarButton(NSView *root, NSString *title) {
    for (NSButton *button in SidebarButtons(root)) {
        if ([button.title isEqualToString:title]) {
            return button;
        }
    }
    return nil;
}

static NSButton *FindButton(NSView *root, NSString *title) {
    Class sidebarButtonClass = NSClassFromString(@"MKPreferencesSidebarButton");
    for (NSView *view in ViewsOfClass(root, [NSButton class])) {
        if ([view isKindOfClass:sidebarButtonClass]) {
            continue;
        }
        NSButton *button = (NSButton *)view;
        if ([button.title isEqualToString:title]) {
            return button;
        }
    }
    return nil;
}

static NSTextField *FindTextFieldWithPlaceholder(NSView *root, NSString *placeholder) {
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *textField = (NSTextField *)view;
        if ([textField.placeholderString isEqualToString:placeholder]) {
            return textField;
        }
    }
    return nil;
}

static BOOL LabelWithTextExists(NSView *root, NSString *text) {
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if ([label.stringValue isEqualToString:text]) {
            return YES;
        }
    }
    return NO;
}

static void SwitchToSidebarItem(NSView *root, NSString *title) {
    NSButton *button = FindSidebarButton(root, title);
    AssertTrue(button != nil, [NSString stringWithFormat:@"sidebar exposes %@", title]);
    [button sendAction:button.action to:button.target];
}

static BOOL CardsHaveUsableFrames(NSView *root) {
    Class cardClass = NSClassFromString(@"MKPreferencesCardView");
    NSArray<NSView *> *cards = ViewsOfClass(root, cardClass);
    if (cards.count == 0) {
        NSLog(@"No preference cards found");
        return NO;
    }

    for (NSView *card in cards) {
        if (NSWidth(card.frame) < 300 || NSHeight(card.frame) < 70) {
            NSLog(@"Preference card has unusable frame: %@", NSStringFromRect(card.frame));
            NSLog(@"Card superview frame: %@", NSStringFromRect(card.superview.frame));
            NSLog(@"Card document frame: %@", NSStringFromRect(card.enclosingScrollView.documentView.frame));
            return NO;
        }
    }
    return YES;
}

static BOOL RightPaneHasNoHorizontalOverflow(NSView *root) {
    NSArray<NSView *> *scrollViews = ViewsOfClass(root, [NSScrollView class]);
    if (scrollViews.count != 1) {
        NSLog(@"Expected one scroll view, found %@", @(scrollViews.count));
        return NO;
    }

    NSScrollView *scrollView = (NSScrollView *)scrollViews[0];
    CGFloat clipWidth = NSWidth(scrollView.contentView.bounds);
    if (clipWidth <= 0.0) {
        clipWidth = NSWidth(scrollView.bounds);
    }
    if (clipWidth <= 0.0) {
        clipWidth = MAX(0.0, NSWidth(root.bounds) - 150.0);
    }
    CGFloat documentWidth = NSWidth(scrollView.documentView.frame);
    if (documentWidth > clipWidth + 1.0) {
        NSLog(@"Document view overflows horizontally: clip=%@ document=%@",
              @(clipWidth),
              @(documentWidth));
        return NO;
    }

    Class cardClass = NSClassFromString(@"MKPreferencesCardView");
    for (NSView *card in ViewsOfClass(root, cardClass)) {
        NSRect frameInDocument = [card.superview convertRect:card.frame toView:scrollView.documentView];
        if (NSMinX(frameInDocument) < -1.0 || NSMaxX(frameInDocument) > documentWidth + 1.0) {
            NSLog(@"Card exceeds document width: card=%@ documentWidth=%@",
                  NSStringFromRect(frameInDocument),
                  @(documentWidth));
            return NO;
        }
    }
    return YES;
}

static BOOL CoverUsesArtworkAspectRatio(NSView *root) {
    Class coverClass = NSClassFromString(@"MKPreferencesCoverView");
    NSArray<NSView *> *covers = ViewsOfClass(root, coverClass);
    if (covers.count != 1) {
        NSLog(@"Expected one preference cover view, found %@", @(covers.count));
        return NO;
    }

    NSView *cover = covers[0];
    CGFloat width = NSWidth(cover.frame);
    CGFloat height = NSHeight(cover.frame);
    if (width <= 0.0 || height <= 0.0) {
        NSLog(@"Preference cover has empty frame: %@", NSStringFromRect(cover.frame));
        return NO;
    }

    CGFloat ratio = width / height;
    if (fabs(ratio - MKPreferencesExpectedCoverAspectRatio) > 0.02) {
        NSLog(@"Preference cover aspect ratio is %@, expected %@. Frame: %@",
              @(ratio),
              @(MKPreferencesExpectedCoverAspectRatio),
              NSStringFromRect(cover.frame));
        return NO;
    }

    if (width > MKPreferencesExpectedCoverMaxWidth + 1.0) {
        NSLog(@"Preference cover exceeds max visual width: %@", NSStringFromRect(cover.frame));
        return NO;
    }

    return YES;
}

static BOOL LabelWithTextHasMinimumHeight(NSView *root, NSString *text, CGFloat minimumHeight) {
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if (![label.stringValue isEqualToString:text]) {
            continue;
        }

        if (NSHeight(label.frame) + 0.5 >= minimumHeight) {
            return YES;
        }

        NSLog(@"Label %@ is clipped-risk height: %@", text, NSStringFromRect(label.frame));
        return NO;
    }

    NSLog(@"Label not found: %@", text);
    return NO;
}

static BOOL SidebarLabelWithTextHasIntrinsicWidth(NSView *root, NSString *text) {
    NSScrollView *scrollView = CurrentScrollView(root);
    if (!scrollView) {
        NSLog(@"Sidebar width check needs the current scroll view");
        return NO;
    }

    NSRect scrollFrame = [scrollView.superview convertRect:scrollView.frame toView:root];
    CGFloat sidebarMaxX = NSMinX(scrollFrame);
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if (![label.stringValue isEqualToString:text]) {
            continue;
        }

        NSRect frame = [label.superview convertRect:label.frame toView:root];
        if (NSMidX(frame) >= sidebarMaxX) {
            continue;
        }

        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSFontAttributeName: label.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]]
        };
        CGFloat requiredWidth = ceil([label.stringValue sizeWithAttributes:attributes].width);
        if (NSWidth(label.frame) + 0.5 >= requiredWidth) {
            return YES;
        }

        NSLog(@"Sidebar label %@ is clipped-risk width: %@ required=%@",
              text,
              NSStringFromRect(label.frame),
              @(requiredWidth));
        return NO;
    }

    NSLog(@"Sidebar label not found: %@", text);
    return NO;
}

static NSImageView *FindImageViewWithAccessibilityLabel(NSView *root, NSString *label) {
    for (NSView *view in ViewsOfClass(root, [NSImageView class])) {
        NSImageView *imageView = (NSImageView *)view;
        if ([[imageView accessibilityLabel] isEqualToString:label]) {
            return imageView;
        }
    }
    return nil;
}

static NSRect FrameInView(NSView *view, NSView *root) {
    return [view.superview convertRect:view.frame toView:root];
}

static NSTextField *FindContentLabel(NSView *root, NSString *text) {
    NSScrollView *scrollView = CurrentScrollView(root);
    CGFloat contentMinX = 0.0;
    if (scrollView) {
        NSRect scrollFrame = [scrollView.superview convertRect:scrollView.frame toView:root];
        contentMinX = NSMinX(scrollFrame);
    }

    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if (![label.stringValue isEqualToString:text]) {
            continue;
        }

        NSRect frame = FrameInView(label, root);
        if (NSMidX(frame) >= contentMinX) {
            return label;
        }
    }
    return nil;
}

static BOOL ContentLabelWithTextHasIntrinsicWidth(NSView *root, NSString *text) {
    NSTextField *label = FindContentLabel(root, text);
    if (!label) {
        NSLog(@"Content label not found: %@", text);
        return NO;
    }

    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: label.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]]
    };
    CGFloat requiredWidth = ceil([label.stringValue sizeWithAttributes:attributes].width);
    if (NSWidth(label.frame) + 0.5 >= requiredWidth) {
        return YES;
    }

    NSLog(@"Content label %@ is clipped-risk width: %@ required=%@",
          text,
          NSStringFromRect(label.frame),
          @(requiredWidth));
    return NO;
}

static BOOL ViewLeadingMatchesContentLabel(NSView *root, NSView *view, NSString *text, CGFloat tolerance) {
    NSTextField *label = FindContentLabel(root, text);
    if (!label || !view) {
        NSLog(@"Cannot compare leading for %@ label=%@ view=%@", text, label, view);
        return NO;
    }

    CGFloat labelX = NSMinX(FrameInView(label, root));
    CGFloat viewX = NSMinX(FrameInView(view, root));
    if (fabs(labelX - viewX) <= tolerance) {
        return YES;
    }

    NSLog(@"View leading does not match %@: labelX=%@ viewX=%@",
          text,
          @(labelX),
          @(viewX));
    return NO;
}

static BOOL ButtonHasReadableWidth(NSButton *button) {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: button.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]]
    };
    CGFloat requiredWidth = ceil([button.title sizeWithAttributes:attributes].width) + 28.0;
    if (NSWidth(button.frame) + 0.5 >= requiredWidth) {
        return YES;
    }

    NSLog(@"Button %@ is clipped-risk width: %@ required=%@",
          button.title,
          NSStringFromRect(button.frame),
          @(requiredWidth));
    return NO;
}

static BOOL WindowContentSizeMatches(NSWindow *window, NSSize expectedSize) {
    NSRect contentRect = [window contentRectForFrameRect:window.frame];
    if (fabs(NSWidth(contentRect) - expectedSize.width) < 1.0 &&
        fabs(NSHeight(contentRect) - expectedSize.height) < 1.0) {
        return YES;
    }

    NSLog(@"Window content size mismatch actual=%@ expected=%@ frame=%@",
          NSStringFromSize(contentRect.size),
          NSStringFromSize(expectedSize),
          NSStringFromSize(window.frame.size));
    return NO;
}

static void FlushWindowLayout(NSWindow *window) {
    [window.contentView setNeedsLayout:YES];
    [window.contentView layoutSubtreeIfNeeded];
    [window displayIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    [window.contentView layoutSubtreeIfNeeded];
    for (NSView *view in ViewsOfClass(window.contentView, [NSScrollView class])) {
        NSScrollView *scrollView = (NSScrollView *)view;
        [scrollView.documentView setNeedsLayout:YES];
        [scrollView.documentView layoutSubtreeIfNeeded];
    }
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];

        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        NSString *learningPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"PurrTypePreferencesTests-%@.json", [NSUUID UUID].UUIDString]];
        NSString *quickPhraseDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"PurrTypePreferencesQuickPhrases-%@", [NSUUID UUID].UUIDString]];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MKUserDefaultsSuiteName] ?: [NSUserDefaults standardUserDefaults];
        [defaults setObject:@"zh-Hant" forKey:MKUserDefaultPreferencesLanguageKey];
        [defaults synchronize];
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                            pinyinPath:pinyinPath
                                                                          learningPath:learningPath];
        PreferencesTestDelegate *delegate = [[PreferencesTestDelegate alloc] init];
        PurrTypePreferencesWindowController *controller = [[PurrTypePreferencesWindowController alloc] init];
        PurrTypeQuickPhraseStore *preferencesQuickPhraseStore = [[PurrTypeQuickPhraseStore alloc] initWithDirectoryPath:quickPhraseDirectory];
        [controller setValue:preferencesQuickPhraseStore forKey:@"quickPhraseStore"];
        [controller showWithEngine:engine delegate:delegate];
        FlushWindowLayout(controller.window);
        NSSize standardPreferencesContentSize = NSMakeSize(622.0, 720.0);
        NSRect initialContentRect = [controller.window contentRectForFrameRect:controller.window.frame];
        CGFloat initialAspectRatio = NSWidth(initialContentRect) / NSHeight(initialContentRect);
        CGFloat minimumContentHeight = NSHeight([controller.window contentRectForFrameRect:
            NSMakeRect(0, 0, controller.window.minSize.width, controller.window.minSize.height)]);
        AssertTrue(WindowContentSizeMatches(controller.window, standardPreferencesContentSize),
                   @"preferences window opens at the fixed standard content size");
        AssertTrue(NSWidth(initialContentRect) <= 650 &&
                   NSHeight(initialContentRect) >= minimumContentHeight &&
                   initialAspectRatio < 1.0,
                   @"preferences window opens in a compact portrait proportion");
        AssertTrue(controller.window.minSize.width <= 622 && controller.window.minSize.height >= 620,
                   @"preferences window keeps compact minimum portrait bounds");

        NSView *rootView = controller.window.contentView;
        AssertTrue([controller.window.title isEqualToString:@"PurrType 設定"], @"preferences window title is localized to Traditional Chinese");
        AssertTrue(SidebarLabelWithTextHasIntrinsicWidth(rootView, @"PurrType"), @"preferences sidebar brand name is fully visible");
        AssertTrue(SidebarButtons(rootView).count == 5, @"preferences window exposes exactly five sidebar items");
        AssertTrue(FindSidebarButton(rootView, @"一般") != nil, @"preferences sidebar exposes General");
        AssertTrue(FindSidebarButton(rootView, @"輸入模式") != nil, @"preferences sidebar exposes Input Modes");
        AssertTrue(FindSidebarButton(rootView, @"打字") != nil, @"preferences sidebar exposes Typing");
        AssertTrue(FindSidebarButton(rootView, @"私隱與學習") != nil, @"preferences sidebar exposes Privacy & Learning");
        AssertTrue(FindSidebarButton(rootView, @"關於") != nil, @"preferences sidebar exposes About");
        AssertTrue(FindSidebarButton(rootView, @"Candidates") == nil, @"preferences sidebar does not expose Candidates");
        AssertTrue(FindSidebarButton(rootView, @"Shortcuts") == nil, @"preferences sidebar does not expose Shortcuts");
        AssertTrue(FindSidebarButton(rootView, @"Appearance") == nil, @"preferences sidebar does not expose Appearance");
        AssertTrue([ViewsOfClass(rootView, [NSVisualEffectView class]) count] == 0, @"preferences sidebar avoids vibrancy so it stays readable in dark mode");
        AssertTrue([ViewsOfClass(rootView, [NSScrollView class]) count] == 1, @"General tab is scrollable by default");
        AssertTrue([ViewsOfClass(rootView, NSClassFromString(@"MKPreferencesCoverView")) count] == 1, @"General tab exposes one cover image view by default");
        AssertTrue(CoverUsesArtworkAspectRatio(rootView), @"General cover uses the full artwork aspect ratio");
        [controller.window setContentSize:NSMakeSize(900, 720)];
        FlushWindowLayout(controller.window);
        AssertTrue(CoverUsesArtworkAspectRatio(rootView), @"General cover remains capped and proportional in wider windows");
        [controller.window setContentSize:NSMakeSize(622, 720)];
        FlushWindowLayout(controller.window);
        AssertTrue([[FindSidebarButton(rootView, @"一般") valueForKey:@"selectedItem"] boolValue], @"preferences opens on General");
        NSControl *generalModeControl = FindSegmentedControl(rootView, @[@"速成", @"新速成", @"倉頡", @"拼音"]);
        AssertTrue(generalModeControl != nil, @"General exposes the default mode control");
        SelectSegmentAndSend(generalModeControl, 1);
        AssertTrue([delegate.mode isEqualToString:MKInputModeSmartSucheng] && delegate.modeChangeCount == 1,
                   @"General default mode control updates delegate to New Sucheng");
        AssertTrue(FindButton(rootView, @"選擇輸入模式") == nil, @"General does not expose onboarding navigation");
        AssertTrue(FindButton(rootView, @"調整打字") == nil, @"General does not expose onboarding navigation");
        AssertTrue(FindButton(rootView, @"私隱與學習") == nil, @"General does not expose onboarding navigation");
        NSControl *languageControl = FindSegmentedControl(rootView, @[@"系統", @"English", @"繁體中文"]);
        AssertTrue(languageControl != nil, @"General exposes preferences language controls");
        AssertTrue([[languageControl valueForKey:@"selectedSegment"] integerValue] == 2,
                   @"Preferences language control reflects saved Traditional Chinese setting");
        AssertTrue(ViewLeadingMatchesContentLabel(rootView, languageControl, @"一般行為", 2.0),
                   @"General Behavior language control aligns with the card title");
        NSScrollView *generalOnlyScrollView = CurrentScrollView(rootView);
        NSView *generalDocumentView = generalOnlyScrollView.documentView;
        NSControl *orientationControl = FindSegmentedControl(rootView, @[@"直式", @"橫式"]);
        AssertTrue(orientationControl != nil, @"General exposes candidate window orientation control");
        SelectSegmentAndSend(orientationControl, 1);
        AssertTrue([delegate.candidatePanelOrientation isEqualToString:MKCandidatePanelOrientationHorizontal] &&
                   delegate.candidatePanelOrientationChangeCount == 1,
                   @"candidate orientation control updates delegate");
        NSControl *globalPageSizeControl = FindSegmentedControl(rootView, @[@"5", @"9"]);
        AssertTrue(globalPageSizeControl != nil, @"General exposes global candidate page-size control");
        SelectSegmentAndSend(globalPageSizeControl, 0);
        AssertTrue(delegate.candidatePageSize == 5 && delegate.candidatePageSizeChangeCount == 1,
                   @"global candidate page-size control updates delegate");
        NSControl *globalSpaceControl = FindSegmentedControl(rootView, @[@"提交", @"翻頁"]);
        AssertTrue(globalSpaceControl != nil, @"General exposes global Space key control");
        SelectSegmentAndSend(globalSpaceControl, 0);
        AssertTrue(!delegate.spacePagingEnabled && delegate.spacePagingChangeCount == 1,
                   @"global Space key control updates delegate");
        NSControl *fontSizeControl = FindSegmentedControl(rootView, @[@"細", @"中", @"大"]);
        AssertTrue(fontSizeControl != nil, @"General exposes candidate font-size control");
        SelectSegmentAndSend(fontSizeControl, 2);
        AssertTrue(fabs(delegate.candidatePanelFontSize - 19.0) < 0.1 &&
                   delegate.candidatePanelFontSizeChangeCount == 1,
                   @"candidate font-size control updates delegate");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"切換輸入模式"),
                   @"General shortcut labels are not compressed into ellipses");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"候選字體大小"),
                   @"Candidate window labels remain fully readable");
        NSArray<NSView *> *generalPopUps = ViewsOfClass(rootView, [NSPopUpButton class]);
        AssertTrue(generalPopUps.count == 1, @"General exposes one candidate highlight popup");
        NSPopUpButton *highlightPopup = (NSPopUpButton *)generalPopUps[0];
        [highlightPopup selectItemWithTitle:@"藍"];
        [highlightPopup sendAction:highlightPopup.action to:highlightPopup.target];
        AssertTrue([delegate.candidatePanelHighlightColor isEqualToString:MKCandidatePanelHighlightBlue] &&
                   delegate.candidatePanelHighlightChangeCount == 1,
                   @"candidate highlight popup updates delegate");
        NSControl *switchShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagSwitchInputMode);
        AssertTrue(switchShortcutRecorder != nil, @"General exposes editable Switch Input Mode shortcut recorder");
        NSRect switchShortcutFrame = FrameInView(switchShortcutRecorder, rootView);
        AssertTrue(NSWidth(switchShortcutFrame) >= 120.0 && NSHeight(switchShortcutFrame) >= 28.0,
                   @"General shortcut recorder keeps a visible framed control");
        RecordShortcutWithKey(switchShortcutRecorder, controller.window, NSEventModifierFlagControl, 0, @"a");
        AssertTrue([delegate.switchInputModeShortcut isEqualToString:@"keycode:1:0"] &&
                   delegate.switchInputModeShortcutChangeCount == 1,
                   @"Switch Input Mode shortcut recorder captures a real key event and updates delegate");
        AssertTrue(![[switchShortcutRecorder valueForKey:@"recording"] boolValue], @"shortcut recorder exits recording state after capture");
        AssertTrue(CurrentScrollView(rootView) == generalOnlyScrollView &&
                   generalOnlyScrollView.documentView == generalDocumentView,
                   @"General shortcut changes do not rebuild the scroll view");
        NSControl *privacyShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagPrivacyLock);
        AssertTrue(privacyShortcutRecorder != nil, @"General exposes editable Pause Learning shortcut recorder");
        SetShortcutAndSend(privacyShortcutRecorder, @"keycode:1:0");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"double_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 0,
                   @"duplicate shortcut conflicts are rejected without mutating delegate");
        SetShortcutAndSend(privacyShortcutRecorder, @"ctrl_shift_backtick");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"ctrl_shift_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 1,
                   @"Pause Learning shortcut recorder updates delegate");
        NSButton *resetShortcutButton = FindButton(rootView, @"重設");
        AssertTrue(resetShortcutButton != nil, @"General exposes shortcut reset controls");
        AssertTrue(CardsHaveUsableFrames(rootView), @"General tab has visible card frames by default");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"General tab does not overflow horizontally by default");

        SwitchToSidebarItem(rootView, @"輸入模式");
        FlushWindowLayout(controller.window);
        AssertTrue([ViewsOfClass(rootView, NSClassFromString(@"MKPreferencesCoverView")) count] == 1, @"Input Modes tab exposes one cover image view");
        NSControl *modeControl = FindSegmentedControl(rootView, @[@"速成", @"新速成", @"倉頡", @"拼音"]);
        AssertTrue(modeControl != nil, @"Input Modes tab exposes per-mode selector");
        SelectSegmentAndSend(modeControl, 3);
        NSArray<NSControl *> *inputModeSwitches = EnabledSwitches(rootView);
        AssertTrue(inputModeSwitches.count == 2, @"Input Modes tab exposes selected-mode enable and failed-reading switches");
        NSControl *selectedModeEnabledSwitch = inputModeSwitches[0];
        SetSwitchStateAndSend(selectedModeEnabledSwitch, NSControlStateValueOff);
        AssertTrue(![delegate.enabledInputModes containsObject:MKInputModePinyin] &&
                   delegate.enabledInputModesChangeCount == 1,
                   @"Input Modes can disable Pinyin input mode");
        SelectSegmentAndSend(modeControl, 1);
        AssertTrue([[modeControl valueForKey:@"selectedSegment"] integerValue] == 1, @"Input Modes selector switches to New Sucheng settings");
        SwitchToSidebarItem(rootView, @"輸入模式");
        FlushWindowLayout(controller.window);
        NSControl *candidatePageSizeControl = FindSegmentedControl(rootView, @[@"跟主要設定", @"5", @"9"]);
        AssertTrue(candidatePageSizeControl != nil, @"Input Modes tab exposes per-mode candidate page-size control");
        NSScrollView *inputModesScrollView = CurrentScrollView(rootView);
        NSView *inputModesDocumentView = inputModesScrollView.documentView;
        SelectSegmentAndSend(candidatePageSizeControl, 1);
        AssertTrue(delegate.modeCandidatePageSizeOverrides[MKInputModeSmartSucheng].unsignedIntegerValue == 5 &&
                   delegate.modeCandidatePageSizeOverrideChangeCount == 1,
                   @"per-mode candidate page-size control updates delegate");
        AssertTrue(CurrentScrollView(rootView) == inputModesScrollView &&
                   inputModesScrollView.documentView == inputModesDocumentView,
                   @"Input Modes setting changes do not rebuild the scroll view");
        NSControl *modeSpaceControl = FindSegmentedControl(rootView, @[@"跟主要設定", @"提交", @"翻頁"]);
        AssertTrue(modeSpaceControl != nil, @"Input Modes tab exposes per-mode Space key control");
        SelectSegmentAndSend(modeSpaceControl, 2);
        AssertTrue([delegate.modeSpaceKeyOverrides[MKInputModeSmartSucheng] isEqualToString:MKModeSpaceKeyPageCandidates] &&
                   delegate.modeSpaceKeyOverrideChangeCount == 1,
                   @"per-mode Space key control updates delegate");
        NSControl *smartSuchengShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagModeBase + 1);
        AssertTrue(smartSuchengShortcutRecorder != nil, @"Input Modes tab exposes editable selected-mode shortcut recorder");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"快捷鍵") &&
                   ContentLabelWithTextHasIntrinsicWidth(rootView, @"候選頁大小") &&
                   ContentLabelWithTextHasIntrinsicWidth(rootView, @"空白鍵"),
                   @"Input Modes setting labels remain fully readable");
        AssertTrue(!NSIntersectsRect(FrameInView(smartSuchengShortcutRecorder, rootView),
                                     FrameInView(candidatePageSizeControl, rootView)),
                   @"Input Modes shortcut and candidate page-size controls do not overlap");
        SetShortcutAndSend(smartSuchengShortcutRecorder, @"keycode:1:42");
        AssertTrue([delegate.modeShortcutsByMode[MKInputModeSmartSucheng] isEqualToString:@"keycode:1:42"] &&
                   delegate.modeShortcutChangeCount == 1,
                   @"mode shortcut recorder updates delegate");
        NSArray<NSControl *> *smartSuchengSwitches = EnabledSwitches(rootView);
        NSControl *clearReadingSwitch = smartSuchengSwitches[1];
        SetSwitchStateAndSend(clearReadingSwitch, NSControlStateValueOn);
        AssertTrue(delegate.modeClearReadingOverrides[MKInputModeSmartSucheng].boolValue &&
                   delegate.modeClearReadingChangeCount == 1,
                   @"clear-reading switch updates delegate for selected mode");
        NSButton *resetModeButton = FindButton(rootView, @"重設此輸入法");
        AssertTrue(resetModeButton != nil, @"Input Modes tab exposes reset selected mode button");
        [resetModeButton sendAction:resetModeButton.action to:resetModeButton.target];
        AssertTrue(delegate.modeResetCount == 1, @"reset selected mode button clears per-mode overrides");
        AssertTrue([ViewsOfClass(rootView, [NSPopUpButton class]) count] == 0, @"Input Modes tab does not use preset-only shortcut popups");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Input Modes tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Input Modes tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"打字");
        FlushWindowLayout(controller.window);
        NSScrollView *typingScrollView = CurrentScrollView(rootView);
        NSView *typingDocumentView = typingScrollView.documentView;
        NSArray<NSControl *> *typingEnabledSwitches = EnabledSwitches(rootView);
        AssertTrue(typingEnabledSwitches.count == 4, @"Typing tab exposes raw-English, spelling, and related-word switches");
        NSControl *rawSwitch = typingEnabledSwitches[0];
        SetSwitchStateAndSend(rawSwitch, NSControlStateValueOff);
        AssertTrue(!delegate.rawEnglishCandidateEnabled && delegate.rawEnglishChangeCount == 1, @"raw-English candidate switch updates delegate");
        NSControl *spellingSwitch = typingEnabledSwitches[1];
        SetSwitchStateAndSend(spellingSwitch, NSControlStateValueOff);
        AssertTrue(!delegate.spellingSuggestionsEnabled && delegate.spellingSuggestionsChangeCount == 1, @"spelling suggestion switch updates delegate");
        NSControl *associationSwitch = typingEnabledSwitches[2];
        SetSwitchStateAndSend(associationSwitch, NSControlStateValueOff);
        AssertTrue(!delegate.associationCandidatesEnabled && delegate.associationCandidatesChangeCount == 1,
                   @"related-word switch updates delegate");
        NSControl *associationContinuationSwitch = typingEnabledSwitches[3];
        SetSwitchStateAndSend(associationContinuationSwitch, NSControlStateValueOff);
        AssertTrue(!delegate.associationContinuationEnabled && delegate.associationContinuationChangeCount == 1,
                   @"related-word continuation switch updates delegate");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"選完聯想詞後繼續提示"),
                   @"Related Words rows remain fully readable");
        AssertTrue(CurrentScrollView(rootView) == typingScrollView &&
                   typingScrollView.documentView == typingDocumentView,
                   @"Typing setting changes do not rebuild the scroll view");
        NSTextField *quickPhraseTriggerField = FindTextFieldWithPlaceholder(rootView, @"以 ; 開頭，例如 ;email");
        NSTextField *quickPhraseReplacementField = FindTextFieldWithPlaceholder(rootView, @"替換文字");
        AssertTrue(quickPhraseTriggerField != nil,
                   @"Typing tab exposes a semicolon Quick Phrases trigger field");
        AssertTrue(quickPhraseReplacementField != nil,
                   @"Typing tab exposes a Quick Phrases replacement field");
        AssertTrue(!LabelWithTextExists(rootView, @"短碼必須以 ; 開頭，例如 ;email。"),
                   @"Typing tab avoids duplicating Quick Phrases placeholder copy");
        NSButton *saveQuickPhraseButton = FindButton(rootView, @"儲存短語");
        AssertTrue(saveQuickPhraseButton != nil &&
                   FindButton(rootView, @"移除短語") != nil &&
                   FindButton(rootView, @"匯入 TXT") != nil &&
                   FindButton(rootView, @"匯出 TXT") != nil,
                   @"Typing tab exposes Quick Phrases save/remove/import/export controls");
        quickPhraseTriggerField.stringValue = @";email";
        quickPhraseReplacementField.stringValue = @"founder@example.com";
        [saveQuickPhraseButton sendAction:saveQuickPhraseButton.action to:saveQuickPhraseButton.target];
        FlushWindowLayout(controller.window);
        AssertTrue(LabelWithTextExists(rootView, @"已儲存 ;email，呢個短碼而家有 1 個內容。"),
                   @"Quick Phrases save shows a visible success message");
        quickPhraseReplacementField.stringValue = @"support@example.com";
        [saveQuickPhraseButton sendAction:saveQuickPhraseButton.action to:saveQuickPhraseButton.target];
        FlushWindowLayout(controller.window);
        AssertTrue([preferencesQuickPhraseStore entriesForTrigger:@";email"].count == 2 &&
                   LabelWithTextExists(rootView, @"已儲存 ;email，呢個短碼而家有 2 個內容。"),
                   @"Quick Phrases allows repeated trigger entries and reports the new count");
        NSTextField *quickPhraseSummaryLabel = FindContentLabel(rootView, @"已儲存 2 個快速短語。");
        AssertTrue(quickPhraseSummaryLabel != nil &&
                   ViewLeadingMatchesContentLabel(rootView, quickPhraseSummaryLabel, @"快速短語", 2.0) &&
                   ContentLabelWithTextHasIntrinsicWidth(rootView, @"已儲存 2 個快速短語。") &&
                   LabelWithTextHasMinimumHeight(rootView, @"已儲存 2 個快速短語。", 16.0),
                   @"Quick Phrases summary stays readable and aligned with the card title");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"已儲存 ;email，呢個短碼而家有 2 個內容。") &&
                   LabelWithTextHasMinimumHeight(rootView, @"已儲存 ;email，呢個短碼而家有 2 個內容。", 16.0),
                   @"Quick Phrases action status stays readable");
        AssertTrue(ViewLeadingMatchesContentLabel(rootView, FindButton(rootView, @"儲存短語"), @"快速短語", 2.0) &&
                   ViewLeadingMatchesContentLabel(rootView, FindButton(rootView, @"匯入 TXT"), @"快速短語", 2.0),
                   @"Quick Phrases buttons align with the card title");
        AssertTrue(LabelWithTextHasMinimumHeight(rootView, @"組字", 24.0), @"Typing tab keeps Composition title fully visible");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Typing tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Typing tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"私隱與學習");
        FlushWindowLayout(controller.window);
        NSScrollView *privacyScrollView = CurrentScrollView(rootView);
        NSView *privacyDocumentView = privacyScrollView.documentView;
        NSArray<NSControl *> *privacyEnabledSwitches = EnabledSwitches(rootView);
        AssertTrue(privacyEnabledSwitches.count == 2, @"Privacy & Learning tab exposes learning and Privacy Lock switches");
        AssertTrue([ViewsOfClass(rootView, [NSPopUpButton class]) count] == 0, @"Privacy & Learning tab does not duplicate shortcut configuration");
        AssertTrue(FindButton(rootView, @"編輯") != nil, @"Privacy & Learning links shortcut editing back to General");
        AssertTrue(ContentLabelWithTextHasIntrinsicWidth(rootView, @"目前快捷鍵"),
                   @"Privacy shortcut reference label remains fully readable");
        NSControl *learningSwitch = privacyEnabledSwitches[0];
        SetSwitchStateAndSend(learningSwitch, NSControlStateValueOn);
        AssertTrue(delegate.learningEnabled, @"learning switch updates delegate");
        NSControl *privacyLockSwitch = privacyEnabledSwitches[1];
        SetSwitchStateAndSend(privacyLockSwitch, NSControlStateValueOn);
        AssertTrue(delegate.privacyLockEnabled && delegate.privacyLockChangeCount == 1, @"Privacy Lock switch updates delegate");
        AssertTrue(CurrentScrollView(rootView) == privacyScrollView &&
                   privacyScrollView.documentView == privacyDocumentView,
                   @"Privacy & Learning setting changes do not rebuild the scroll view");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"ctrl_shift_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 1,
                   @"Privacy tab shortcut reference does not mutate shortcut preferences");
        AssertTrue(LabelWithTextHasMinimumHeight(rootView, @"學習", 24.0), @"Privacy & Learning tab keeps Learning title fully visible");
        AssertTrue(FindButton(rootView, @"匯出備份") != nil &&
                   FindButton(rootView, @"還原備份") != nil,
                   @"Privacy & Learning exposes basic backup and restore controls");
        NSButton *resetLearningDataButton = FindButton(rootView, @"重設學習資料");
        AssertTrue(resetLearningDataButton != nil, @"Privacy & Learning exposes reset learning data button");
        [resetLearningDataButton sendAction:resetLearningDataButton.action to:resetLearningDataButton.target];
        FlushWindowLayout(controller.window);
        AssertTrue(LabelWithTextExists(rootView, @"學習資料已重設。"),
                   @"Reset Learning Data shows visible completion feedback");
        NSButton *privacyPolicyButton = FindButton(rootView, @"開啟私隱政策");
        AssertTrue(privacyPolicyButton != nil, @"Privacy & Learning exposes an in-app privacy policy button");
        AssertTrue(ViewLeadingMatchesContentLabel(rootView, FindButton(rootView, @"重設學習資料"), @"資料", 2.0) &&
                   ViewLeadingMatchesContentLabel(rootView, FindButton(rootView, @"匯出備份"), @"備份 / 還原", 2.0),
                   @"Privacy data and backup buttons align with the card titles");
        [privacyPolicyButton sendAction:privacyPolicyButton.action to:privacyPolicyButton.target];
        FlushWindowLayout(controller.window.attachedSheet ?: controller.window);
        NSWindow *privacyPolicySheet = controller.window.attachedSheet;
        AssertTrue(privacyPolicySheet != nil, @"Privacy policy opens as an attached preferences sheet");
        NSArray<NSView *> *privacyPolicyTextViews = ViewsOfClass(privacyPolicySheet.contentView, [NSTextView class]);
        AssertTrue(privacyPolicyTextViews.count == 1, @"Privacy policy sheet contains one text view");
        NSTextView *privacyPolicyTextView = (NSTextView *)privacyPolicyTextViews[0];
        AssertTrue(!privacyPolicyTextView.editable && privacyPolicyTextView.selectable,
                   @"Privacy policy text is read-only and selectable");
        AssertTrue([privacyPolicyTextView.string containsString:@"PurrType Privacy Policy"],
                   @"Privacy policy sheet displays the bundled policy text");
        NSButton *closePrivacyPolicyButton = FindButton(privacyPolicySheet.contentView, @"關閉");
        AssertTrue(closePrivacyPolicyButton != nil, @"Privacy policy sheet exposes a close button");
        [closePrivacyPolicyButton sendAction:closePrivacyPolicyButton.action to:closePrivacyPolicyButton.target];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        AssertTrue(controller.window.attachedSheet == nil, @"Privacy policy sheet closes without leaving an attached modal");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Privacy & Learning tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Privacy & Learning tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"關於");
        FlushWindowLayout(controller.window);
        NSButton *githubButton = FindButton(rootView, @"GitHub");
        NSButton *coffeeButton = FindButton(rootView, @"Buy Me a Coffee");
        NSButton *bugButton = FindButton(rootView, @"回報問題");
        AssertTrue(githubButton != nil && coffeeButton != nil && bugButton != nil, @"About links expose GitHub, Buy Me a Coffee, and Report a Bug buttons");
        NSRect githubFrame = FrameInView(githubButton, rootView);
        NSRect coffeeFrame = FrameInView(coffeeButton, rootView);
        NSRect bugFrame = FrameInView(bugButton, rootView);
        AssertTrue(ButtonHasReadableWidth(githubButton) &&
                   ButtonHasReadableWidth(coffeeButton) &&
                   ButtonHasReadableWidth(bugButton),
                   @"About link buttons keep enough width for their titles");
        AssertTrue(ViewLeadingMatchesContentLabel(rootView, githubButton, @"連結", 2.0),
                   @"About link buttons align with the Links title");
        AssertTrue(fabs(NSMinY(githubFrame) - NSMinY(coffeeFrame)) < 2.0 &&
                   fabs(NSMinY(coffeeFrame) - NSMinY(bugFrame)) < 2.0,
                   @"About link buttons are arranged horizontally");
        NSImageView *coffeeQRCode = FindImageViewWithAccessibilityLabel(rootView, @"Buy Me a Coffee QR Code");
        AssertTrue(coffeeQRCode != nil && coffeeQRCode.image != nil, @"About links expose a Buy Me a Coffee QR code");
        NSRect qrFrame = FrameInView(coffeeQRCode, rootView);
        AssertTrue(!NSIntersectsRect(qrFrame, coffeeFrame),
                   @"Buy Me a Coffee QR code is separated from the horizontal button row");
        NSRect linksCardFrame = FrameInView(coffeeQRCode.superview, rootView);
        AssertTrue(fabs(NSMidX(qrFrame) - NSMidX(linksCardFrame)) < 2.0,
                   @"Buy Me a Coffee QR code is centered in the Links card");
        AssertTrue([ViewsOfClass(rootView, [NSButton class]) count] >= 3, @"About tab exposes link buttons");
        AssertTrue(CardsHaveUsableFrames(rootView), @"About tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"About tab does not overflow horizontally");

        [controller.window setContentSize:NSMakeSize(622, 620)];
        for (NSString *tabTitle in @[@"一般", @"輸入模式", @"打字", @"私隱與學習", @"關於"]) {
            SwitchToSidebarItem(rootView, tabTitle);
            FlushWindowLayout(controller.window);
            AssertTrue(CardsHaveUsableFrames(rootView), [NSString stringWithFormat:@"%@ tab has usable card frames at minimum size", tabTitle]);
            AssertTrue(CoverUsesArtworkAspectRatio(rootView), [NSString stringWithFormat:@"%@ tab cover keeps full artwork aspect ratio at minimum size", tabTitle]);
            AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), [NSString stringWithFormat:@"%@ tab does not overflow horizontally at minimum size", tabTitle]);
        }

        [controller.window setContentSize:NSMakeSize(760, 650)];
        FlushWindowLayout(controller.window);
        [defaults setObject:@"en" forKey:MKUserDefaultPreferencesLanguageKey];
        [defaults synchronize];
        [controller reloadState];
        FlushWindowLayout(controller.window);
        NSRect englishContentRect = [controller.window contentRectForFrameRect:controller.window.frame];
        AssertTrue(WindowContentSizeMatches(controller.window, standardPreferencesContentSize),
                   [NSString stringWithFormat:@"English Preferences normalizes to the same fixed size as Traditional Chinese, actual=%@",
                                              NSStringFromSize(englishContentRect.size)]);
        AssertTrue(FindSidebarButton(rootView, @"General") != nil, @"English Preferences keeps localized sidebar usable");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"English Preferences does not overflow horizontally");
        for (NSString *tabTitle in @[@"General", @"Input Modes", @"Typing", @"Privacy & Learning", @"About"]) {
            [controller.window setContentSize:NSMakeSize(760, 650)];
            SwitchToSidebarItem(rootView, tabTitle);
            FlushWindowLayout(controller.window);
            AssertTrue(WindowContentSizeMatches(controller.window, standardPreferencesContentSize),
                       [NSString stringWithFormat:@"English %@ tab keeps the standard Preferences size", tabTitle]);
            AssertTrue(RightPaneHasNoHorizontalOverflow(rootView),
                       [NSString stringWithFormat:@"English %@ tab does not overflow horizontally", tabTitle]);
        }

        [controller close];
        [defaults removeObjectForKey:MKUserDefaultPreferencesLanguageKey];
        [defaults synchronize];
        [[NSFileManager defaultManager] removeItemAtPath:learningPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:quickPhraseDirectory error:nil];
        NSLog(@"PASS: PurrTypePreferencesTests");
    }

    return 0;
}
