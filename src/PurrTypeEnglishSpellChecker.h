#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MKSpellingCandidateSource;

@interface PurrTypeEnglishSpellChecker : NSObject

+ (instancetype)sharedChecker;

- (BOOL)isEligibleTokenForSpellingSuggestions:(NSString *)token;
- (NSArray<NSString *> *)suggestionsForToken:(NSString *)token limit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END
