#import <Cocoa/Cocoa.h>

@class PurrTypeCandidatePanel;

@protocol PurrTypeCandidatePanelDelegate <NSObject>
- (void)candidatePanel:(PurrTypeCandidatePanel *)panel didSelectCandidateText:(NSString *)candidateText;
@end

@interface PurrTypeCandidatePanel : NSObject

@property(nonatomic, weak) id<PurrTypeCandidatePanelDelegate> delegate;

- (void)showCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)client;
- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex;
- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount;
- (void)showCandidates:(NSArray<NSString *> *)candidateTexts
            nearClient:(id)client
  anchorCharacterIndex:(NSNumber *)anchorCharacterIndex
             pageIndex:(NSUInteger)pageIndex
             pageCount:(NSUInteger)pageCount
    usePreservedAnchor:(BOOL)usePreservedAnchor;
- (void)beginAnchorSessionForClient:(id)client;
- (void)clearAnchorSession;
- (void)hide;
- (BOOL)isVisible;
- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts;
- (NSSize)preferredSizeForCandidates:(NSArray<NSString *> *)candidateTexts pageIndicatorText:(NSString *)pageIndicatorText;
- (NSString *)candidateTextAtPanelPoint:(NSPoint)point;
- (void)selectCandidateAtPanelPoint:(NSPoint)point;

@end
