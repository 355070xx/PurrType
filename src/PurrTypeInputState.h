#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PurrTypeInputState : NSObject

@property(nonatomic, strong, readonly) NSMutableString *buffer;
@property(nonatomic, assign) BOOL associationModeActive;
@property(nonatomic, assign) BOOL rawEnglishModeActive;

+ (BOOL)isRawEnglishContinuationString:(NSString *)string;

- (void)appendCodeText:(NSString *)text;
- (void)appendRawEnglishText:(NSString *)text;
- (void)deleteBackward;
- (void)resetComposition;
- (void)clearAssociations;

@end

NS_ASSUME_NONNULL_END
