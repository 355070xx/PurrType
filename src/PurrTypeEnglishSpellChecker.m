#import "PurrTypeEnglishSpellChecker.h"
#import <AppKit/AppKit.h>

NSString *const MKSpellingCandidateSource = @"spelling";

@interface PurrTypeEnglishSpellChecker ()

@property(nonatomic, assign) NSInteger spellDocumentTag;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *suggestionCache;

@end

@implementation PurrTypeEnglishSpellChecker

+ (instancetype)sharedChecker {
    static PurrTypeEnglishSpellChecker *checker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checker = [[PurrTypeEnglishSpellChecker alloc] init];
    });
    return checker;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _spellDocumentTag = [NSSpellChecker uniqueSpellDocumentTag];
        _suggestionCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    if (_spellDocumentTag != 0 && [NSSpellChecker sharedSpellCheckerExists]) {
        [[NSSpellChecker sharedSpellChecker] closeSpellDocumentWithTag:_spellDocumentTag];
    }
}

- (BOOL)isEligibleTokenForSpellingSuggestions:(NSString *)token {
    NSString *trimmed = [self normalizedToken:token];
    if (trimmed.length < 3 || trimmed.length > 48) {
        return NO;
    }

    NSCharacterSet *letters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    NSCharacterSet *nonLetters = [letters invertedSet];
    if ([trimmed rangeOfCharacterFromSet:nonLetters].location != NSNotFound) {
        return NO;
    }

    if ([trimmed isEqualToString:[trimmed uppercaseString]] && trimmed.length > 1) {
        return NO;
    }

    return YES;
}

- (NSArray<NSString *> *)suggestionsForToken:(NSString *)token limit:(NSUInteger)limit {
    NSString *trimmed = [self normalizedToken:token];
    if (limit == 0 || ![self isEligibleTokenForSpellingSuggestions:trimmed]) {
        return @[];
    }

    NSString *cacheKey = [trimmed lowercaseString];
    NSArray<NSString *> *cached = self.suggestionCache[cacheKey];
    if (cached) {
        return [self limitedSuggestions:cached limit:limit];
    }

    NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
    NSString *language = [self preferredEnglishLanguageForSpellChecker:checker];
    NSRange wordRange = NSMakeRange(0, trimmed.length);
    NSRange misspelledRange = [checker checkSpellingOfString:trimmed
                                                  startingAt:0
                                                    language:language
                                                        wrap:NO
                                      inSpellDocumentWithTag:self.spellDocumentTag
                                                   wordCount:NULL];
    if (misspelledRange.location == NSNotFound) {
        self.suggestionCache[cacheKey] = @[];
        return @[];
    }

    NSString *correction = [checker correctionForWordRange:wordRange
                                                  inString:trimmed
                                                  language:language
                                    inSpellDocumentWithTag:self.spellDocumentTag];

    NSMutableArray<NSString *> *rankedSuggestions = [NSMutableArray array];
    if (correction.length > 0) {
        [rankedSuggestions addObject:correction];
    }

    NSArray<NSString *> *guesses = [checker guessesForWordRange:wordRange
                                                       inString:trimmed
                                                       language:language
                                         inSpellDocumentWithTag:self.spellDocumentTag] ?: @[];
    if (guesses.count == 0 && language.length > 0) {
        guesses = [checker guessesForWordRange:wordRange
                                      inString:trimmed
                                      language:nil
                        inSpellDocumentWithTag:self.spellDocumentTag] ?: @[];
    }

    [rankedSuggestions addObjectsFromArray:guesses];

    NSArray<NSString *> *sanitized = [self sanitizedSuggestions:rankedSuggestions originalToken:trimmed];
    self.suggestionCache[cacheKey] = sanitized;
    if (self.suggestionCache.count > 512) {
        [self.suggestionCache removeAllObjects];
        self.suggestionCache[cacheKey] = sanitized;
    }
    return [self limitedSuggestions:sanitized limit:limit];
}

- (NSString *)normalizedToken:(NSString *)token {
    if (![token isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)preferredEnglishLanguageForSpellChecker:(NSSpellChecker *)checker {
    for (NSString *language in checker.userPreferredLanguages) {
        if ([self isEnglishLanguageIdentifier:language]) {
            return language;
        }
    }
    for (NSString *language in checker.availableLanguages) {
        if ([self isEnglishLanguageIdentifier:language]) {
            return language;
        }
    }
    return @"en";
}

- (BOOL)isEnglishLanguageIdentifier:(NSString *)language {
    NSString *lowercase = [language lowercaseString];
    return [lowercase isEqualToString:@"en"] || [lowercase hasPrefix:@"en_"] || [lowercase hasPrefix:@"en-"];
}

- (NSArray<NSString *> *)sanitizedSuggestions:(NSArray<NSString *> *)suggestions originalToken:(NSString *)originalToken {
    NSMutableArray<NSString *> *sanitized = [NSMutableArray arrayWithCapacity:suggestions.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (id value in suggestions) {
        if (![value isKindOfClass:[NSString class]]) {
            continue;
        }

        NSString *candidate = [self normalizedToken:(NSString *)value];
        if (candidate.length == 0 || candidate.length > 64) {
            continue;
        }
        if ([candidate rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
            continue;
        }
        if ([candidate caseInsensitiveCompare:originalToken] == NSOrderedSame) {
            continue;
        }

        NSString *dedupeKey = [candidate lowercaseString];
        if ([seen containsObject:dedupeKey]) {
            continue;
        }
        [seen addObject:dedupeKey];
        [sanitized addObject:[self suggestion:candidate matchingCapitalizationOfToken:originalToken]];
    }
    return sanitized;
}

- (NSString *)suggestion:(NSString *)suggestion matchingCapitalizationOfToken:(NSString *)token {
    if (token.length == 0 || suggestion.length == 0) {
        return suggestion;
    }

    unichar first = [token characterAtIndex:0];
    if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:first]) {
        NSString *head = [[suggestion substringToIndex:1] uppercaseString];
        NSString *tail = suggestion.length > 1 ? [suggestion substringFromIndex:1] : @"";
        return [head stringByAppendingString:tail];
    }
    return suggestion;
}

- (NSArray<NSString *> *)limitedSuggestions:(NSArray<NSString *> *)suggestions limit:(NSUInteger)limit {
    if (suggestions.count <= limit) {
        return suggestions;
    }
    return [suggestions subarrayWithRange:NSMakeRange(0, limit)];
}

@end
