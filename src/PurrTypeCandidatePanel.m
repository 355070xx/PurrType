#import "PurrTypeCandidatePanel.h"
#import "PurrTypePreferencesConstants.h"
#include <math.h>

static const CGFloat MKCandidatePanelRowHeight = 21.0;
static const CGFloat MKCandidatePanelVerticalInset = 4.0;
static const CGFloat MKCandidatePanelHorizontalInset = 4.0;
static const CGFloat MKCandidatePanelHeaderHeight = 18.0;
static const CGFloat MKCandidatePanelMinWidth = 86.0;
static const CGFloat MKCandidatePanelMaxWidth = 154.0;
static const CGFloat MKCandidatePanelLongTextMaxWidth = 360.0;
static const CGFloat MKCandidatePanelScreenMargin = 8.0;
static const CGFloat MKCandidatePanelDefaultAnchorHeight = 22.0;
static const CGFloat MKCandidatePanelCaretHorizontalGap = 4.0;
static const CGFloat MKCandidatePanelCaretVerticalGap = 4.0;

static NSString *MKCandidatePanelCustomHighlightHex(NSString *highlightColor) {
    if (![highlightColor hasPrefix:MKCandidatePanelHighlightCustomPrefix]) {
        return nil;
    }
    NSString *hex = [highlightColor substringFromIndex:MKCandidatePanelHighlightCustomPrefix.length];
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    }
    if (hex.length != 6) {
        return nil;
    }
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    if (![scanner scanHexInt:&rgb] || !scanner.isAtEnd) {
        return nil;
    }
    return [NSString stringWithFormat:@"#%06X", rgb & 0xFFFFFF];
}

static BOOL MKCandidatePanelHighlightColorIsPreset(NSString *highlightColor) {
    return [highlightColor isEqualToString:MKCandidatePanelHighlightRed] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightOrange] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightYellow] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightGreen] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightBlue] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightPurple] ||
           [highlightColor isEqualToString:MKCandidatePanelHighlightPink];
}

static NSString *MKCandidatePanelNormalizedHighlightColor(NSString *highlightColor) {
    if (MKCandidatePanelHighlightColorIsPreset(highlightColor)) {
        return highlightColor;
    }
    NSString *customHex = MKCandidatePanelCustomHighlightHex(highlightColor);
    if (customHex.length > 0) {
        return [MKCandidatePanelHighlightCustomPrefix stringByAppendingString:customHex];
    }
    return MKCandidatePanelHighlightRed;
}

static NSColor *MKCandidatePanelColorFromCustomHighlight(NSString *highlightColor) {
    NSString *customHex = MKCandidatePanelCustomHighlightHex(highlightColor);
    if (customHex.length == 0) {
        return nil;
    }
    unsigned int rgb = 0;
    [[NSScanner scannerWithString:[customHex substringFromIndex:1]] scanHexInt:&rgb];
    return [NSColor colorWithCalibratedRed:((rgb >> 16) & 0xFF) / 255.0
                                     green:((rgb >> 8) & 0xFF) / 255.0
                                      blue:(rgb & 0xFF) / 255.0
                                     alpha:1.0];
}

@protocol PurrTypeLineHeightAnchorClient <NSObject>
- (NSDictionary *)attributesForCharacterIndex:(NSUInteger)index lineHeightRectangle:(NSRectPointer)lineHeightRect;
@end

@interface MKCandidatePanelView : NSView
@property(nonatomic, copy) NSArray<NSString *> *candidateTexts;
@property(nonatomic, copy) NSString *pageIndicatorText;
@property(nonatomic, assign) NSUInteger selectedIndex;
@property(nonatomic, copy) NSString *orientation;
@property(nonatomic, assign) CGFloat candidateFontSize;
@property(nonatomic, copy) NSString *highlightColor;
@property(nonatomic, copy) void (^selectionHandler)(NSPoint point);
@end

@implementation MKCandidatePanelView

- (BOOL)isFlipped {
    return YES;
}

- (CGFloat)effectiveFontSize {
    if (self.candidateFontSize <= 0.0) {
        return 17.0;
    }
    return self.candidateFontSize;
}

- (BOOL)usesHorizontalLayout {
    return [self.orientation isEqualToString:MKCandidatePanelOrientationHorizontal];
}

- (NSColor *)effectiveHighlightColor {
    NSColor *customColor = MKCandidatePanelColorFromCustomHighlight(self.highlightColor);
    if (customColor) {
        return customColor;
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightOrange]) {
        return [NSColor colorWithCalibratedRed:0.91 green:0.42 blue:0.18 alpha:1.0];
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightYellow]) {
        return [NSColor colorWithCalibratedRed:0.78 green:0.52 blue:0.08 alpha:1.0];
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightGreen]) {
        return [NSColor colorWithCalibratedRed:0.20 green:0.55 blue:0.28 alpha:1.0];
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightBlue]) {
        return [NSColor colorWithCalibratedRed:0.16 green:0.44 blue:0.91 alpha:1.0];
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightPurple]) {
        return [NSColor colorWithCalibratedRed:0.52 green:0.32 blue:0.86 alpha:1.0];
    }
    if ([self.highlightColor isEqualToString:MKCandidatePanelHighlightPink]) {
        return [NSColor colorWithCalibratedRed:0.84 green:0.24 blue:0.52 alpha:1.0];
    }
    return [NSColor colorWithCalibratedRed:1.0 green:0.31 blue:0.34 alpha:1.0];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = self.bounds;
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5)
                                                               xRadius:12.0
                                                               yRadius:12.0];
    [[NSColor colorWithCalibratedWhite:0.04 alpha:0.88] setFill];
    [background fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.22] setStroke];
    [background setLineWidth:1.0];
    [background stroke];

    NSDictionary<NSAttributedStringKey, id> *normalAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[self effectiveFontSize] weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.92 alpha:1.0]
    };
    NSDictionary<NSAttributedStringKey, id> *selectedAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:[self effectiveFontSize] weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    NSDictionary<NSAttributedStringKey, id> *pageAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.82 alpha:1.0]
    };

    CGFloat contentTop = 0.0;
    if (self.pageIndicatorText.length > 0) {
        NSString *pageText = self.pageIndicatorText ?: @"";
        NSSize pageTextSize = [pageText sizeWithAttributes:pageAttributes];
        NSRect pageTextRect = NSMakeRect(NSWidth(bounds) - pageTextSize.width - 10.0,
                                         floor((MKCandidatePanelHeaderHeight - pageTextSize.height) / 2.0),
                                         pageTextSize.width,
                                         pageTextSize.height + 1.0);
        [pageText drawInRect:pageTextRect withAttributes:pageAttributes];

        NSBezierPath *headerLine = [NSBezierPath bezierPath];
        [headerLine moveToPoint:NSMakePoint(8.0, MKCandidatePanelHeaderHeight - 0.5)];
        [headerLine lineToPoint:NSMakePoint(NSWidth(bounds) - 8.0, MKCandidatePanelHeaderHeight - 0.5)];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] setStroke];
        [headerLine setLineWidth:1.0];
        [headerLine stroke];
        contentTop = MKCandidatePanelHeaderHeight;
    }

    BOOL horizontal = [self usesHorizontalLayout];
    CGFloat horizontalX = MKCandidatePanelHorizontalInset;
    for (NSUInteger index = 0; index < self.candidateTexts.count; index += 1) {
        NSString *text = self.candidateTexts[index] ?: @"";
        NSDictionary<NSAttributedStringKey, id> *attributes = (index == self.selectedIndex) ? selectedAttributes : normalAttributes;
        NSSize textSize = [text sizeWithAttributes:attributes];
        CGFloat cellWidth = horizontal ? ceil(textSize.width + 20.0) : NSWidth(bounds) - MKCandidatePanelHorizontalInset * 2.0;
        CGFloat y = contentTop + MKCandidatePanelVerticalInset + (CGFloat)index * MKCandidatePanelRowHeight;
        NSRect rowRect = horizontal ?
            NSMakeRect(horizontalX, contentTop + MKCandidatePanelVerticalInset, cellWidth, MKCandidatePanelRowHeight) :
            NSMakeRect(MKCandidatePanelHorizontalInset, y, cellWidth, MKCandidatePanelRowHeight);
        BOOL selected = (index == self.selectedIndex);
        if (selected) {
            NSBezierPath *selection = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rowRect, 0.0, 1.0)
                                                                      xRadius:10.0
                                                                      yRadius:10.0];
            [[self effectiveHighlightColor] setFill];
            [selection fill];
        }

        NSRect textRect = NSMakeRect(NSMinX(rowRect) + 8.0,
                                     NSMinY(rowRect) + floor((NSHeight(rowRect) - textSize.height) / 2.0) - 1.0,
                                     NSWidth(rowRect) - 16.0,
                                     textSize.height + 2.0);
        [text drawInRect:textRect withAttributes:attributes];

        if (!selected && index + 1 < self.candidateTexts.count) {
            NSBezierPath *separator = [NSBezierPath bezierPath];
            if (horizontal) {
                CGFloat lineX = NSMaxX(rowRect) + 0.5;
                [separator moveToPoint:NSMakePoint(lineX, NSMinY(rowRect) + 4.0)];
                [separator lineToPoint:NSMakePoint(lineX, NSMaxY(rowRect) - 4.0)];
            } else {
                CGFloat lineY = NSMaxY(rowRect) - 0.5;
                [separator moveToPoint:NSMakePoint(NSMinX(rowRect) + 8.0, lineY)];
                [separator lineToPoint:NSMakePoint(NSMaxX(rowRect) - 8.0, lineY)];
            }
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] setStroke];
            [separator setLineWidth:1.0];
            [separator stroke];
        }
        horizontalX = NSMaxX(rowRect);
    }
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    if (!self.selectionHandler) {
        return;
    }
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    self.selectionHandler(point);
}

@end

@interface PurrTypeCandidatePanel ()
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) MKCandidatePanelView *panelView;
@property(nonatomic, assign) BOOL hasLastAnchorRect;
@property(nonatomic, assign) NSRect lastAnchorRect;
@property(nonatomic, weak) id lastAnchorClient;
- (NSArray<NSValue *> *)anchorRangesForClient:(id)client allowSelectedRangeFallback:(BOOL)allowSelectedRangeFallback;
@end

@implementation PurrTypeCandidatePanel

- (instancetype)init {
    self = [super init];
    if (self) {
        _panelView = [[MKCandidatePanelView alloc] initWithFrame:NSZeroRect];
        _panelView.wantsLayer = YES;
        _orientation = [MKCandidatePanelOrientationVertical copy];
        _candidateFontSize = 17.0;
        _highlightColor = [MKCandidatePanelHighlightRed copy];
        _panelView.orientation = _orientation;
        _panelView.candidateFontSize = _candidateFontSize;
        _panelView.highlightColor = _highlightColor;
        __weak typeof(self) weakSelf = self;
        _panelView.selectionHandler = ^(NSPoint point) {
            [weakSelf selectCandidateAtPanelPoint:point];
        };

        _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, MKCandidatePanelMinWidth, 80)
                                             styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        _panel.contentView = _panelView;
        _panel.opaque = NO;
        _panel.backgroundColor = [NSColor clearColor];
        _panel.hasShadow = YES;
        _panel.level = NSPopUpMenuWindowLevel;
        _panel.ignoresMouseEvents = NO;
        _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorFullScreenAuxiliary |
                                    NSWindowCollectionBehaviorTransient;
    }
    return self;
}

- (void)setOrientation:(NSString *)orientation {
    NSString *normalized = [orientation isEqualToString:MKCandidatePanelOrientationHorizontal] ?
        MKCandidatePanelOrientationHorizontal : MKCandidatePanelOrientationVertical;
    _orientation = [normalized copy];
    self.panelView.orientation = _orientation;
    [self.panelView setNeedsDisplay:YES];
}

- (void)setCandidateFontSize:(CGFloat)candidateFontSize {
    if (candidateFontSize <= 15.5) {
        _candidateFontSize = 15.0;
    } else if (candidateFontSize >= 18.5) {
        _candidateFontSize = 19.0;
    } else {
        _candidateFontSize = 17.0;
    }
    self.panelView.candidateFontSize = _candidateFontSize;
    [self.panelView setNeedsDisplay:YES];
}

- (void)setHighlightColor:(NSString *)highlightColor {
    NSString *normalized = MKCandidatePanelNormalizedHighlightColor(highlightColor);
    _highlightColor = [normalized copy];
    self.panelView.highlightColor = _highlightColor;
    [self.panelView setNeedsDisplay:YES];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)client {
    [self showCandidates:candidateTexts nearClient:client anchorCharacterIndex:nil];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex {
    [self showCandidates:candidateTexts
              nearClient:client
    anchorCharacterIndex:anchorCharacterIndex
               pageIndex:0
               pageCount:0
      usePreservedAnchor:NO
           selectedIndex:0];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount {
    [self showCandidates:candidateTexts
              nearClient:client
    anchorCharacterIndex:anchorCharacterIndex
               pageIndex:pageIndex
               pageCount:pageCount
      usePreservedAnchor:NO
           selectedIndex:0];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount
    usePreservedAnchor:(BOOL)usePreservedAnchor {
    if (candidateTexts.count == 0) {
        [self hide];
        return;
    }

    [self showCandidates:candidateTexts
              nearClient:client
    anchorCharacterIndex:anchorCharacterIndex
               pageIndex:pageIndex
               pageCount:pageCount
      usePreservedAnchor:usePreservedAnchor
           selectedIndex:0];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount
    usePreservedAnchor:(BOOL)usePreservedAnchor
         selectedIndex:(NSUInteger)selectedIndex {
    if (candidateTexts.count == 0) {
        [self hide];
        return;
    }

    self.panelView.candidateTexts = [candidateTexts copy];
    self.panelView.selectedIndex = selectedIndex < candidateTexts.count ? selectedIndex : 0;
    NSString *pageIndicatorText = pageCount > 1 ? [NSString stringWithFormat:@"%lu/%lu",
                                                   (unsigned long)(pageIndex + 1),
                                                   (unsigned long)pageCount] : @"";
    self.panelView.pageIndicatorText = pageIndicatorText;
    NSSize panelSize = [self preferredSizeForCandidates:candidateTexts pageIndicatorText:pageIndicatorText];
    NSRect anchorRect = NSZeroRect;
    if (![self resolveAnchorRect:&anchorRect
                       forClient:client
            anchorCharacterIndex:anchorCharacterIndex
               usePreservedAnchor:usePreservedAnchor]) {
        [self hide];
        return;
    }

    NSRect frame = [self frameForPanelSize:panelSize anchorRect:anchorRect];
    [self.panel setFrame:frame display:NO];
    [self.panelView setFrame:NSMakeRect(0, 0, panelSize.width, panelSize.height)];
    [self.panelView setNeedsDisplay:YES];
    [self.panel orderFrontRegardless];
}

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts nearScreenRect:(NSRect)screenRect {
    if (candidateTexts.count == 0 || ![self isUsableAnchorRect:screenRect]) {
        [self hide];
        return;
    }

    self.panelView.candidateTexts = [candidateTexts copy];
    self.panelView.selectedIndex = 0;
    self.panelView.pageIndicatorText = @"";
    NSSize panelSize = [self preferredSizeForCandidates:candidateTexts pageIndicatorText:@""];
    NSRect anchorRect = [self normalizedAnchorRect:screenRect];
    // Screen fallbacks are non-text anchors and must not be reused as a preserved caret position.
    NSRect frame = [self frameForPanelSize:panelSize anchorRect:anchorRect];
    [self.panel setFrame:frame display:NO];
    [self.panelView setFrame:NSMakeRect(0, 0, panelSize.width, panelSize.height)];
    [self.panelView setNeedsDisplay:YES];
    [self.panel orderFrontRegardless];
}

- (void)hide {
    [self.panel orderOut:nil];
}

- (void)beginAnchorSessionForClient:(id)client {
    self.hasLastAnchorRect = NO;
    self.lastAnchorRect = NSZeroRect;
    self.lastAnchorClient = client;
}

- (void)clearAnchorSession {
    self.hasLastAnchorRect = NO;
    self.lastAnchorRect = NSZeroRect;
    self.lastAnchorClient = nil;
}

- (BOOL)isVisible {
    return self.panel.isVisible;
}

- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts {
    return [self preferredSizeForCandidates:candidateTexts pageIndicatorText:@""];
}

- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts pageIndicatorText:(NSString *)pageIndicatorText {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:self.candidateFontSize weight:NSFontWeightRegular]
    };
    NSDictionary<NSAttributedStringKey, id> *pageAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold]
    };
    BOOL horizontal = [self.orientation isEqualToString:MKCandidatePanelOrientationHorizontal];
    CGFloat maxTextWidth = 0.0;
    CGFloat horizontalWidth = MKCandidatePanelHorizontalInset * 2.0;
    for (NSString *text in candidateTexts) {
        CGFloat textWidth = [text ?: @"" sizeWithAttributes:attributes].width;
        maxTextWidth = MAX(maxTextWidth, textWidth);
        horizontalWidth += ceil(textWidth + 20.0);
    }
    if (pageIndicatorText.length > 0) {
        maxTextWidth = MAX(maxTextWidth, [pageIndicatorText sizeWithAttributes:pageAttributes].width + 18.0);
        horizontalWidth = MAX(horizontalWidth, maxTextWidth + 26.0);
    }

    CGFloat headerHeight = pageIndicatorText.length > 0 ? MKCandidatePanelHeaderHeight : 0.0;
    CGFloat width = horizontal ? horizontalWidth : ceil(maxTextWidth + 26.0);
    CGFloat verticalMaxWidth = maxTextWidth > (MKCandidatePanelMaxWidth - 26.0) ?
        MKCandidatePanelLongTextMaxWidth : MKCandidatePanelMaxWidth;
    width = MIN(MAX(width, MKCandidatePanelMinWidth), horizontal ? 520.0 : verticalMaxWidth);
    CGFloat rowCount = horizontal ? 1.0 : (CGFloat)candidateTexts.count;
    CGFloat height = headerHeight + MKCandidatePanelVerticalInset * 2.0 + MKCandidatePanelRowHeight * rowCount;
    return NSMakeSize(width, ceil(height));
}

- (NSString *)candidateTextAtPanelPoint:(NSPoint)point {
    if (point.x < 0.0 || point.x > NSWidth(self.panelView.bounds)) {
        return nil;
    }
    CGFloat contentTop = self.panelView.pageIndicatorText.length > 0 ? MKCandidatePanelHeaderHeight : 0.0;
    if (point.y < contentTop + MKCandidatePanelVerticalInset) {
        return nil;
    }

    if ([self.orientation isEqualToString:MKCandidatePanelOrientationHorizontal]) {
        if (point.y >= contentTop + MKCandidatePanelVerticalInset + MKCandidatePanelRowHeight) {
            return nil;
        }
        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSFontAttributeName: [NSFont systemFontOfSize:self.candidateFontSize weight:NSFontWeightRegular]
        };
        CGFloat x = MKCandidatePanelHorizontalInset;
        for (NSString *text in self.panelView.candidateTexts) {
            CGFloat width = ceil([text ?: @"" sizeWithAttributes:attributes].width + 20.0);
            if (point.x >= x && point.x < x + width) {
                return text;
            }
            x += width;
        }
        return nil;
    }

    CGFloat candidateAreaHeight = MKCandidatePanelRowHeight * (CGFloat)self.panelView.candidateTexts.count;
    CGFloat y = point.y - contentTop - MKCandidatePanelVerticalInset;
    if (y < 0.0 || y >= candidateAreaHeight) {
        return nil;
    }

    NSUInteger index = (NSUInteger)floor(y / MKCandidatePanelRowHeight);
    if (index >= self.panelView.candidateTexts.count) {
        return nil;
    }
    return self.panelView.candidateTexts[index];
}

- (void)selectCandidateAtPanelPoint:(NSPoint)point {
    NSString *candidateText = [self candidateTextAtPanelPoint:point];
    if (candidateText.length == 0) {
        return;
    }
    [self.delegate candidatePanel:self didSelectCandidateText:candidateText];
}

- (BOOL)resolveAnchorRect:(NSRect *)resolvedAnchorRect
                forClient:(id)client
     anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
       usePreservedAnchor:(BOOL)usePreservedAnchor {
    if (!client) {
        if (usePreservedAnchor && self.hasLastAnchorRect) {
            if (resolvedAnchorRect) {
                *resolvedAnchorRect = self.lastAnchorRect;
            }
            return YES;
        }
        return NO;
    }

    if (self.hasLastAnchorRect && self.lastAnchorClient && self.lastAnchorClient != client) {
        self.hasLastAnchorRect = NO;
        self.lastAnchorRect = NSZeroRect;
    }

    if (anchorCharacterIndex) {
        NSRect lineHeightRect = [self anchorRectFromLineHeightAttributesForClient:client
                                                             anchorCharacterIndex:anchorCharacterIndex];
        if ([self isUsableAnchorRect:lineHeightRect]) {
            NSRect normalizedRect = [self normalizedAnchorRect:lineHeightRect];
            self.hasLastAnchorRect = YES;
            self.lastAnchorRect = normalizedRect;
            self.lastAnchorClient = client;
            if (resolvedAnchorRect) {
                *resolvedAnchorRect = normalizedRect;
            }
            return YES;
        }
    }

    NSArray<NSValue *> *ranges = [self anchorRangesForClient:client
                                  allowSelectedRangeFallback:(anchorCharacterIndex == nil)];

    if ([client respondsToSelector:@selector(firstRectForCharacterRange:actualRange:)]) {
        for (NSValue *rangeValue in ranges) {
            NSRange range = rangeValue.rangeValue;
            if (range.location == NSNotFound) {
                continue;
            }

            NSRect rect = [(id<NSTextInputClient>)client firstRectForCharacterRange:range actualRange:NULL];
            if ([self isUsableAnchorRect:rect]) {
                NSRect normalizedRect = [self normalizedAnchorRect:rect];
                self.hasLastAnchorRect = YES;
                self.lastAnchorRect = normalizedRect;
                self.lastAnchorClient = client;
                if (resolvedAnchorRect) {
                    *resolvedAnchorRect = normalizedRect;
                }
                return YES;
            }
        }
    }

    if (self.hasLastAnchorRect) {
        if (resolvedAnchorRect) {
            *resolvedAnchorRect = self.lastAnchorRect;
        }
        return YES;
    }

    return NO;
}

- (NSRect)anchorRectFromLineHeightAttributesForClient:(id)client anchorCharacterIndex:(NSNumber *)anchorCharacterIndex {
    if (!anchorCharacterIndex || ![client respondsToSelector:@selector(attributesForCharacterIndex:lineHeightRectangle:)]) {
        return NSZeroRect;
    }

    NSRect lineHeightRect = NSZeroRect;
    [(id<PurrTypeLineHeightAnchorClient>)client attributesForCharacterIndex:anchorCharacterIndex.unsignedIntegerValue
                                                          lineHeightRectangle:&lineHeightRect];
    return lineHeightRect;
}

- (NSArray<NSValue *> *)anchorRangesForClient:(id)client {
    return [self anchorRangesForClient:client allowSelectedRangeFallback:YES];
}

- (NSArray<NSValue *> *)anchorRangesForClient:(id)client allowSelectedRangeFallback:(BOOL)allowSelectedRangeFallback {
    NSMutableArray<NSValue *> *ranges = [NSMutableArray arrayWithCapacity:3];

    if ([client respondsToSelector:@selector(markedRange)]) {
        NSRange markedRange = [(id<NSTextInputClient>)client markedRange];
        if (markedRange.location != NSNotFound) {
            NSRange markedEndRange = NSMakeRange(NSMaxRange(markedRange), 0);
            [ranges addObject:[NSValue valueWithRange:markedEndRange]];
            [ranges addObject:[NSValue valueWithRange:markedRange]];
            return ranges;
        }
    }

    if (!allowSelectedRangeFallback) {
        return ranges;
    }

    if ([client respondsToSelector:@selector(selectedRange)]) {
        NSRange selectedRange = [(id<NSTextInputClient>)client selectedRange];
        if (selectedRange.location != NSNotFound) {
            [ranges addObject:[NSValue valueWithRange:selectedRange]];
        }
    }

    return ranges;
}

- (BOOL)isUsableAnchorRect:(NSRect)rect {
    if (NSEqualRects(rect, NSZeroRect)) {
        return NO;
    }
    if (!isfinite(NSMinX(rect)) || !isfinite(NSMinY(rect)) ||
        !isfinite(NSWidth(rect)) || !isfinite(NSHeight(rect))) {
        return NO;
    }
    if (NSWidth(rect) < 0.0 || NSHeight(rect) < 0.0) {
        return NO;
    }
    NSRect normalizedRect = [self normalizedAnchorRect:rect];
    return [self screenForRect:normalizedRect] != nil;
}

- (NSRect)normalizedAnchorRect:(NSRect)rect {
    CGFloat width = NSWidth(rect) <= 0.0 ? 1.0 : NSWidth(rect);
    CGFloat height = NSHeight(rect) <= 0.0 ? MKCandidatePanelDefaultAnchorHeight : NSHeight(rect);
    return NSMakeRect(NSMinX(rect), NSMinY(rect), width, height);
}

- (NSRect)frameForPanelSize:(NSSize)panelSize anchorRect:(NSRect)anchorRect {
    NSScreen *screen = [self screenForRect:anchorRect] ?: [NSScreen mainScreen];
    NSRect visibleFrame = screen.visibleFrame;

    CGFloat preferredX = NSMaxX(anchorRect) + MKCandidatePanelCaretHorizontalGap;
    CGFloat alignedX = NSMinX(anchorRect);
    CGFloat leftX = NSMinX(anchorRect) - panelSize.width - MKCandidatePanelCaretHorizontalGap;
    CGFloat maxX = NSMaxX(visibleFrame) - panelSize.width - MKCandidatePanelScreenMargin;
    CGFloat minX = NSMinX(visibleFrame) + MKCandidatePanelScreenMargin;
    CGFloat x = preferredX;
    if (x > maxX && alignedX <= maxX) {
        x = alignedX;
    }
    if (x > maxX && leftX >= minX) {
        x = leftX;
    }
    x = MIN(MAX(x, minX), maxX);

    CGFloat belowY = NSMinY(anchorRect) - panelSize.height - MKCandidatePanelCaretVerticalGap;
    CGFloat aboveY = NSMaxY(anchorRect) + MKCandidatePanelCaretVerticalGap;
    CGFloat maxY = NSMaxY(visibleFrame) - panelSize.height - MKCandidatePanelScreenMargin;
    CGFloat minY = NSMinY(visibleFrame) + MKCandidatePanelScreenMargin;
    CGFloat y = belowY;
    if (y < minY && aboveY <= maxY) {
        y = aboveY;
    }
    y = MIN(MAX(y, minY), maxY);

    return NSMakeRect(x, y, panelSize.width, panelSize.height);
}

- (NSScreen *)screenForRect:(NSRect)rect {
    NSPoint point = NSMakePoint(NSMidX(rect), NSMidY(rect));
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(point, screen.frame)) {
            return screen;
        }
    }
    return nil;
}

@end
