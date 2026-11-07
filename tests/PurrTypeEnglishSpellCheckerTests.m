#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEnglishSpellChecker.h"

@interface PurrTypeEnglishSpellChecker (TestableSanitization)
- (NSArray<NSString *> *)sanitizedSuggestions:(NSArray *)suggestions originalToken:(NSString *)originalToken;
@end

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL StringArrayContainsCaseInsensitive(NSArray<NSString *> *strings, NSString *needle) {
    for (NSString *string in strings) {
        if ([string caseInsensitiveCompare:needle] == NSOrderedSame) {
            return YES;
        }
    }
    return NO;
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];
        PurrTypeEnglishSpellChecker *checker = [PurrTypeEnglishSpellChecker sharedChecker];

        AssertTrue([checker isEligibleTokenForSpellingSuggestions:@"speling"], @"plain English word is eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"https://recieve.example"], @"URL-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"foo_bar"], @"code-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"./recieve"], @"path-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"recieve1"], @"mixed alphanumeric token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"API"], @"all-caps acronym is not eligible for spelling suggestions");

        NSArray *sanitized = [checker sanitizedSuggestions:@[@"spelling", @"SPELLING", @" speling ", @"", @"line\nbreak", @123]
                                             originalToken:@"Speling"];
        AssertTrue([sanitized isEqualToArray:@[@"Spelling"]], @"suggestions reject invalid entries, deduplicate and preserve initial capitalization");
        PurrTypeEnglishSpellChecker *cachedChecker = [[PurrTypeEnglishSpellChecker alloc] init];
        [cachedChecker setValue:[@{@"speling": @[@"spelling", @"spieling"]} mutableCopy] forKey:@"suggestionCache"];
        AssertTrue([[cachedChecker suggestionsForToken:@"speling" limit:1] isEqualToArray:@[@"spelling"]], @"cached suggestions respect the requested limit");
        AssertTrue([cachedChecker suggestionsForToken:@"speling" limit:0].count == 0, @"zero limit suppresses cached suggestions");
        AssertTrue([checker suggestionsForToken:@"https://recieve.example" limit:8].count == 0, @"URL-like tokens never call through to spelling suggestions");

        // Probe the external service separately. Hosted Intel VMs can have no usable
        // NSSpellServer even though AppKit, compilation and the app logic work.
        NSSpellChecker *system = [NSSpellChecker sharedSpellChecker];
        NSArray<NSString *> *systemGuesses = [system guessesForWordRange:NSMakeRange(0, 7)
                                                              inString:@"speling"
                                                              language:@"en"
                                                inSpellDocumentWithTag:0];
        BOOL serviceAvailable = StringArrayContainsCaseInsensitive(systemGuesses, @"spelling");
        BOOL allowUnavailable = [NSProcessInfo.processInfo.environment[@"PURRTYPE_ALLOW_UNAVAILABLE_SPELL_SERVICE"] isEqualToString:@"1"];
        if (!serviceAvailable && allowUnavailable) {
            NSLog(@"SKIP: live NSSpellChecker integration; hosted system service unavailable (logic tests passed)");
        } else {
            AssertTrue(serviceAvailable, @"live NSSpellChecker integration requires a usable macOS English spelling service");
            NSArray<NSString *> *suggestions = [checker suggestionsForToken:@"speling" limit:8];
            AssertTrue(StringArrayContainsCaseInsensitive(suggestions, @"spelling"), @"NSSpellChecker suggests spelling for speling");
            AssertTrue([checker suggestionsForToken:@"speling" limit:1].count == 1, @"spelling suggestions respect the requested limit");
            AssertTrue([checker suggestionsForToken:@"receive" limit:8].count == 0, @"correctly spelled words do not show spelling suggestions");
            NSLog(@"PASS: live NSSpellChecker integration");
        }
        NSLog(@"PASS: PurrTypeEnglishSpellCheckerTests");
    }

    return 0;
}
