#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeCandidatePanel.h"
#include <math.h>

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface CandidatePanelTestDelegate : NSObject <PurrTypeCandidatePanelDelegate>
@property(nonatomic, copy) NSString *selectedText;
@end

@implementation CandidatePanelTestDelegate
- (void)candidatePanel:(PurrTypeCandidatePanel *)panel didSelectCandidateText:(NSString *)candidateText {
    (void)panel;
    self.selectedText = candidateText;
}
@end

@interface CandidatePanelTestClient : NSObject <NSTextInputClient>
@property(nonatomic, assign) NSRect firstRect;
@property(nonatomic, assign) NSRect selectedRect;
@property(nonatomic, assign) NSRect markedEndRect;
@property(nonatomic, assign) NSRect markedRangeRect;
@property(nonatomic, assign) NSRect lineHeightRect;
@property(nonatomic, assign) NSRange selectedRangeValue;
@property(nonatomic, assign) NSRange markedRangeValue;
@property(nonatomic, assign) NSRange lastRequestedRange;
@property(nonatomic, assign) NSUInteger lastRequestedAttributeIndex;
@property(nonatomic, assign) BOOL lineHeightAnchorEnabled;
@end

@implementation CandidatePanelTestClient

- (instancetype)init {
    self = [super init];
    if (self) {
        _firstRect = NSMakeRect(240, 520, 0, 22);
        _selectedRect = _firstRect;
        _markedEndRect = _firstRect;
        _markedRangeRect = _firstRect;
        _lineHeightRect = _firstRect;
        _selectedRangeValue = NSMakeRange(NSNotFound, 0);
        _markedRangeValue = NSMakeRange(0, 0);
        _lastRequestedRange = NSMakeRange(NSNotFound, 0);
        _lastRequestedAttributeIndex = NSNotFound;
        _lineHeightAnchorEnabled = NO;
    }
    return self;
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
    (void)string;
    (void)replacementRange;
}

- (void)doCommandBySelector:(SEL)selector {
    (void)selector;
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {
    (void)string;
    (void)selectedRange;
    (void)replacementRange;
}

- (void)unmarkText {
}

- (NSRange)selectedRange {
    return self.selectedRangeValue;
}

- (NSRange)markedRange {
    return self.markedRangeValue;
}

- (BOOL)hasMarkedText {
    return YES;
}

- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
    (void)range;
    if (actualRange) {
        *actualRange = NSMakeRange(NSNotFound, 0);
    }
    return nil;
}

- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText {
    return @[];
}

- (NSDictionary *)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRectPointer)lineHeightRect {
    self.lastRequestedAttributeIndex = index;
    if (lineHeightRect) {
        *lineHeightRect = self.lineHeightAnchorEnabled ? self.lineHeightRect : NSZeroRect;
    }
    return @{};
}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(NSRangePointer)actualRange {
    self.lastRequestedRange = range;
    if (actualRange) {
        *actualRange = range;
    }
    if (self.markedRangeValue.location != NSNotFound &&
        NSEqualRanges(range, NSMakeRange(NSMaxRange(self.markedRangeValue), 0))) {
        return self.markedEndRect;
    }
    if (self.markedRangeValue.location != NSNotFound && NSEqualRanges(range, self.markedRangeValue)) {
        return self.markedRangeRect;
    }
    if (self.selectedRangeValue.location != NSNotFound && NSEqualRanges(range, self.selectedRangeValue)) {
        return self.selectedRect;
    }
    return self.firstRect;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {
    (void)point;
    return 0;
}

@end

static NSArray<NSString *> *TenCandidateRows(void) {
    return @[
        @"0 of",
        @"1 伙",
        @"2 你",
        @"3 係",
        @"4 為",
        @"5 氣",
        @"6 焦",
        @"7 無",
        @"8 條",
        @"9 儀"
    ];
}

static NSRect CandidatePanelFrame(PurrTypeCandidatePanel *panel) {
    NSWindow *window = [panel valueForKey:@"panel"];
    return window.frame;
}

static NSUInteger CandidatePanelSelectedIndex(PurrTypeCandidatePanel *panel) {
    NSView *panelView = [panel valueForKey:@"panelView"];
    return [[panelView valueForKey:@"selectedIndex"] unsignedIntegerValue];
}

static NSScreen *TestScreenForRect(NSRect rect) {
    NSPoint point = NSMakePoint(NSMidX(rect), NSMidY(rect));
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(point, screen.frame)) {
            return screen;
        }
    }
    return [NSScreen mainScreen];
}

static CGFloat ExpectedPanelXForAnchorRect(NSRect anchorRect, NSSize panelSize) {
    NSScreen *screen = TestScreenForRect(anchorRect);
    NSRect visibleFrame = screen.visibleFrame;
    CGFloat normalizedWidth = NSWidth(anchorRect) <= 0.0 ? 1.0 : NSWidth(anchorRect);
    CGFloat preferredX = NSMinX(anchorRect) + normalizedWidth + 4.0;
    CGFloat alignedX = NSMinX(anchorRect);
    CGFloat leftX = NSMinX(anchorRect) - panelSize.width - 4.0;
    CGFloat maxX = NSMaxX(visibleFrame) - panelSize.width - 8.0;
    CGFloat minX = NSMinX(visibleFrame) + 8.0;
    CGFloat x = preferredX;
    if (x > maxX && alignedX <= maxX) {
        x = alignedX;
    }
    if (x > maxX && leftX >= minX) {
        x = leftX;
    }
    return MIN(MAX(x, minX), maxX);
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];

        PurrTypeCandidatePanel *panel = [[PurrTypeCandidatePanel alloc] init];
        NSArray<NSString *> *rows = TenCandidateRows();
        NSSize preferredSize = [panel preferredSizeForCandidates:rows];
        AssertTrue((NSInteger)preferredSize.height == 218, @"custom panel is readable and still shows 0-9 without scrolling");
        AssertTrue(preferredSize.width >= 86 && preferredSize.width <= 154, @"custom panel keeps compact bounded width");
        NSSize preferredSizeWithPage = [panel preferredSizeForCandidates:rows pageIndicatorText:@"2/5"];
        AssertTrue((NSInteger)preferredSizeWithPage.height == 236, @"custom panel reserves a compact page-count header");

        CandidatePanelTestClient *client = [[CandidatePanelTestClient alloc] init];
        client.selectedRangeValue = NSMakeRange(100, 0);
        client.selectedRect = NSMakeRect(900, 200, 0, 22);
        client.lineHeightAnchorEnabled = YES;
        client.lineHeightRect = NSMakeRect(320, 520, 12, 22);
        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@1];
        NSRect lineHeightFrame = CandidatePanelFrame(panel);
        AssertTrue(client.lastRequestedAttributeIndex == 1, @"custom panel asks the IMK line-height anchor for the active composing character");
        AssertTrue(fabs(NSMinX(lineHeightFrame) - ExpectedPanelXForAnchorRect(client.lineHeightRect, preferredSize)) < 0.5, @"custom panel prefers the IMK line-height anchor when provided");

        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@1 pageIndex:1 pageCount:5];
        AssertTrue([panel candidateTextAtPanelPoint:NSMakePoint(20, 14)] == nil, @"hit testing ignores the page-count header");
        AssertTrue([[panel candidateTextAtPanelPoint:NSMakePoint(20, 18 + 14)] isEqualToString:@"0 of"], @"hit testing selects row 0 below the page-count header");
        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@1 pageIndex:1 pageCount:5 usePreservedAnchor:NO selectedIndex:3];
        AssertTrue(CandidatePanelSelectedIndex(panel) == 3, @"custom panel exposes the selected candidate row to drawing");
        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@1 pageIndex:1 pageCount:5 usePreservedAnchor:NO selectedIndex:99];
        AssertTrue(CandidatePanelSelectedIndex(panel) == 0, @"custom panel falls back to the first row for invalid selected indexes");

        client.lineHeightAnchorEnabled = NO;
        [panel beginAnchorSessionForClient:client];
        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@1];
        AssertTrue(panel.isVisible, @"custom candidate panel becomes visible");
        NSRect firstFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(firstFrame) - ExpectedPanelXForAnchorRect(client.markedEndRect, preferredSize)) < 0.5,
                   [NSString stringWithFormat:@"custom panel x appears beside the client caret, actual %.1f expected %.1f range %@ marked %@",
                    NSMinX(firstFrame),
                    ExpectedPanelXForAnchorRect(client.markedEndRect, preferredSize),
                    NSStringFromRange(client.lastRequestedRange),
                    NSStringFromRect(client.markedEndRect)]);
        AssertTrue(NSEqualRanges(client.lastRequestedRange, NSMakeRange(NSMaxRange(client.markedRangeValue), 0)), @"custom panel asks for the marked-text endpoint instead of a stale selectedRange");

        AssertTrue([[panel candidateTextAtPanelPoint:NSMakePoint(20, 14)] isEqualToString:@"0 of"], @"hit testing selects row 0");
        AssertTrue([[panel candidateTextAtPanelPoint:NSMakePoint(20, 14 + 21 * 9)] isEqualToString:@"9 儀"], @"hit testing selects row 9");
        AssertTrue([panel candidateTextAtPanelPoint:NSMakePoint(20, 2)] == nil, @"hit testing ignores top padding");
        AssertTrue([panel candidateTextAtPanelPoint:NSMakePoint(20, preferredSize.height + 1)] == nil, @"hit testing ignores outside bottom");

        CandidatePanelTestDelegate *delegate = [[CandidatePanelTestDelegate alloc] init];
        panel.delegate = delegate;
        [panel selectCandidateAtPanelPoint:NSMakePoint(20, 14 + 21 * 3)];
        AssertTrue([delegate.selectedText isEqualToString:@"3 係"], @"mouse selection delegates selected candidate text");

        client.lastRequestedAttributeIndex = NSNotFound;
        client.lineHeightAnchorEnabled = YES;
        client.lineHeightRect = NSMakeRect(780, 520, 12, 22);
        client.markedEndRect = NSMakeRect(40, 520, 0, 22);
        [panel beginAnchorSessionForClient:client];
        [panel showCandidates:rows nearClient:client anchorCharacterIndex:@0];
        NSRect punctuationFrame = CandidatePanelFrame(panel);
        AssertTrue(client.lastRequestedAttributeIndex == 0, @"punctuation panel asks the same line-height anchor used by text candidates");
        AssertTrue(fabs(NSMinX(punctuationFrame) - ExpectedPanelXForAnchorRect(client.lineHeightRect, preferredSize)) < 0.5,
                   @"punctuation panel uses the active marked character anchor instead of falling back to the line start");

        client.lineHeightAnchorEnabled = NO;
        client.markedEndRect = NSMakeRect(NSMinX(client.markedEndRect) + 80.0, NSMinY(client.markedEndRect), NSWidth(client.markedEndRect), NSHeight(client.markedEndRect));
        [panel showCandidates:rows nearClient:client];
        NSRect movedFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(movedFrame) - ExpectedPanelXForAnchorRect(client.markedEndRect, preferredSize)) < 0.5, @"custom panel follows caret movement during one composition");

        NSRect preservedAssociationAnchor = client.markedEndRect;
        client.markedRangeValue = NSMakeRange(NSNotFound, 0);
        client.selectedRangeValue = NSMakeRange(0, 0);
        client.selectedRect = NSMakeRect(0, NSMinY(preservedAssociationAnchor), 0, NSHeight(preservedAssociationAnchor));
        [panel showCandidates:rows nearClient:nil anchorCharacterIndex:nil pageIndex:0 pageCount:14 usePreservedAnchor:YES];
        AssertTrue(panel.isVisible, @"post-commit association panel remains visible when reusing the preserved caret anchor");
        NSRect preservedAssociationFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(preservedAssociationFrame) - ExpectedPanelXForAnchorRect(preservedAssociationAnchor, preferredSizeWithPage)) < 0.5,
                   @"post-commit association panel reuses the preserved caret anchor instead of accepting a transient screen-left selectedRange");

        [panel showCandidates:rows nearClient:nil anchorCharacterIndex:nil pageIndex:0 pageCount:14];
        AssertTrue(!panel.isVisible, @"ordinary nil-client candidate panels hide instead of implicitly reusing a stale anchor");

        CandidatePanelTestClient *screenLeftSelectedRangeClient = [[CandidatePanelTestClient alloc] init];
        screenLeftSelectedRangeClient.markedRangeValue = NSMakeRange(NSNotFound, 0);
        screenLeftSelectedRangeClient.selectedRangeValue = NSMakeRange(0, 0);
        screenLeftSelectedRangeClient.selectedRect = NSMakeRect(0, NSMinY(preservedAssociationAnchor), 0, NSHeight(preservedAssociationAnchor));
        [panel clearAnchorSession];
        [panel showCandidates:rows nearClient:screenLeftSelectedRangeClient anchorCharacterIndex:@0];
        AssertTrue(!panel.isVisible, @"composition panels wait for a marked-text anchor instead of jumping to a screen-left selectedRange after app switch");

        [panel clearAnchorSession];
        NSRect fallbackScreenRect = NSMakeRect(420, 360, 52, 52);
        [panel showCandidates:rows nearScreenRect:fallbackScreenRect];
        AssertTrue(panel.isVisible, @"custom candidate panel can use an explicit screen rect fallback anchor");
        NSRect fallbackFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(fallbackFrame) - ExpectedPanelXForAnchorRect(fallbackScreenRect, preferredSize)) < 0.5,
                   @"screen-rect fallback anchor positions the custom panel beside the fallback rect");
        [panel showCandidates:rows nearClient:nil anchorCharacterIndex:nil pageIndex:0 pageCount:14 usePreservedAnchor:YES];
        AssertTrue(!panel.isVisible, @"screen-rect fallback does not seed a preserved text caret anchor");

        client.markedRangeValue = NSMakeRange(0, 0);
        client.selectedRangeValue = NSMakeRange(100, 0);

        [panel beginAnchorSessionForClient:client];
        [panel showCandidates:rows nearClient:client];
        NSRect nextCompositionFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(nextCompositionFrame) - ExpectedPanelXForAnchorRect(client.markedEndRect, preferredSize)) < 0.5, @"custom panel repositions after starting a new composition anchor session");

        client.markedEndRect = NSMakeRect(NSMinX(client.markedEndRect) + 500.0, NSMinY(client.markedEndRect), NSWidth(client.markedEndRect), NSHeight(client.markedEndRect));
        [panel showCandidates:rows nearClient:client];
        NSRect jumpFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(jumpFrame) - ExpectedPanelXForAnchorRect(client.markedEndRect, preferredSize)) < 0.5, @"custom panel follows the current caret instead of reusing an old app position");

        CandidatePanelTestClient *secondClient = [[CandidatePanelTestClient alloc] init];
        secondClient.markedEndRect = NSMakeRect(40, 520, 0, 22);
        [panel showCandidates:rows nearClient:secondClient];
        NSRect secondClientFrame = CandidatePanelFrame(panel);
        AssertTrue(fabs(NSMinX(secondClientFrame) - ExpectedPanelXForAnchorRect(secondClient.markedEndRect, preferredSize)) < 0.5, @"custom panel accepts a new client anchor instead of reusing the old app position");

        CandidatePanelTestClient *noAnchorClient = [[CandidatePanelTestClient alloc] init];
        noAnchorClient.markedRangeValue = NSMakeRange(NSNotFound, 0);
        noAnchorClient.selectedRangeValue = NSMakeRange(NSNotFound, 0);
        [panel clearAnchorSession];
        [panel showCandidates:rows nearClient:noAnchorClient anchorCharacterIndex:@1];
        AssertTrue(!panel.isVisible, @"custom panel hides instead of falling back to mouse location when no usable anchor exists");

        [panel hide];
        AssertTrue(!panel.isVisible, @"custom candidate panel hides");
        NSLog(@"PASS: PurrTypeCandidatePanelTests");
    }
    return 0;
}
