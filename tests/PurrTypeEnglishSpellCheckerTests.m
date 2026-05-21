#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEnglishSpellChecker.h"

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
        PurrTypeEnglishSpellChecker *checker = [PurrTypeEnglishSpellChecker sharedChecker];

        AssertTrue([checker isEligibleTokenForSpellingSuggestions:@"speling"], @"plain English word is eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"https://recieve.example"], @"URL-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"foo_bar"], @"code-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"./recieve"], @"path-like token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"recieve1"], @"mixed alphanumeric token is not eligible for spelling suggestions");
        AssertTrue(![checker isEligibleTokenForSpellingSuggestions:@"API"], @"all-caps acronym is not eligible for spelling suggestions");

        NSArray<NSString *> *suggestions = [checker suggestionsForToken:@"speling" limit:8];
        AssertTrue(StringArrayContainsCaseInsensitive(suggestions, @"spelling"), @"NSSpellChecker suggests spelling for speling");
        AssertTrue([checker suggestionsForToken:@"speling" limit:1].count == 1, @"spelling suggestions respect the requested limit");
        AssertTrue([checker suggestionsForToken:@"receive" limit:8].count == 0, @"correctly spelled words do not show spelling suggestions");
        AssertTrue([checker suggestionsForToken:@"https://recieve.example" limit:8].count == 0, @"URL-like tokens never call through to spelling suggestions");
    }

    return 0;
}
